from rest_framework import generics, permissions
from .serializers import LikeSerializer
from rest_framework.response import Response
from ..like.models import Like
from ..post.models import Post
from rest_framework import status

# Create your views here.


class LikeCreateView(generics.CreateAPIView):
    queryset = Like.objects.all()
    serializer_class = LikeSerializer

    def post(self, request, *args, **kwargs):
        user_id = request.user.id
        post_id = request.data.get('post_id')
        post = None

        try:
            post = Post.objects.filter(id=post_id).first()
        except Post.DoesNotExist:
            return Response(status=status.HTTP_400_BAD_REQUEST)

        existing_like = Like.objects.filter(user=user_id, post=post_id).first()

        if existing_like:
            existing_like.delete()
            return Response({'message': 'Like supprimé avec succès'}, status=status.HTTP_204_NO_CONTENT)
        else:
            like_data = {'user': user_id, 'post': post.id}
            serializer = self.get_serializer(data=like_data)
            serializer.is_valid(raise_exception=True)
            serializer.save()
            return Response(status=status.HTTP_201_CREATED)


class PostLikesListView(generics.ListAPIView):
    permission_classes = (permissions.AllowAny,)

    def get(self, request, post_id):
        post_likes = Like.objects.filter(post_id=post_id)
        serializer = LikeSerializer(post_likes, many=True)
        return Response(serializer.data)


class UserLikesListView(generics.ListAPIView):
    def get(self, request, user_id):
        user_likes = Like.objects.filter(user_id=user_id)
        serializer = LikeSerializer(user_likes, many=True)
        return Response(serializer.data)


class UserLikeCheckView(generics.RetrieveAPIView):
    def get(self, request, post_id):
        post = Post.objects.get(pk=post_id)
        try:
            Like.objects.get(user=request.user, post=post)
            return Response({"liked": True})
        except Like.DoesNotExist:
            return Response({"liked": False})
