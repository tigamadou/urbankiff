from django.urls import path
from . import views

urlpatterns = [
    path('<int:post_id>', views.CommentListCreateView.as_view(),
         name='comment-list-create'),
    path('subcomment/<int:comment_id>',
         views.SubCommentListCreateView.as_view(), name='subcomment-create'),
    path('<int:id>/detail', views.CommentDetailView.as_view(), name='comment-detail'),
    path('post/<int:post_id>', views.CommentsByPostView.as_view(),
         name='comments-by-post'),
    path('user/<int:user_id>', views.CommentsByUserView.as_view(),
         name='comments-by-user'),
    path('block/<int:id>', views.BlockCommentView.as_view(), name='block-comment'),
    path('subcomments/<int:comment_id>',
         views.SubCommentsByCommentView.as_view(), name='subcomments-by-comment'),
]
