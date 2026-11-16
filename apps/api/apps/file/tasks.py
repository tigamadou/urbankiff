import io
import logging
import mimetypes

import requests
from PIL import Image as PImage
from django.conf import settings
from apps.workers import task

from .libs import upload_file, create_read_url
from .models import File


log = logging.getLogger(__name__)


def _get_size(image, width):
    """
    Determines the new image width/height based on given image dimensions and a new width
    """
    width_percent = width / float(image.size[0])
    height = float(image.size[1]) * width_percent
    return (width, height)


def _get_format(file_obj):
    """
    This is specific to PIL to ensure we use the right format name
    """
    if file_obj.mime_type:
        file_mime = file_obj.mime_type
    else:
        file_mime, encoding = mimetypes.guess_type(file_obj.name)

    if file_mime in ('image/jpeg', 'image/jpg'):
        return 'JPEG'

    if file_mime == 'image/png':
        return 'PNG'

    raise Exception('unsupported image mime type: {0}'.format(file_mime))


# @task(schedule=settings.FILE_IMAGE_RESIZE_SCHEDULE)
def resize_images():
    """
    Get all images to be resized and push into their own tasks
    """
    images = File.objects.filter(
        mime_type__in=File.IMAGE_MIME_TYPES
    ).all()
    [resize_image(img.id) for img in images]


@task()
def resize_image(file_id):
    file_obj = File.objects.get(pk=file_id)
    file_url = create_read_url(file_obj.s3_object_key)
    res = requests.get(file_url, stream=True)

    if res.status_code >= 300:
        raise Exception('{0}: {1}'.format(res.status_code, res.content))

    orig = PImage.open(res.raw)
    acl = 'public-read'  # Default to public since is_private field is removed

    for size in settings.FILE_IMAGE_SIZES:
        mem = io.BytesIO()
        img = orig.copy()

        img.thumbnail(_get_size(img, size['width']), PImage.ANTIALIAS)
        img.save(mem,
                 format=_get_format(file_obj),
                 quality=size.get('quality', 95))

        mem.seek(0)
        # Generate variant path for different image sizes
        variant_path = f"{file_obj.s3_object_key}_{size['key']}"
        upload_file(variant_path, mem, acl=acl)

        mem.close()
        img.close()

    # Note: is_verified and is_resized fields are removed
    # File processing completion should be handled differently
