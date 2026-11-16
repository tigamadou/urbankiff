from rest_framework import generics, permissions
from .serializers import Post, PostSerializers, Tag, TagSerializer
from apps.category.models import Category
from apps.comment.serializers import Report, ReportSerializers
from rest_framework.parsers import JSONParser
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework import status
from rolepermissions.checkers import has_role
import json
from apps.comment.models import Comment
from django.db.models import Q, Count
from .models import PostView
from libs.cache_handler import get_or_set_cache, generate_cache_key
from rest_framework.pagination import PageNumberPagination
# Create your views here.


class PostListCreateAPIView(generics.ListCreateAPIView):
    serializer_class = PostSerializers
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        """Override get_queryset to ensure proper filtering of deleted posts"""
        user = self.request.user
        if has_role(user, "administrator") or has_role(user, "editor"):
            # Admins and editors can see all posts (including deleted ones for management)
            return Post.objects.all().order_by("-created_at")
        else:
            # Regular users only see their own non-deleted posts
            return Post.objects.filter(author=user, deleted=False).order_by("-created_at")

    def get(self, request, *args, **kwargs):
        def fetch_data():
            queryset = self.get_queryset()
            return self.get_serializer(queryset, many=True).data

        cache_timeout = 300  # Cache timeout in seconds (5 minutes)
        cache_key = generate_cache_key('post_get_list', request.query_params.dict())
        data = get_or_set_cache(cache_key, cache_timeout, fetch_data)
        return Response(data)

    def post(self, request, *args, **kwargs):
        data = JSONParser().parse(request)
        title = data["title"]
        intro = data["intro"]
        content = data["content"]
        image = data["image"]
        audio = data["audio"]
        video = data["video"]
        url = data["url"]
        slug = data["slug"]
        published = data["published"]
        deleted = data["deleted"]
        language = data["language"]
        category_id = data["category"]["id"]
        tags_ids = data["tags"]
        category = Category.objects.get(id=category_id)
        post = Post.objects.create(title=title, intro=intro, content=content,
                                   slug=slug, image=image, audio=audio, video=video, url=url, published=published, deleted=deleted, author=self.request.user, language=language, category=category)
        post.tags.set(tags_ids)
        post.save()
        return Response({"status": status.HTTP_201_CREATED})


class PostDetailsAPIView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = PostSerializers
    permission_classes = (permissions.AllowAny,)
    lookup_field = "id"

    def get_queryset(self):
        """Override get_queryset to ensure proper filtering of deleted posts"""
        user = self.request.user
        if has_role(user, "administrator") or has_role(user, "editor"):
            # Admins and editors can see all posts (including deleted ones for management)
            return Post.objects.all()
        else:
            # Regular users only see their own non-deleted posts
            return Post.objects.filter(author=user, deleted=False)

    def put(self, request, *args, **kwargs):
        # Get user info and his permissions
        user = request.user

        # Get data to edit
        data = JSONParser().parse(request)
        post_id = data["id"]
        title = data["title"]
        slug = data["slug"]
        intro = data["intro"]
        content = data["content"]
        image = data["image"]
        audio = data["audio"]
        video = data["video"]
        post_status = data["status"]
        language = data["language"]
        url = data["url"]
        published = data["published"]
        category_id = data["category"]["id"]
        tags_ids = data["tags"]
        category = Category.objects.get(id=category_id)
        post = None
        try:
            post = Post.objects.get(id=post_id, author=user)
        except Post.DoesNotExist:
            if not has_role(user, "administrator") or not has_role(user, "editor"):
                return Response({"status": status.HTTP_403_FORBIDDEN})
            post = Post.objects.get(id=post_id)

        post.title = title
        post.slug = slug
        post.intro = intro
        post.content = content
        post.image = image
        post.audio = audio
        post.video = video
        post.url = url
        post.published = published
        post.category = category
        post.language = language
        post.status = post_status
        post.tags.set(tags_ids)
        post.save()

        return Response({"status": status.HTTP_200_OK})

    def delete(self, request, *args, **kwargs):
        post = Post.objects.get(id=kwargs["id"])
        post.deleted = True
        post.published = False
        post.save()
        print(post.deleted)
        return Response({"status": status.HTTP_200_OK})

# ========================================================
#    Ubnews frontend
# ========================================================


class FetchPostData(generics.ListCreateAPIView):
    serializer_class = PostSerializers
    permission_classes = (permissions.AllowAny,)

    def get_queryset(self):
        """Override get_queryset to ensure proper filtering of deleted posts"""
        params = self.request.GET.dict()
        language = self.request.language
        last_post = int(params.get('last_post', 0))
        post_limit = int(params.get("post_limit", 12))

        base_queryset = Post.objects.filter(
            language__exact=language,
            deleted=False,
            published=True
        )

        if last_post != 0:
            try:
                post = Post.objects.get(pk=last_post)
                return base_queryset.filter(created_at__lt=post.created_at).order_by('-created_at')[:post_limit]
            except Post.DoesNotExist:
                return base_queryset.order_by("-created_at")[:post_limit]
        else:
            return base_queryset.order_by("-created_at")[:post_limit]

    def get(self, request, *args, **kwargs):
        def fetch_data():
            queryset = self.get_queryset()
            post_serializer = PostSerializers(queryset, many=True)
            return post_serializer.data

        cache_timeout = 300  # Cache timeout in seconds (5 minutes)
        cache_key = generate_cache_key('fetch_post_data', request.query_params.dict())
        data = get_or_set_cache(cache_key, cache_timeout, fetch_data)
        return Response(data)


class FetchLastPost(generics.RetrieveAPIView):
    serializer_class = PostSerializers
    permission_classes = (permissions.AllowAny,)

    def get_queryset(self):
        """Override get_queryset to ensure proper filtering of deleted posts"""
        language = self.request.language
        return Post.objects.filter(
            language__exact=language,
            deleted=False,
            published=True
        ).order_by('created_at')

    def get(self, request, *args, **kwargs):
        post = self.get_queryset().first()
        if post:
            post_serializer = PostSerializers(post)
            return Response(post_serializer.data)
        return Response({"message": "No posts found"}, status=404)


class FetchSlugPost(generics.RetrieveAPIView):
    serializer_class = PostSerializers
    permission_classes = (permissions.AllowAny,)

    def get_queryset(self):
        """Override get_queryset to ensure proper filtering of deleted posts"""
        slug = self.kwargs.get("slug")
        return Post.objects.filter(
            slug=slug,
            deleted=False,
            published=True
        )

    def get(self, request, *args, **kwargs):
        def fetch_data():
            queryset = self.get_queryset()
            post_serializer = PostSerializers(queryset, many=True)
            return post_serializer.data
        cache_timeout = 300  # Cache timeout in seconds (5 minutes)
        cache_key = generate_cache_key('fetch_slug_post', kwargs)
        data = get_or_set_cache(cache_key, cache_timeout, fetch_data)
        return Response(data)


class MostViewedPostsView(generics.RetrieveAPIView):
    serializer_class = PostSerializers
    permission_classes = (permissions.AllowAny,)

    def get_queryset(self):
        """Override get_queryset to ensure proper filtering of deleted posts"""
        lang = self.kwargs.get('lang')
        post_title = self.kwargs.get('post_title')

        return Post.objects.filter(
            published=True,
            deleted=False,
            language=lang
        ).exclude(slug=post_title).annotate(
            view_count=Count('views')
        ).order_by('-view_count')[:10]

    def get(self, request, *args, **kwargs):
        def fetch_data():
            queryset = self.get_queryset()
            post_serializer = PostSerializers(queryset, many=True)
            return post_serializer.data

        cache_timeout = 300  # Cache timeout in seconds (5 minutes)
        cache_key = generate_cache_key('get_most_views', kwargs)
        data = get_or_set_cache(cache_key, cache_timeout, fetch_data)
        return Response(data)


class IncrementViewPost(generics.CreateAPIView):
    serializer_class = PostSerializers
    permission_classes = (permissions.AllowAny,)

    def get_queryset(self):
        """Override get_queryset to ensure proper filtering of deleted posts"""
        return Post.objects.filter(deleted=False, published=True)

    def post(self, request, *args, **kwargs):
        params = request.data
        try:
            post = self.get_queryset().get(id=params["id"])
            post.views = post.views + 1
            post.save()
            return Response({"status": status.HTTP_200_OK})
        except Post.DoesNotExist:
            return Response({"error": "Post not found"}, status=404)


class FetchCategoryPostData(generics.ListCreateAPIView):
    serializer_class = PostSerializers
    permission_classes = (permissions.AllowAny,)

    def get_queryset(self):
        """Override get_queryset to ensure proper filtering of deleted posts"""
        params = self.request.GET.dict()
        language = self.request.language
        last_post = int(params.get('last_post', 0))
        name = params.get("name")

        base_queryset = Post.objects.filter(
            category__slug=name,
            language__exact=language,
            deleted=False,
            published=True
        )

        if last_post != 0:
            try:
                post = Post.objects.get(pk=last_post)
                return base_queryset.filter(created_at__lt=post.created_at).order_by('-created_at')[:12]
            except Post.DoesNotExist:
                return base_queryset.order_by("-created_at")[:12]
        else:
            return base_queryset.order_by("-created_at")[:12]

    def get(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        post_serializer = PostSerializers(queryset, many=True)
        return Response(post_serializer.data)


class FetchCategoryLastPost(generics.RetrieveAPIView):
    serializer_class = PostSerializers
    permission_classes = (permissions.AllowAny,)

    def get_queryset(self):
        """Override get_queryset to ensure proper filtering of deleted posts"""
        name = self.kwargs.get("name")
        return Post.objects.filter(
            category__name=name,
            deleted=False,
            published=True
        ).order_by('created_at')

    def get(self, request, *args, **kwargs):
        post = self.get_queryset().first()
        if post:
            post_serializer = PostSerializers(post)
            return Response(post_serializer.data)
        return Response({"message": "No posts found"}, status=404)


class SearchPost(generics.ListCreateAPIView):
    serializer_class = PostSerializers
    permission_classes = (permissions.AllowAny,)

    def get_queryset(self):
        """Override get_queryset to ensure proper filtering of deleted posts"""
        language = self.request.language
        search_query = self.request.GET.get('search_query', "")

        return Post.objects.filter(
            Q(title__icontains=search_query) | Q(intro__icontains=search_query),
            language__exact=language,
            deleted=False,
            published=True
        )

    def get(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        posts_serializer = PostSerializers(queryset, many=True)
        return Response(posts_serializer.data)


class ReportListCreateAPIView(generics.ListCreateAPIView):
    serializer_class = ReportSerializers
    queryset = Report.objects.all()
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, *args, **kwargs):
        data = JSONParser().parse(request)
        post_id = data.get("post_id", None)
        comment_id = data.get("comment_id", None)
        reason = data['reason']

        user = request.user
        headers = {}
        for header, value in request.META.items():
            header = '-'.join([h.capitalize()
                               for h in header.lower().split('_')])
            if value is None or value == "":
                continue
            else:
                headers[header] = "{}".format(value)
        formated_headers = json.loads(json.dumps(headers))
        browser = ""
        if formated_headers.get("Http-Sec-Ch-Ua") is not None:
            browser = formated_headers["Http-Sec-Ch-Ua"]
        else:
            browser = formated_headers['Http-User-Agent']
        ip = formated_headers['Remote-Addr']
        if post_id:
            try:
                post = Post.objects.get(pk=post_id, deleted=False, published=True)
                Report.objects.create(post=post, reason=reason,
                                      reporter=user, ip=ip, browser=browser)
                return Response({"message": "A post have been report!"}, status=status.HTTP_201_CREATED)
            except Post.DoesNotExist:
                return Response({"error": "Post not found or not available for reporting"}, status=404)
        elif comment_id:
            comment = Comment.objects.get(pk=comment_id)
            Report.objects.create(comment=comment, reason=reason,
                                  reporter=user, ip=ip, browser=browser)
            return Response({"message": "A post have been report!"}, status=status.HTTP_201_CREATED)


class RecordPostView(APIView):
    permission_classes = (permissions.AllowAny,)

    def post(self, request, post_id, *args, **kwargs):
        try:
            post = Post.objects.get(id=post_id, deleted=False, published=True)
        except Post.DoesNotExist:
            return Response({"error": "Post not found"}, status=status.HTTP_404_NOT_FOUND)

        # Get IP address for the view
        ip_address = request.META.get('REMOTE_ADDR')
        user_agent = request.META.get('HTTP_USER_AGENT', 'Unknown')

        # Create a new PostView record
        PostView.objects.create(post=post, ip_address=ip_address, user_agent=user_agent)
        return Response({"message": "View recorded successfully"}, status=status.HTTP_201_CREATED)


class TagView(generics.ListCreateAPIView):
    serializer_class = TagSerializer
    queryset = Tag.objects.all()
    permission_classes = (permissions.IsAuthenticated,)


class PostsByTagView(APIView):
    """
    API endpoint to retrieve all posts associated with a specific tag.
    """
    permission_classes = (permissions.AllowAny,)

    def get(self, request, tag_name):
        try:
            tag = Tag.objects.get(name=tag_name)
            posts = tag.posts.filter(deleted=False, published=True)  # Filter out deleted posts
            serializer = PostSerializers(posts, many=True)
            return Response(serializer.data, status=status.HTTP_200_OK)
        except Tag.DoesNotExist:
            return Response(
                {"detail": f"Tag '{tag_name}' not found."},
                status=status.HTTP_404_NOT_FOUND
            )


class PostFetchListAPIView(APIView):
    permission_classes = (permissions.AllowAny,)

    def get(self, request):
        # Query parameters
        category = request.query_params.get('category')
        tag = request.query_params.get('tag')
        language = request.query_params.get('language')
        limit = request.query_params.get('limit', 10)

        # Filter queryset - ensure deleted posts are excluded
        queryset = Post.objects.filter(deleted=False, published=True).order_by('-created_at')
        if category:
            queryset = queryset.filter(category__slug=category)
        if tag:
            queryset = queryset.filter(tags__slug=tag)
        if language:
            queryset = queryset.filter(language=language)

        # Pagination
        paginator = PageNumberPagination()
        paginator.page_size = limit
        paginated_queryset = paginator.paginate_queryset(queryset, request)

        # Serialize data
        serializer = PostSerializers(paginated_queryset, many=True)
        return paginator.get_paginated_response(serializer.data)
