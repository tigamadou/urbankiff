from django.contrib import admin
from .models import File


@admin.register(File)
class FileAdmin(admin.ModelAdmin):
    list_filter = ('mime_type', 'path', 'created_at', 'deleted_at')
    list_display = ('filename', 'name', 'path', 'url', 'mime_type', 'created_at', 'deleted_at')

    def filename(self, obj):
        return str(obj)
