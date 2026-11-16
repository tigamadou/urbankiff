from .models import Scrapper
from rest_framework import serializers


class ScrapperSerializer(serializers.ModelSerializer):

    class Meta:
        model = Scrapper
        fields = "__all__"
