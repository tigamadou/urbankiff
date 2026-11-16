from django.db import models
from django.template.defaultfilters import slugify

# Create your models here.


class Page(models.Model):

    title = models.CharField(max_length=1000)
    language = models.CharField(max_length=1000)
    slug = models.SlugField(max_length=1000, null=True, blank=True)
    content = models.TextField()

    published = models.BooleanField(default=False)
    deleted = models.BooleanField(default=False)
    views = models.IntegerField(null=True, blank=True, default=0)

    created_at = models.DateTimeField(auto_now_add=True, auto_now=False)
    updated_at = models.DateTimeField(auto_now_add=False, auto_now=True)

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(self.title)
        return super().save(*args, **kwargs)

    class Meta:
        verbose_name = "Page"
        verbose_name_plural = "Pages"

    def __str__(self):
        return self.title
