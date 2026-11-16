from django.urls import path
from . import views
urlpatterns = [
    path('sendcode', views.SendVerifyCode.as_view()),
    path('verify', views.VerifyTwilioOTP.as_view())
]
