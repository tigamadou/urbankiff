from rest_framework import serializers
from .models import Like
# from ..user.serializers import UserSerializer
# from ..post.serializers import PostSerializers


class LikeSerializer(serializers.ModelSerializer):
    class Meta:
        model = Like
        fields = '__all__'
