from django.db import models
from django.template.defaultfilters import slugify
from apps.category.models import Category
from apps.user.models import User


class Tag(models.Model):
    name = models.CharField(max_length=50, unique=True)
    slug = models.SlugField(max_length=50, null=True, blank=True)

    def save(self, *args, **kwargs):
        self.slug = slugify(self.name)
        return super().save(*args, **kwargs)

    def __str__(self):
        return self.name


class Post(models.Model):

    title = models.CharField(max_length=1000)
    slug = models.SlugField(max_length=1000, null=True, blank=True)
    intro = models.CharField(max_length=10000)
    content = models.TextField()
    url = models.CharField(max_length=1000)
    image = models.CharField(max_length=5000)
    audio = models.CharField(max_length=5000, null=True, blank=True)
    video = models.CharField(max_length=5000, null=True, blank=True)
    tags = models.ManyToManyField(Tag, related_name="posts", blank=True)

    published = models.BooleanField(default=False)
    deleted = models.BooleanField(default=False)
    status = models.CharField(max_length=10, default="save")
    language = models.CharField(max_length=50, default="en")

    created_at = models.DateTimeField(auto_now_add=True, auto_now=False)
    updated_at = models.DateTimeField(auto_now_add=False, auto_now=True)

    author = models.ForeignKey(User, on_delete=models.CASCADE)
    category = models.ForeignKey(Category, on_delete=models.CASCADE)

    def save(self, *args, **kwargs):
        # Generate slug every time the title is updated
        # base_slug = slugify(self.title)
        # slug = base_slug
        # counter = 1
        # while Post.objects.filter(slug=slug).exclude(id=self.id).exists():
        #     slug = f"{base_slug}-{counter}"
        #     counter += 1
        # self.slug = slug
        super().save(*args, **kwargs)

    class Meta:
        verbose_name = "Post"
        verbose_name_plural = "Posts"

    def __str__(self):
        return self.title


class PostView(models.Model):
    post = models.ForeignKey('Post', on_delete=models.CASCADE, related_name='views')
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.CharField(max_length=255, null=True)
    viewed_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"View on {self.post.title} at {self.viewed_at}"
