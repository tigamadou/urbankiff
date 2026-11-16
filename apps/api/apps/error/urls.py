from django.urls import path
from . import views

urlpatterns = [
    path('', views.ErrorListCreateAPIView.as_view()),
]
