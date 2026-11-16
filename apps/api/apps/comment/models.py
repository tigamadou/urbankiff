from django.db import models
from apps.user.models import User
from apps.post.models import Post


# Create your models here.

class SubComment(models.Model):
    created_date = models.DateTimeField(auto_now_add=True)
    updated_date = models.DateTimeField(auto_now=True)
    content = models.TextField()
    deleted = models.BooleanField(default=False)
    blocked = models.BooleanField(default=False)
    user = models.ForeignKey(
        User, blank=True, null=True, on_delete=models.CASCADE)

    def __str__(self):
        return str(self.id)

    class Meta:
        verbose_name = "subcomment"
        verbose_name_plural = "subcomments"


class Comment(models.Model):
    created_date = models.DateTimeField(auto_now_add=True)
    updated_date = models.DateTimeField(auto_now=True)
    content = models.TextField()
    deleted = models.BooleanField(default=False)
    blocked = models.BooleanField(default=False)
    sub_comments = models.ManyToManyField(
        SubComment, related_name='parent_comment')

    def __str__(self):
        return str(self.id)

    class Meta:
        verbose_name = "comment"
        verbose_name_plural = "comments"


class Comment_Users(models.Model):
    comment = models.ForeignKey(Comment, on_delete=models.CASCADE)
    user = models.ForeignKey(User, on_delete=models.CASCADE)


class Comment_Posts(models.Model):
    comment = models.ForeignKey(Comment, on_delete=models.CASCADE)
    post = models.ForeignKey(Post, on_delete=models.CASCADE)


class Report(models.Model):
    reason = models.CharField(max_length=500)
    date = models.DateTimeField(auto_now_add=True, auto_now=False)
    post = models.ForeignKey(
        Post, on_delete=models.CASCADE, blank=True, null=True)
    comment = models.ForeignKey(
        Comment, on_delete=models.CASCADE, blank=True, null=True)
    reporter = models.ForeignKey(
        User, on_delete=models.CASCADE, null=True, blank=True)
    ip = models.CharField(max_length=100)
    browser = models.CharField(max_length=100)
