from django.urls import path
from . import views

urlpatterns = [
    path('', views.ScrapperListCreateAPIView.as_view()),
    path('<int:id>', views.ScrapperDetailAPIView.as_view()),
]
