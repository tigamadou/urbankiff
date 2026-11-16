from django.urls import path, re_path

from . import views


urlpatterns = [
    path('create-signed-file', views.CreateSignedFile.as_view(), name='create-signed-file'),
    path('files', views.UploadFile.as_view(), name='upload-file'),
    path('files/<int:pk>', views.FileDetail.as_view(), name='file-detail'),
    path('files/list', views.ListFilesView.as_view(), name='list_files'),
    path('files/upload', views.FileUploadView.as_view(), name='file-upload'),
    path('files/upload/<str:prefix>', views.UploadFileView.as_view(), name='upload_file_prefix'),
    path('file/<str:file_name>', views.FileServeView.as_view(), name='file-serve'),
    re_path(r'^file/rename/(?P<prefix>.+)/(?P<old_file_name>.+)/(?P<new_file_name>.+)/$', views.RenameFileView.as_view(), name='rename_file'),
    re_path(r'^file/delete/(?P<file_name>.+)/$', views.DeleteFileView.as_view(), name='delete_file'),
    re_path(r'^files/(?P<file_name>.+)/$', views.FileRetrieveSignedUrlView.as_view(), name='file-signed-url'),
]
