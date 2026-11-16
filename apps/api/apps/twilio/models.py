from django.db import models

# Create your models here.


class TwilioService(models.Model):

    service_id = models.CharField(max_length=500)
    created_at = models.DateTimeField(auto_now_add=True, auto_now=False)

    class Meta:
        verbose_name = "TwilioService"
        verbose_name_plural = "TwilioServices"

    def __str__(self):
        return self.service_id
