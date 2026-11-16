from rest_framework import serializers
from .models import Post, Tag
from apps.category.serializers import CategorySerializers
from apps.user.serializers import UserSerializer


class TagSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tag
        fields = ['id', 'name', 'slug']


class PostSerializers(serializers.ModelSerializer):
    category = CategorySerializers()
    author = UserSerializer()
    tags = TagSerializer(many=True, read_only=True)
    view_count = serializers.SerializerMethodField()

    class Meta:
        model = Post
        fields = ["id", "title", "slug", "intro", "content", "url", "status", "image", "audio", "video", "published",
                  "deleted", "created_at", "updated_at", "language", "author", "category", 'view_count', 'tags']

    def get_view_count(self, obj):
        return obj.views.count()
