from rest_framework import generics, permissions
from .models import Campaign
from .serializers import CampaignSerializer


class CampaignListCreateView(generics.ListCreateAPIView):
    queryset = Campaign.objects.prefetch_related('medias').all()
    serializer_class = CampaignSerializer

    def get_permissions(self):
        if self.request.method == 'GET':
            # Apply permissions for GET requests
            return [permissions.AllowAny()]
        elif self.request.method == 'POST':
            # Apply permissions for POST requests
            return [permissions.IsAuthenticated()]
        return super().get_permissions()


class CampaignRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Campaign.objects.prefetch_related('medias').all()
    serializer_class = CampaignSerializer
