from django.contrib.auth import get_user_model
from django.db import models


class File(models.Model):
    IMAGE_MIME_TYPES = ('image/jpeg', 'image/png')

    owner = models.ForeignKey(
        get_user_model(), on_delete=models.CASCADE, related_name='files')
    name = models.CharField(max_length=255, default='')
    path = models.CharField(max_length=255, default='uploads')
    url = models.URLField(max_length=500, blank=True)
    mime_type = models.CharField(max_length=25)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    deleted_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return self.name

    @property
    def is_image(self):
        return self.mime_type in File.IMAGE_MIME_TYPES

    @property
    def s3_object_key(self):
        """Return the S3 object key (file name) for this file."""
        return self.name

    def delete(self, *args, **kwargs):
        """ Delete the actual file, when the model instance is deleted.
        """
        # Note: File deletion logic should be handled at the application level
        # since we now store only the path, not the FileField
        super().delete(*args, **kwargs)
