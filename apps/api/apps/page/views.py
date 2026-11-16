from rest_framework import generics, permissions
from .serializers import Page, PageSerializers
from rest_framework.parsers import JSONParser
from rest_framework.response import Response
from rest_framework import status
# Create your views here.

from project.utils import is_admin


class PageListCreateAPIView(generics.ListCreateAPIView):

    serializer_class = PageSerializers
    permission_classes = (permissions.AllowAny,)
    queryset = Page.objects.all().order_by("-created_at")

    def post(self, request, *args, **kwargs):
        user = request.user
        if not is_admin(user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        data = JSONParser().parse(request)
        title = data["title"]
        content = data["content"]
        published = data["published"]
        deleted = data["deleted"]
        views = data["views"]
        language = data["language"]
        page = Page.objects.create(title=title, content=content, published=published, deleted=deleted, views=views, language=language)
        page.save()
        return Response({"status": status.HTTP_201_CREATED})


class PageDetailsAPIView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = PageSerializers
    permission_classes = (permissions.AllowAny,)
    queryset = Page.objects.all()
    lookup_field = "id"

    def put(self, request, *args, **kwargs):
        user = request.user
        if not is_admin(user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        data = JSONParser().parse(request)
        page_id = data["id"]
        title = data["title"]
        content = data["content"]
        published = data["published"]
        language = data["language"]
        page = Page.objects.get(id=page_id)
        page.title = title
        page.content = content
        page.published = published
        page.language = language
        page.save()

        return Response({"status": status.HTTP_200_OK})

    def delete(self, request, *args, **kwargs):
        user = request.user
        if not is_admin(user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        page = Page.objects.get(id=kwargs["id"])
        page.deleted = True
        page.published = False
        page.save()
        print(page.deleted)
        return Response({"status": status.HTTP_200_OK})

# ========================================================
#    Ubnews frontend
# ========================================================


class IncrementViewPage(generics.CreateAPIView):
    serializer_class = PageSerializers
    permission_classes = (permissions.AllowAny,)
    queryset = Page.objects.all()

    def page(self, request, *args, **kwargs):
        params = JSONParser().parse(request)
        page = Page.objects.get(id=params["id"])
        page.views = page.views + 1
        page.save()
        return Response({"status": status.HTTP_200_OK})


class GetPageByTitleView(generics.RetrieveAPIView):
    serializer_class = PageSerializers
    permission_classes = (permissions.AllowAny,)
    queryset = Page.objects.all()
    lookup_field = "title"

    def get(self, request, *args, **kwargs):
        lang = "fr" if kwargs['lang'] == "fr" else "en"
        page = Page.objects.get(title=kwargs["title"], language=lang)
        page_serializer = PageSerializers(page)
        return Response({"data": page_serializer.data}, status=status.HTTP_200_OK)
