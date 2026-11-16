from rest_framework import serializers
from .models import Page


class PageSerializers(serializers.ModelSerializer):
    class Meta:
        model = Page
        fields = ["id", "title", "slug", "content", "published",
                  "deleted", "views", "created_at", "updated_at", "language"]
