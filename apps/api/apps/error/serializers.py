from rest_framework import serializers
from .models import Error


class ErrorSerializers(serializers.ModelSerializer):

    class Meta:
        model = Error
        fields = '__all__'
