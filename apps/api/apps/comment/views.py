from rest_framework import generics, permissions
from .serializers import Comment, CommentSerializers, Comment_Users, Comment_Posts, SubCommentSerializers, SubComment
from rest_framework.response import Response
from ..post.models import Post
from rest_framework import status
from django.db import transaction
from django.db.models import Q
from django.shortcuts import get_object_or_404
from project.utils import is_admin

# Create your views here.


class CommentListCreateView(generics.ListCreateAPIView):
    queryset = Comment.objects.all()
    serializer_class = CommentSerializers
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]
    lookup_field = "id"

    def get(self, request, *args, **kwargs):
        blocked_param = self.request.query_params.get('blocked', "false")
        user = request.user
        queryset = None
        if is_admin(user):
            queryset = Comment.objects.all()
        else:
            queryset = Comment.objects.filter(
                Q(comment_posts__post__author=user)
            )

        if blocked_param is not None:
            blocked = blocked_param.lower() == 'true'
            queryset = queryset.filter(blocked=blocked)

        serializer = CommentSerializers(queryset, many=True)

        return Response(serializer.data)

    def post(self, request, *args, **kwargs):
        user = self.request.user
        post_id = kwargs['post_id']

        try:
            post = Post.objects.get(id=post_id)
        except Post.DoesNotExist:
            return Response(
                data={'error': 'Le post spécifié n\'existe pas.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        with transaction.atomic():
            comment = serializer.save()
            Comment_Users.objects.create(comment=comment, user=user)
            Comment_Posts.objects.create(comment=comment, post=post)

        return Response(serializer.data, status=status.HTTP_201_CREATED)


class SubCommentListCreateView(generics.RetrieveUpdateDestroyAPIView):
    queryset = SubComment.objects.all()
    serializer_class = SubCommentSerializers
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]
    lookup_field = "id"

    def post(self, request, *args, **kwargs):
        user = request.user
        comment_id = kwargs['comment_id']

        try:
            comment = Comment.objects.get(id=comment_id)
        except Comment.DoesNotExist:
            return Response(status=status.HTTP_400_BAD_REQUEST)

        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        subComment = serializer.save(user=user)
        comment.sub_comments.add(subComment)

        return Response(serializer.data, status=status.HTTP_201_CREATED)


class CommentDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Comment.objects.all()
    serializer_class = CommentSerializers
    permission_classes = [permissions.AllowAny]
    lookup_field = "id"

    def get(self, request, *args, **kwargs):
        user = request.user
        queryset = None
        try:
            if is_admin(user):
                queryset = Comment.objects.get(id=kwargs["id"])
            else:
                queryset = Comment.objects.get(
                    Q(comment_posts__post__author=user)
                )

        except Comment.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

        serializer = CommentSerializers(queryset)

        return Response(serializer.data)


class CommentsByPostView(generics.ListAPIView):
    queryset = Comment.objects.all()
    serializer_class = CommentSerializers
    permission_classes = [permissions.AllowAny]
    lookup_field = "id"

    def get(self, request, *args, **kwargs):
        post_id = kwargs['post_id']
        position = request.query_params.get('position', None)
        comments_per_page = 10

        if position:
            try:
                position = int(position)
            except ValueError:
                position = 0

        queryset = []
        if position and position != 0:
            queryset = Comment.objects.filter(Q(comment_posts__post_id=post_id)
                                              ).order_by('-created_date')[position:comments_per_page]
        else:
            queryset = Comment.objects.filter(
                Q(comment_posts__post_id=post_id)
            ).order_by('-created_date')[:comments_per_page]
        serializer = CommentSerializers(queryset, many=True)

        return Response(serializer.data)


class SubCommentsByCommentView(generics.ListAPIView):
    queryset = SubComment.objects.all()
    serializer_class = SubCommentSerializers
    permission_classes = [permissions.AllowAny]

    def list(self, request, *args, **kwargs):
        comment_id = kwargs['comment_id']
        comment = get_object_or_404(Comment, id=comment_id)

        position = request.query_params.get('position', None)
        limit = 5

        try:
            position = int(position)
        except (ValueError, TypeError):
            position = 0

        all_sub_comments = comment.sub_comments.all().order_by("-created_date")

        if position and position > 0:
            sub_comments = all_sub_comments[position:limit]
        else:
            sub_comments = all_sub_comments[:1]

        serializer = SubCommentSerializers(sub_comments, many=True)

        if not sub_comments.exists():
            return Response([])

        return Response(serializer.data)


class CommentsByUserView(generics.ListAPIView):
    queryset = Comment.objects.all()
    serializer_class = CommentSerializers
    permission_classes = [permissions.AllowAny]
    lookup_field = "id"

    def get_queryset(self):
        user_id = self.kwargs['user_id']

        queryset = Comment.objects.filter(comment_users__user_id=user_id)

        return queryset


class BlockCommentView(generics.UpdateAPIView):
    queryset = Comment.objects.all()
    serializer_class = CommentSerializers
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]
    lookup_field = "id"

    def update(self, request, *args, **kwargs):
        user = request.user
        is_admin_user = is_admin(user)

        queryset = Comment.objects.filter(Q(id=kwargs["id"]))

        if not is_admin_user:
            queryset = queryset.filter(Q(comment_posts__post__author=user))

        if not queryset.exists():
            queryset = SubComment.objects.filter(Q(id=kwargs["id"]))

            if not is_admin_user:
                queryset = queryset.filter(Q(comment_posts__post__author=user))

        if not queryset.exists():
            return Response(status=status.HTTP_404_NOT_FOUND)

        instance = queryset.first()

        if instance.blocked:
            instance.blocked = False
        else:
            instance.blocked = True

        instance.save()
        return Response(status=status.HTTP_200_OK)
