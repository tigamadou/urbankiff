from django.urls import path
from . import views

urlpatterns = [
    path('', views.CategoryListCreateAPIView.as_view()),
    path('<int:id>', views.CategoryDetailsAPIView.as_view()),
    path('<str:slug>', views.GetCategoryNameAPIView.as_view()),
]
