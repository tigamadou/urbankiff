from django.conf import settings
from django.contrib import admin
from django.urls import path, include
from rest_framework import permissions
from drf_yasg.views import get_schema_view
from drf_yasg import openapi
from apps.post.views import PostFetchListAPIView

from .views import api_root, health

admin.site.site_title = settings.ADMIN_TITLE
admin.site.site_header = settings.ADMIN_HEADER
schema_view = get_schema_view(
    openapi.Info(
        title="Snippets API",
        default_version='v1',
        description="Test description",
        terms_of_service="https://www.google.com/policies/terms/",
        contact=openapi.Contact(email="contact@snippets.local"),
        license=openapi.License(name="BSD License"),
    ),
    public=True,
    permission_classes=(permissions.AllowAny,),
)

urlpatterns = [
    # Admin
    path('admin/', admin.site.urls),

    # Apps
    path('api/health/', health, name='health'),
    path('', include('apps.file.urls')),
    path('', include('apps.user.urls')),
    path('category/', include('apps.category.urls')),
    path('comments/', include('apps.comment.urls')),
    path('page/', include('apps.page.urls')),
    path('scrapper/', include('apps.scrapper.urls')),
    path('post/', include('apps.post.urls')),
    path('posts', PostFetchListAPIView.as_view(), name="post-list-filtered"),
    path('error/', include('apps.error.urls')),
    path('twilio/', include('apps.twilio.urls')),
    path('likes/', include('apps.like.urls')),
    path('ads/', include('apps.banner.urls')),
    # Social login
    path('auth/', include('drf_social_oauth2.urls', namespace='drf')),
]
if settings.DEBUG:
    urlpatterns += [
        # DRF API
        path('api/', api_root, name='index'),
        path('api-auth/', include('rest_framework.urls')),
        path('swagger<format>/', schema_view.without_ui(cache_timeout=0),
             name='schema-json'),
        path('', schema_view.with_ui('swagger', cache_timeout=0), name='schema-swagger-ui'),
        path('redoc/', schema_view.with_ui('redoc',
                                           cache_timeout=0), name='schema-redoc'),
    ]
