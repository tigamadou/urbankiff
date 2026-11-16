from django.db import models

# Create your models here.


class Error(models.Model):
    message = models.JSONField(null=True)
    datetime = models.DateTimeField(auto_now_add=True)
    ip = models.CharField(max_length=100)
    platform = models.CharField(max_length=500)
    browser = models.CharField(max_length=100)

    class Meta:
        verbose_name = "error"
        verbose_name_plural = "errors"

    def __str__(self):
        return "{}".format(self.message)
