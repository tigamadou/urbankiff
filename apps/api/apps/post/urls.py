from django.urls import path
from . import views

urlpatterns = [
    path('', views.PostListCreateAPIView.as_view()),
    path('<int:id>', views.PostDetailsAPIView.as_view()),
    path('getlastpost', views.FetchLastPost.as_view()),
    path('fetchpostdata', views.FetchPostData.as_view()),
    path('getcategorylastpost/<str:name>',
         views.FetchCategoryLastPost.as_view()),
    path('fetchcategorypostdata', views.FetchCategoryPostData.as_view()),
    path('record-view/<int:post_id>', views.RecordPostView.as_view(), name='record-post-view'),
    path('fetchpostdata/<str:slug>', views.FetchSlugPost.as_view()),
    path('fetchmostview/<str:lang>/<str:post_title>', views.MostViewedPostsView.as_view()),
    path('search', views.SearchPost.as_view()),
    path('report', views.ReportListCreateAPIView.as_view()),
    path('tags', views.TagView.as_view()),
    path('tags/<str:tag_name>', views.PostsByTagView.as_view(), name='posts-by-tag'),
]
