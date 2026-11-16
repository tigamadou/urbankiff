from .models import TwilioService
from .serializers import TwilioServiceSerializer
from rest_framework import generics, permissions, status
from rest_framework.parsers import JSONParser
from rest_framework.response import Response
import os
from twilio.rest import Client
# Create your views here.
account_sid = os.environ['TWILIO_ACCOUNT_SID']
auth_token = os.environ['TWILIO_AUTH_TOKEN']
client = Client(account_sid, auth_token)


class SendVerifyCode(generics.CreateAPIView):
    permission_classes = (permissions.AllowAny,)
    serializer_class = TwilioServiceSerializer
    queryset = TwilioService.objects.all()

    def post(self, request, *args, **kwargs):
        data = JSONParser().parse(request)
        # ten_minutes_ago = datetime.datetime.now() - datetime.timedelta(minutes=10)
        # service = TwilioService.objects.order_by('-created_at').first()
        # if service.created_at.timestamp() < ten_minutes_ago.timestamp():
        print("Creating new service")
        service_sid = create_twilio_services()
        print(service_sid)
        verification = client.verify.v2.services("{}".format(service_sid)
                                                 ).verifications.create(to="{}".format(data["phonenumber"]), channel='sms')
        return Response({"status": status.HTTP_201_CREATED, "data": verification.status}, status=status.HTTP_201_CREATED)


class VerifyTwilioOTP(generics.CreateAPIView):
    permission_classes = (permissions.AllowAny,)
    serializer_class = TwilioServiceSerializer
    queryset = TwilioService.objects.all()

    def post(self, request, *args, **kwargs):
        data = JSONParser().parse(request)
        service = TwilioService.objects.order_by("-created_at").first()
        print(service.service_id)
        try:
            verification_check = client.verify.v2.services(
                '{}'.format(service.service_id)).verification_checks.create(to="{}".format(data["phonenumber"]), code="{}".format(data["otp"]))
            print(verification_check)
            if verification_check.status == 'approved':
                return Response({"status": status.HTTP_200_OK, "data": verification_check.status})
            else:
                return Response({"status": status.HTTP_400_BAD_REQUEST, "data": verification_check.status})
        except Exception as twillioException:
            print(twillioException)
            return Response({"status": status.HTTP_404_NOT_FOUND, "data": "something went wrong"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


def create_twilio_services():
    service = client.verify.v2.services.create(
        friendly_name='Ubnews Verify Service'
    )
    TwilioService.objects.create(service_id=service.sid)
    return service.sid
