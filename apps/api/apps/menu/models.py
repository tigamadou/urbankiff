from django.db import models

# Create your models here.


class Menu(models.Model):

    name = models.CharField(max_length=50)
    target = models.BooleanField(default=False)
    activated = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True, auto_now=False)
    updated_at = models.DateTimeField(auto_now=True)
    url = models.CharField(max_length=100)

    class Meta:
        verbose_name = "Menu"
        verbose_name_plural = "Menus"

    def __str__(self):
        return self.name
