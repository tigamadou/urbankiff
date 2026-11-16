from .models import TwilioService
from rest_framework import serializers


class TwilioServiceSerializer(serializers.ModelSerializer):
    class Meta:
        model = TwilioService
        fields = "__all__"
