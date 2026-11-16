import math
import random
from push_notifications.models import GCMDevice


def generateOTP():

    # Declare a string variable
    # which stores all string
    string = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    OTP = ""
    length = len(string)
    for i in range(6):
        OTP += string[math.floor(random.random() * length)]

    return OTP


def notification_sender(gcm_reg_id):

    device = GCMDevice.objects.get(registration_id=gcm_reg_id)

    # The first argument will be sent as "message" to the intent extras Bundle
    # Retrieve it with intent.getExtras().getString("message")

    device.send_message("You've got mail")

    # If you want to customize, send an extra dict and a None message.
    # the extras dict will be mapped into the intent extras Bundle.
    # For dicts where all values are keys this will be sent as url parameters,
    # but for more complex nested collections the extras dict will be sent via
    # the bulk message api.

    device.send_message(message={
                        "title": "Game Request", "body": "Bob wants to play poker"}, extra={"foo": "bar"})
