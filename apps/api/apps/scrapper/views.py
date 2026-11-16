
# Create your views here.
from .serializers import Scrapper, ScrapperSerializer
from rest_framework import generics, permissions


class ScrapperListCreateAPIView(generics.ListCreateAPIView):
    serializer_class = ScrapperSerializer
    permission_classes = (permissions.AllowAny,)
    queryset = Scrapper.objects.all()


class ScrapperDetailAPIView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = ScrapperSerializer
    permission_classes = (permissions.AllowAny,)
    queryset = Scrapper.objects.all()
    lookup_field = "id"
