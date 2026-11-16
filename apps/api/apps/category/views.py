from rest_framework import generics, permissions
from .serializers import Category, CategorySerializers
from rest_framework.response import Response
from rest_framework import status
from project.utils import is_admin

# Create your views here.


class CategoryListCreateAPIView(generics.ListCreateAPIView):

    serializer_class = CategorySerializers
    permission_classes = (permissions.AllowAny,)
    queryset = Category.objects.all()


class CategoryDetailsAPIView(generics.RetrieveUpdateDestroyAPIView):

    serializer_class = CategorySerializers
    permission_classes = (permissions.AllowAny,)
    queryset = Category.objects.all()
    lookup_field = "id"

    def post(self, request, *args, **kwargs):
        user = request.user
        if not is_admin(user):
            return Response(status=status.HTTP_403_FORBIDDEN)
        serializer = CategorySerializers(data=request.data)
        if serializer.is_valid():
            category = serializer.save()
            return Response(CategorySerializers(category).data, status=status.HTTP_201_CREATED)
        return Response(status=status.HTTP_400_BAD_REQUEST)

    def put(self, request, *args, **kwargs):
        user = request.user
        if not is_admin(user):
            return Response(status=status.HTTP_403_FORBIDDEN)
        try:
            category = Category.objects.get(id=kwargs["id"])
        except Category.DoesNotExist:
            return Response({"message": "La catégorie n'existe pas"}, status=status.HTTP_404_NOT_FOUND)
        data = request.data
        serializer = CategorySerializers(category, data=data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(CategorySerializers(category).data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class GetCategoryNameAPIView(generics.RetrieveAPIView):

    serializer_class = CategorySerializers
    permission_classes = (permissions.AllowAny,)
    queryset = Category.objects.all()

    def get(self, request, *args, **kwargs):
        category = Category.objects.filter(slug=kwargs["slug"])
        if len(category) > 0:
            category_serializer = CategorySerializers(category, many=True)
            return Response({"category": category_serializer.data, "status": status.HTTP_200_OK})
        else:
            return Response({"status": status.HTTP_404_NOT_FOUND})
