from rest_framework import generics, permissions
from .serializers import Error, ErrorSerializers
from rest_framework.parsers import JSONParser
from rest_framework.response import Response
from rest_framework import status
import json
from project.utils import is_admin

# Create your views here.


class ErrorListCreateAPIView(generics.ListCreateAPIView):

    serializer_class = ErrorSerializers
    permission_classes = (permissions.AllowAny,)
    queryset = Error.objects.all()

    def get(self, request, *args, **kwargs):
        user = request.user
        if not is_admin(user):
            return Response(status=status.HTTP_403_FORBIDDEN)
        errors_serialized = ErrorSerializers(Error.objects.all(), many=True)

        return Response(errors_serialized.data)

    def post(self, request, *args, **kwargs):
        data = JSONParser().parse(request)
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
        platform = ""
        if formated_headers.get("Http-Sec-Ch-Ua") is not None:
            browser = formated_headers["Http-Sec-Ch-Ua"]
        else:
            browser = formated_headers['Http-User-Agent']
        if formated_headers.get("Http-Sec-Ch-Ua-Platform") is not None:
            platform = formated_headers["Http-Sec-Ch-Ua-Platform"]
        else:
            platform = "Check In Browser"
        print(formated_headers)
        Error.objects.create(
            message=data, ip=formated_headers['Remote-Addr'], browser=browser, platform=platform)
        return Response({"status", status.HTTP_200_OK})

    def delete(self, request, *args, **kwargs):
        user = request.user
        if not is_admin(user):
            return Response(status=status.HTTP_403_FORBIDDEN)
        data = JSONParser().parse(request)
        ids_to_delete = data.get("ids", [])

        if not ids_to_delete:
            return Response({"message": "Aucun ID à supprimer fourni"}, status=status.HTTP_400_BAD_REQUEST)
        try:
            Error.objects.filter(id__in=ids_to_delete).delete()

            return Response({"message": "Suppression réussie"}, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({"message": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
