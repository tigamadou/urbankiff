from django.db import models
from apps.user.models import User
from apps.post.models import Post


# Create your models here.
class Like(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    post = models.ForeignKey(Post, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return str(self.id)

    class Meta:
        verbose_name = "like"
        verbose_name_plural = "likes"
        unique_together = ('user', 'post')
