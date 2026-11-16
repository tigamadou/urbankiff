from django.urls import path
from . import views

urlpatterns = [
    path('', views.LikeCreateView.as_view(), name='like-create'),
    path('post/<int:post_id>/likes',
         views.PostLikesListView.as_view(), name='post-likes-list'),
    path('user/<int:user_id>/likes',
         views.UserLikesListView.as_view(), name='user-likes-list'),
    path('user/checklike/<int:post_id>',
         views.UserLikeCheckView.as_view(), name='user-likes-check'),



]
