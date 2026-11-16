from django.db import models
import uuid


class Campaign(models.Model):
    id = models.AutoField(primary_key=True)
    uuid = models.CharField(max_length=255, unique=True)

    def __str__(self):
        return self.uuid


class Media(models.Model):
    MEDIA_TYPES = [
        ('picture', 'Picture'),
        ('video', 'Video'),
    ]
    DEVICE_TYPES = [
        ('desktop', 'Desktop'),
        ('mobile', 'Mobile'),
        ('tablet', 'Tablet'),
    ]

    uuid = models.UUIDField(default=uuid.uuid4, editable=False, unique=True)
    campaign = models.ForeignKey(Campaign, related_name="medias", on_delete=models.CASCADE)
    type = models.CharField(max_length=20, choices=MEDIA_TYPES)
    file = models.URLField()
    device = models.CharField(max_length=20, choices=DEVICE_TYPES)
    url = models.URLField(blank=True, null=True)

    def __str__(self):
        return self.uuid
