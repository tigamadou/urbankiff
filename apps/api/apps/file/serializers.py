import mimetypes

from django.contrib.auth import get_user_model
from rest_framework import serializers

from .models import File
from .libs import signed_url


class FileSerializer(serializers.ModelSerializer):
    owner = serializers.PrimaryKeyRelatedField(
        queryset=get_user_model().objects.all(),
        default=serializers.CurrentUserDefault()
    )

    class Meta:
        model = File
        extra_kwargs = {
            'mime_type': {'read_only': True},
        }
        fields = (
            'id',
            'owner',
            'name',
            'path',
            'url',
            'mime_type',
            'created_at',
            'updated_at',
            'deleted_at',
        )


class CreateSignedFileSerializer(serializers.Serializer):
    file_name = serializers.CharField(write_only=True)
    acl = serializers.CharField(write_only=True, required=False)
    content_type = serializers.CharField(write_only=True, required=False)

    file_id = serializers.IntegerField(read_only=True)
    url = serializers.URLField(read_only=True)
    s3_data = serializers.JSONField(read_only=True)

    def create(self, validated_data):
        file_name = validated_data['file_name'].replace(' ', '_')

        signed = signed_url(
            file_name=file_name,
            content_type=validated_data.get('content_type', None)
        )

        mime_type, encoding = mimetypes.guess_type(signed['url'])

        file_obj = File.objects.create(
            owner=self.context['request'].user,
            name=file_name,
            path='uploads',
            mime_type=mime_type or ''
        )

        return {
            's3_data': signed['data'],
            'url': signed['url'],
            'file_id': file_obj.id
        }


class MinioUploadSerializer(serializers.Serializer):
    file = serializers.FileField()
