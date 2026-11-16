from django.urls import path
from . import views

urlpatterns = [
    path('', views.PageListCreateAPIView.as_view()),
    path('<int:id>', views.PageDetailsAPIView.as_view()),
    path('<str:title>/<str:lang>', views.GetPageByTitleView.as_view()),
    path('incrementviews', views.IncrementViewPage.as_view()),
]
