from minio import Minio
from django.conf import settings
from django.core.files.storage import default_storage

# Create MinIO client
minio_client = Minio(
    settings.MINIO_STORAGE_ENDPOINT,
    access_key=settings.MINIO_STORAGE_ACCESS_KEY,
    secret_key=settings.MINIO_STORAGE_SECRET_KEY,
    secure=settings.MINIO_STORAGE_USE_HTTPS,
)


def upload_file_to_minio(file):
    # Generate a unique file name or use the original one
    file_name = default_storage.get_available_name(file.name)

    # Upload the file to the MinIO bucket
    minio_client.put_object(
        settings.MINIO_STORAGE_BUCKET_NAME,
        file_name,
        file,
        file.size
    )
    return file_name
