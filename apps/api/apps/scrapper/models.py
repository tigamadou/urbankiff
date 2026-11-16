from django.db import models

# Create your models here.


class Scrapper(models.Model):

    title = models.CharField(max_length=1000, unique=True)
    date = models.DateField()
    intro = models.CharField(max_length=5000, blank=True, null=True)
    content = models.TextField()
    image = models.CharField(max_length=1000)
    website = models.CharField(max_length=100)
    link = models.CharField(max_length=500)
    language = models.CharField(max_length=50)

    class Meta:
        verbose_name = "scrapper"
        verbose_name_plural = "scrappers"

    def __str__(self):
        return self.title
