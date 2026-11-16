from rest_framework import serializers
from .models import Comment, Comment_Posts, Comment_Users, SubComment, Report
from django.contrib.auth import get_user_model
from apps.post.serializers import PostSerializers


class CommentUserSerializers(serializers.ModelSerializer):

    class Meta:
        model = Comment_Users
        fields = '__all__'


class CommentPostSerializers(serializers.ModelSerializer):

    class Meta:
        model = Comment_Posts
        fields = '__all__'


class SubCommentSerializers(serializers.ModelSerializer):

    class Meta:
        model = SubComment
        fields = '__all__'

    def to_representation(self, instance):
        representation = super().to_representation(instance)
        user_id = representation.pop('user')
        user = get_user_model().objects.filter(id=user_id).first()
        if user:
            representation['user'] = f"{user.firstname} {user.lastname}"
            representation['avatar'] = user.avatar
        return representation


class CommentSerializers(serializers.ModelSerializer):
    user_id = serializers.SerializerMethodField()
    post_id = serializers.SerializerMethodField()

    class Meta:
        model = Comment
        fields = ['id', 'created_date', 'updated_date',
                  'content', 'user_id', 'post_id', 'blocked']

    def get_user_id(self, obj):
        user_associated = Comment_Users.objects.filter(comment=obj).first()
        return user_associated.user_id if user_associated else None

    def get_post_id(self, obj):
        post_associated = Comment_Posts.objects.filter(comment=obj).first()
        return post_associated.post_id if post_associated else None

    def to_representation(self, instance):
        representation = super().to_representation(instance)
        user_id = representation.pop('user_id')
        user = get_user_model().objects.filter(id=user_id).first()
        if user:
            representation['user'] = f"{user.firstname} {user.lastname}"
            representation['avatar'] = user.avatar
            representation['user_id'] = user.id
        return representation


class ReportSerializers(serializers.ModelSerializer):
    post = PostSerializers()

    class Meta:
        model = Report
        fields = "__all__"
