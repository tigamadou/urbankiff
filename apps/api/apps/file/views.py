from rest_framework import generics, status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.parsers import FormParser, MultiPartParser

from .models import File
from .serializers import CreateSignedFileSerializer, FileSerializer, MinioUploadSerializer
from .minio_service import minio_client
from minio.commonconfig import CopySource
from django.http import FileResponse, Http404
import mimetypes
from django.conf import settings
import os
from PIL import Image
from io import BytesIO

MIME_TYPES = {
    '.mp3': 'audio/mpeg',
    '.wav': 'audio/wav',
    '.ogg': 'audio/ogg',
    # '.jpg': 'image/jpeg',
    # '.jpeg': 'image/jpeg',
    # '.png': 'image/png',
    '.pdf': 'application/pdf',
    '.webp': 'image/webp',
}

# Only WebP images are accepted
ACCEPTED_IMAGE_MIME_TYPE = 'image/webp'


def create_thumbnail(image_data, size, format='WEBP'):
    """
    Create a center-cropped thumbnail from image data

    Args:
        image_data: Raw image data (bytes)
        size: Tuple of (width, height) for thumbnail size
        format: Output format (WEBP, JPEG, PNG, etc.)

    Returns:
        BytesIO object containing the thumbnail data
    """
    try:
        # Open image from bytes
        image = Image.open(BytesIO(image_data))

        # Convert to RGB if necessary (for WebP output)
        if format == 'WEBP' and image.mode in ('RGBA', 'LA', 'P'):
            # For WebP, we can preserve transparency or convert to RGB
            if image.mode == 'P':
                image = image.convert('RGBA')
            # Keep RGBA for WebP to preserve transparency
        elif format == 'JPEG' and image.mode in ('RGBA', 'LA', 'P'):
            # Create a white background for JPEG
            background = Image.new('RGB', image.size, (255, 255, 255))
            if image.mode == 'P':
                image = image.convert('RGBA')
            background.paste(image, mask=image.split()[-1] if image.mode == 'RGBA' else None)
            image = background

        # Get target dimensions
        target_width, target_height = size

        # Calculate the aspect ratio of the original image
        original_width, original_height = image.size
        original_ratio = original_width / original_height
        target_ratio = target_width / target_height

        # Determine how to resize and crop
        if original_ratio > target_ratio:
            # Image is wider than target ratio, crop width
            new_height = target_height
            new_width = int(target_height * original_ratio)
        else:
            # Image is taller than target ratio, crop height
            new_width = target_width
            new_height = int(target_width / original_ratio)

        # Resize the image to the calculated dimensions
        image = image.resize((new_width, new_height), Image.Resampling.LANCZOS)

        # Calculate crop box for center cropping
        left = (new_width - target_width) // 2
        top = (new_height - target_height) // 2
        right = left + target_width
        bottom = top + target_height

        # Crop the image to the exact target size
        image = image.crop((left, top, right, bottom))

        # Save to BytesIO
        output = BytesIO()
        if format == 'WEBP':
            image.save(output, format=format, quality=85, optimize=True, method=6)
        else:
            image.save(output, format=format, quality=85, optimize=True)
        output.seek(0)

        return output

    except Exception as e:
        raise Exception(f"Failed to create thumbnail: {str(e)}")


def upload_thumbnail_to_minio(thumbnail_data, thumbnail_name, thumbnail_folder, bucket_name):
    """
    Upload thumbnail to MinIO in specified folder

    Args:
        thumbnail_data: BytesIO object containing thumbnail data
        thumbnail_name: Name for the thumbnail file
        thumbnail_folder: Folder path for the thumbnail (e.g., "thumbnails/30x30")
        bucket_name: MinIO bucket name

    Returns:
        True if successful, False otherwise
    """
    try:
        minio_client.put_object(
            bucket_name,
            f"uploads/{thumbnail_folder}/{thumbnail_name}",
            thumbnail_data,
            thumbnail_data.getbuffer().nbytes
        )
        return True
    except Exception as e:
        print(f"Failed to upload thumbnail {thumbnail_name} to {thumbnail_folder}: {str(e)}")
        return False


class CreateSignedFile(generics.CreateAPIView):
    """ Create signed file.

    This creates a file instance and generates a signed URL that the
    client can upload to directly.
    """
    serializer_class = CreateSignedFileSerializer


class UploadFile(generics.CreateAPIView):
    """ Upload file.

    This handles uploading a file on the server, rather than returning
    a signed URL for AWS S3 or the like. Though, with django-storages,
    the file may very well likely end up on S3 anyway.
    """
    parser_classes = [FormParser, MultiPartParser]
    serializer_class = FileSerializer


class FileDetail(generics.RetrieveDestroyAPIView):
    queryset = File.objects
    serializer_class = FileSerializer


class FileServeView(APIView):
    """
    API endpoint to serve file by file_name.
    """
    permission_classes = (permissions.AllowAny,)

    def get(self, request, file_name, *args, **kwargs):
        try:
            # Look up the file in the database
            file_obj = File.objects.get(name=file_name)

            # Check if file is deleted
            if file_obj.deleted_at:
                raise Http404("File has been deleted.")

        except File.DoesNotExist:
            raise Http404("File not found in database.")

        bucket_name = settings.MINIO_STORAGE_BUCKET_NAME

        # Check if this is a thumbnail request for an image
        width_param = request.query_params.get('w')
        if width_param and file_obj.mime_type == ACCEPTED_IMAGE_MIME_TYPE:
            try:
                width = int(width_param)
                if width in [30, 300]:
                    # Construct thumbnail path
                    thumbnail_folder = f"thumbnails/{width}x{width}"
                    thumbnail_path = f"{file_obj.path}/{thumbnail_folder}/{file_obj.name}"
                    local_file_path = os.path.join('/tmp', f"thumb_{width}_{file_obj.name}")

                    try:
                        # Download the thumbnail from MinIO
                        minio_client.fget_object(bucket_name, thumbnail_path, local_file_path)

                        # Open the thumbnail file and send it as a FileResponse
                        file = open(local_file_path, 'rb')
                        response = FileResponse(file, content_type=file_obj.mime_type)
                        response['Content-Disposition'] = f'inline; filename="{file_obj.name}"'
                        return response

                    except Exception as e:
                        print(f"Thumbnail {thumbnail_path} not found, serving original: {e}")
                        # Fall through to serve original file if thumbnail doesn't exist
                else:
                    # Invalid width parameter, serve original file
                    pass
            except (ValueError, TypeError):
                # Invalid width parameter, serve original file
                pass

        # Serve original file (default behavior)
        full_file_path = f"{file_obj.path}/{file_obj.name}"
        local_file_path = os.path.join('/tmp', file_obj.name)  # Path where the file will be temporarily stored

        # Use MIME type from database, fallback to file extension detection
        content_type = file_obj.mime_type
        if not content_type:
            # Get file extension to determine content type
            _, file_extension = os.path.splitext(file_obj.name)
            content_type = MIME_TYPES.get(file_extension.lower())
            if not content_type:
                # Try to get content type from mimetypes
                content_type, _ = mimetypes.guess_type(file_obj.name)
                if not content_type:
                    content_type = 'application/octet-stream'

        try:
            # Download the file from MinIO using the full path and save it locally
            minio_client.fget_object(bucket_name, full_file_path, local_file_path)

            # Open the file in binary mode and send it as a FileResponse
            file = open(local_file_path, 'rb')
            response = FileResponse(file, content_type=content_type)
            response['Content-Disposition'] = f'inline; filename="{file_obj.name}"'
            return response

        except Exception as e:
            print(f"Error serving file {full_file_path}: {e}")
            raise Http404("File not found in storage or unable to download.")
        finally:
            # Clean up the temporary file
            if os.path.exists(local_file_path):
                os.remove(local_file_path)


class FileUploadView(APIView):
    def post(self, request, *args, **kwargs):
        # Check if user is authenticated
        if not request.user.is_authenticated:
            return Response({"detail": "Authentication required"}, status=status.HTTP_401_UNAUTHORIZED)

        # Validate the incoming file data using the serializer
        serializer = MinioUploadSerializer(data=request.data)
        if serializer.is_valid():
            file = serializer.validated_data['file']

            # Check if file is a WebP image
            original_name = file.name
            mime_type, _ = mimetypes.guess_type(original_name)
            if not mime_type:
                file_extension = os.path.splitext(original_name)[1].lower()
                mime_type = MIME_TYPES.get(file_extension, 'application/octet-stream')

            # Only allow WebP images
            if mime_type != ACCEPTED_IMAGE_MIME_TYPE:
                return Response({
                    "error": "Only WebP images are accepted",
                    "received_mime_type": mime_type,
                    "accepted_mime_type": ACCEPTED_IMAGE_MIME_TYPE
                }, status=status.HTTP_400_BAD_REQUEST)

            try:
                # Generate unique file name for uploads folder
                from django.core.files.storage import default_storage
                unique_name = default_storage.get_available_name(original_name)
                file_name = f"uploads/{unique_name}"

                # Upload file to MinIO with uploads folder
                bucket_name = settings.MINIO_STORAGE_BUCKET_NAME
                minio_client.put_object(bucket_name, file_name, file, file.size)

                # Construct file URL
                minio_endpoint = getattr(settings, 'FILES_CDN_ENDPOINT')
                file_url = f"{minio_endpoint}/{unique_name}"

                # Create File record in database
                file_obj = File.objects.create(
                    owner=request.user,
                    name=unique_name,
                    path='uploads',
                    url=file_url,
                    mime_type=mime_type
                )

                # Generate thumbnails for WebP images
                thumbnails_created = []
                if mime_type == ACCEPTED_IMAGE_MIME_TYPE:
                    try:
                        # Read the uploaded file data for thumbnail generation
                        file.seek(0)  # Reset file pointer
                        image_data = file.read()

                        # Get file extension for thumbnail naming
                        file_extension = os.path.splitext(unique_name)[1]
                        base_name = os.path.splitext(unique_name)[0]

                        # Define thumbnail sizes and their corresponding folders
                        thumbnail_configs = [
                            {"size": (300, 300), "folder": "thumbnails/300x300"},
                            {"size": (30, 30), "folder": "thumbnails/30x30"}
                        ]

                        for config in thumbnail_configs:
                            width, height = config["size"]
                            folder = config["folder"]

                            try:
                                # Create thumbnail
                                thumbnail_data = create_thumbnail(
                                    image_data,
                                    (width, height),
                                    format='WEBP'
                                )

                                # Generate thumbnail name (without size suffix)
                                thumbnail_name = f"{base_name}.webp"

                                # Upload thumbnail to MinIO in specific folder
                                if upload_thumbnail_to_minio(thumbnail_data, thumbnail_name, folder, bucket_name):
                                    thumbnails_created.append({
                                        "size": f"{width}x{height}",
                                        "name": thumbnail_name,
                                        "folder": folder,
                                        "url": f"{minio_endpoint}/{folder}/{thumbnail_name}"
                                    })

                            except Exception as thumb_error:
                                print(f"Failed to create {width}x{height} thumbnail: {str(thumb_error)}")
                                continue

                    except Exception as e:
                        print(f"Failed to generate thumbnails: {str(e)}")

                response_data = {
                    "message": "File uploaded successfully",
                    "file_id": file_obj.id,
                    "file_name": unique_name,
                    "url": file_obj.url,
                    "mime_type": mime_type,
                    "created_at": file_obj.created_at
                }

                # Add thumbnails info if any were created
                if thumbnails_created:
                    response_data["thumbnails"] = thumbnails_created

                return Response(response_data, status=status.HTTP_201_CREATED)

            except Exception as e:
                return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class FileRetrieveSignedUrlView(APIView):
    permission_classes = (permissions.AllowAny,)

    def get(self, request, file_name, *args, **kwargs):
        bucket_name = settings.MINIO_STORAGE_BUCKET_NAME
        local_file_path = os.path.join('/tmp', file_name)  # Path where the file will be temporarily stored

        _, file_extension = os.path.splitext(file_name)
        content_type = MIME_TYPES.get(file_extension.lower())
        if not content_type:
            return Response({"detail": "Unsupported file type"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            # Download the file from MinIO and save it locally
            minio_client.fget_object(bucket_name, file_name, local_file_path)

            # Get the MIME type of the file (e.g., 'image/png', 'image/jpeg', etc.)
            mime_type, _ = mimetypes.guess_type(local_file_path)

            if mime_type is None:
                # If MIME type cannot be guessed, use a default (application/octet-stream)
                mime_type = 'application/octet-stream'

            # Open the file in binary mode and send it as a FileResponse
            file = open(local_file_path, 'rb')
            response = FileResponse(file, content_type=content_type)
            response['Content-Disposition'] = f'inline; filename="{file_name}"'
            return response

        except Exception as e:
            print(f"Error: {e}")
            raise Http404("File not found or unable to download.")
        finally:
            # Clean up the temporary file
            if os.path.exists(local_file_path):
                os.remove(local_file_path)


class ListFilesView(APIView):
    """
    API endpoint to list files from the database.
    """
    permission_classes = (permissions.AllowAny,)

    def get(self, request):
        try:
            # Get query parameters for filtering and pagination
            page = int(request.query_params.get('page', 1))
            page_size = int(request.query_params.get('page_size', 20))
            owner_id = request.query_params.get('owner_id')
            mime_type = request.query_params.get('mime_type')

            # Build queryset
            queryset = File.objects.filter(deleted_at__isnull=True)

            # Filter by owner if provided
            if owner_id:
                queryset = queryset.filter(owner_id=owner_id)

            # Filter by MIME type if provided
            if mime_type:
                queryset = queryset.filter(mime_type=mime_type)

            # Order by creation date (newest first)
            queryset = queryset.order_by('-created_at')

            # Calculate pagination
            total_count = queryset.count()
            start_index = (page - 1) * page_size
            end_index = start_index + page_size

            # Get paginated results
            files = queryset[start_index:end_index]

            # Serialize the files
            file_data = []
            for file_obj in files:
                file_data.append({
                    "id": file_obj.id,
                    "name": file_obj.name,
                    "path": file_obj.path,
                    "url": file_obj.url,
                    "mime_type": file_obj.mime_type,
                    "owner_id": file_obj.owner_id,
                    "owner_email": file_obj.owner.email if file_obj.owner else None,
                    "created_at": file_obj.created_at,
                    "updated_at": file_obj.updated_at,
                    "is_image": file_obj.is_image
                })

            # Prepare response with pagination info
            response_data = {
                "files": file_data,
                "pagination": {
                    "page": page,
                    "page_size": page_size,
                    "total_count": total_count,
                    "total_pages": (total_count + page_size - 1) // page_size,
                    "has_next": end_index < total_count,
                    "has_previous": page > 1
                }
            }

            return Response(response_data, status=status.HTTP_200_OK)

        except Exception as e:
            return Response({"detail": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class DeleteFileView(APIView):
    """
    API endpoint to soft delete a file by setting deleted_at timestamp.
    """
    permission_classes = (permissions.AllowAny,)

    def delete(self, request, file_name):
        try:
            # Look up the file in the database
            file_obj = File.objects.get(name=file_name)

            # Check if file is already deleted
            if file_obj.deleted_at:
                return Response({"detail": "File is already deleted"}, status=status.HTTP_400_BAD_REQUEST)

            # Perform soft delete by setting deleted_at timestamp
            from django.utils import timezone
            file_obj.deleted_at = timezone.now()
            file_obj.save(update_fields=['deleted_at'])

            return Response({
                "detail": f"File '{file_name}' deleted successfully",
                "file_id": file_obj.id,
                "deleted_at": file_obj.deleted_at
            }, status=status.HTTP_200_OK)

        except File.DoesNotExist:
            return Response({"detail": "File not found in database"}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return Response({"detail": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class UploadFileView(APIView):
    """
    API endpoint to upload a file to MinIO under a specific prefix.
    """
    parser_classes = [MultiPartParser]  # Allow multipart file uploads

    def post(self, request, prefix):
        bucket_name = settings.MINIO_STORAGE_BUCKET_NAME
        file = request.FILES.get('file')
        file_name = file.name
        file_extension = os.path.splitext(file_name)[1].lower()
        print('file_extension: {file_extension}')
        if file_extension not in MIME_TYPES:
            return Response(
                {"error": f"File type {file_extension} is not allowed. Allowed types: {list(MIME_TYPES.keys())}"},
                status=status.HTTP_400_BAD_REQUEST
            )

        if not file:
            return Response({"detail": "No file provided"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            file_name = prefix + "/" + file.name  # Combine prefix and file name to store under the prefix

            # Upload the file to MinIO
            minio_client.put_object(bucket_name, file_name, file, file.size)

            return Response({"detail": f"File {file.name} uploaded successfully under {prefix}"}, status=status.HTTP_201_CREATED)

        except Exception as e:
            return Response({"error_detail": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class RenameFileView(APIView):
    """
    API endpoint to rename a file in MinIO under a specific prefix.
    """

    def put(self, request, prefix, old_file_name, new_file_name):
        bucket_name = settings.MINIO_STORAGE_BUCKET_NAME

        try:
            # Extract file extension from the old file name
            file_extension = os.path.splitext(old_file_name)[1]

            # Ensure new file name includes the original extension
            if not new_file_name.endswith(file_extension):
                new_file_name += file_extension

            old_file_path = f"{prefix}/{old_file_name}"
            new_file_path = f"{prefix}/{new_file_name}"

            copy_source = CopySource(bucket_name, old_file_path)

            # Copy the file to the new path
            minio_client.copy_object(
                bucket_name, new_file_path,
                copy_source
            )

            # Delete the old file
            minio_client.remove_object(bucket_name, old_file_path)

            return Response(
                {"detail": f"File renamed from {old_file_name} to {new_file_name}"},
                status=status.HTTP_200_OK
            )

        except Exception as e:
            return Response({"detail": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
