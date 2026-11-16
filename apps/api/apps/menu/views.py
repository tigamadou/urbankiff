from rest_framework import generics, permissions
from .serializers import Menu, MenuSerializers
# Create your views here.


class MenuListCreateAPIView(generics.ListCreateAPIView):
    serializer_class = MenuSerializers
    permission_classes = (permissions.AllowAny,)
    queryset = Menu.objects.all()


class MenuDetailsAPIView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = MenuSerializers
    permission_classes = (permissions.AllowAny,)
    queryset = Menu.objects.all()
    lookup_field = "id"
