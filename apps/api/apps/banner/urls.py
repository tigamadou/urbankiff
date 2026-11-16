from django.urls import path
from .views import CampaignListCreateView, CampaignRetrieveUpdateDestroyView

urlpatterns = [
    path('', CampaignListCreateView.as_view(), name='campaign-list-create'),
    path('<int:pk>', CampaignRetrieveUpdateDestroyView.as_view(), name='campaign-detail'),
]
