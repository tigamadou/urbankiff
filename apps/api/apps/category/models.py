from django.db import models
from django.template.defaultfilters import slugify
from django.urls import reverse

# Create your models here.


class Category(models.Model):
    name = models.CharField(max_length=50)
    color = models.CharField(max_length=50)
    slug = models.SlugField(max_length=50, null=True, blank=True)
    language = models.CharField(max_length=50, default="en")

    def save(self, *args, **kwargs):
        self.slug = slugify(self.name)
        return super().save(*args, **kwargs)

    def get_absolute_url(self):
        return reverse('blog_detail', kwargs={'slug': self.slug})

    class Meta:
        verbose_name = "category"
        verbose_name_plural = "categorys"

    def __str__(self):
        return self.name
