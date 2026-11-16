import logging.config
import os
import sys
import django_heroku
import datetime


# ==================================================================================================
# ENVIRONMENT SETTINGS
# ==================================================================================================


DEV = 'dev'
STAGING = 'staging'
PRODUCTION = 'production'
TEST = 'test'
ENV = os.environ.get('DJANGO_ENV', DEV)
TESTING = 'test' in sys.argv or ENV == TEST

# Admin Banner
if ENV == DEV:
    ENVIRONMENT_NAME = "Development Environment"
    ENVIRONMENT_COLOR = "#828282"
elif ENV == STAGING:
    ENVIRONMENT_NAME = "Staging Staging Environment"
    ENVIRONMENT_COLOR = "#FF2222"
else:
    ENVIRONMENT_NAME = None
    ENVIRONMENT_COLOR = None

# ==================================================================================================
# DJANGO SETTINGS
# ==================================================================================================


BASE_DIR = os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))).replace('/project', '')
SECRET_KEY = os.environ.get('SECRET_KEY', 'local')
DEBUG = False if ENV == PRODUCTION else True
ALLOWED_HOSTS = os.environ.get('ALLOWED_HOSTS', '*').split(',')

AUTH_USER_MODEL = 'user.User'

INSTALLED_APPS = [
    # Custom Admin settings (must be before django.contrib.admin)
    'django_admin_env_notice',
    'admin_interface',
    'colorfield',

    # Django core
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.messages',
    'django.contrib.sessions',
    'django.contrib.staticfiles',

    # 3rd party
    'django_extensions',
    'django_filters',
    'rest_framework',
    'rest_framework.authtoken',
    'rest_framework_tracking',
    'drf_yasg',
    'rolepermissions',
    "push_notifications",

    # Social login setup
    'oauth2_provider',
    'social_django',
    'drf_social_oauth2',

    # Local
    'apps.file',
    'apps.mail',
    'apps.user',
    'apps.workers',
    'apps.category',
    'apps.menu',
    'apps.post',
    'apps.page',
    'apps.error',
    'apps.comment',
    'apps.twilio',
    'apps.like',
    'apps.scrapper',
    'apps.banner'
]

MIDDLEWARE = [
    'libs.corsmiddleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    "project.language_middleware.LanguageMiddleware",
    'django.middleware.csrf.CsrfViewMiddleware',
]
# Email Backend
EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'

ROOT_URLCONF = 'project.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [os.path.join(BASE_DIR, 'templates')],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
                'django_admin_env_notice.context_processors.from_settings',
                'social_django.context_processors.backends',
                'social_django.context_processors.login_redirect',
            ],
        },
    },
]

WSGI_APPLICATION = 'project.wsgi.application'

DEFAULT_AUTO_FIELD = 'django.db.models.AutoField'

TEST_RUNNER = 'project.test_runner.AgentLotTestRunner'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('POSTGRES_DB'),
        'USER': os.environ.get('POSTGRES_USER'),
        'PASSWORD': os.environ.get('POSTGRES_PASSWORD'),
        'HOST': os.environ.get('POSTGRES_HOST'),
    },
}

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

LANGUAGE_CODE = 'fr'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_L10N = True
USE_TZ = True

MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

STATIC_URL = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')

LOGGING_CONFIG = None
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'root': {
        'level': 'WARNING',
        'handlers': ['console', 'sentry'],
    },
    'formatters': {
        'custom': {
            'format': '%(levelname)s %(message)s (in %(module)s.%(funcName)s:%(lineno)s by %(name)s)',
            'datefmt': '%Y-%m-%dT%H:%M:%S',
        },
    },
    'handlers': {
        'console': {
            'level': 'DEBUG',
            'class': 'logging.StreamHandler',
            'formatter': 'custom'
        },
        'sentry': {
            'level': 'WARNING',
            'class': 'raven.contrib.django.raven_compat.handlers.SentryHandler',
            'tags': {'custom-tag': 'x'},
        },
    },
    'loggers': {
        'apps': {'level': 'DEBUG'},
        'project': {'level': 'DEBUG'},
        'libs': {'level': 'DEBUG'},
        'django': {'level': 'INFO'},
        'gunicorn': {'level': 'WARNING'},
        'workers': {'level': 'DEBUG'}
    }
}
logging.config.dictConfig(LOGGING)


# ==================================================================================================
# 3RD PARTY SETTINGS
# ==================================================================================================


WORKERS_SLEEP = 2
WORKERS_PURGE = 1000
WORKERS_DELAY = 60 * 1

REST_FRAMEWORK = {
    'DEFAULT_RENDERER_CLASSES': (
        'djangorestframework_camel_case.render.CamelCaseJSONRenderer',
        'rest_framework.renderers.BrowsableAPIRenderer',
    ),
    'DEFAULT_PARSER_CLASSES': (
        'djangorestframework_camel_case.parser.CamelCaseJSONParser',
        "rest_framework.parsers.MultiPartParser",
        "rest_framework.parsers.FormParser"

    ),
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework.authentication.TokenAuthentication',
        # # SessionAuthentication may interfere with mobile API requests.
        # # If you are experiencing ssues, try commenting out the following line.
        'rest_framework.authentication.SessionAuthentication',
        'oauth2_provider.contrib.rest_framework.OAuth2Authentication',  # django-oauth-toolkit >= 1.0.0
        'drf_social_oauth2.authentication.SocialAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
    # 'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.LimitOffsetPagination',
    # 'PAGE_SIZE': 25,
    'DEFAULT_FILTER_BACKENDS': (
        'django_filters.rest_framework.DjangoFilterBackend',
        'rest_framework.filters.OrderingFilter',
        'rest_framework.filters.SearchFilter',
    ),
    'EXCEPTION_HANDLER': 'libs.exception_handler.exception_handler'
}
if not DEBUG:
    REST_FRAMEWORK['DEFAULT_RENDERER_CLASSES'] = (
        'djangorestframework_camel_case.render.CamelCaseJSONRenderer',
    )

APP_NAME = 'Urbankiff'
ADMIN_TITLE = 'Admin'
ADMIN_HEADER = 'Admin'
TOKEN_EXPIRY_TIME = datetime.timedelta(days=5)

WEB_URL = os.environ.get('WEB_URL', 'http://localhost:3000')
RESET_PASSWORD_URL = '{}{}'.format(
    WEB_URL, '/reset-password/{reset_token}/{user_id}')

# ==================================================================================================
# FILE SETTINGS
# ==================================================================================================


AWS_ACCESS_KEY_ID = None
AWS_SECRET_ACCESS_KEY = None
AWS_STORAGE_BUCKET_NAME = None
AWS_LOCATION = ''

# Enable file resize task by uncommenting the task decorator for apps.file.tasks.resize_images()
# How often to check for images to resizes (in seconds)
FILE_IMAGE_RESIZE_SCHEDULE = 60
FILE_IMAGE_SIZES = (
    {'key': 'th', 'width': 350, 'quality': 90},
    {'key': 'md', 'width': 800},
)


# ==================================================================================================
# EMAIL SETTINGS
# ==================================================================================================


DEFAULT_FROM_EMAIL = 'noreply@urbankiff.com'
DEFAULT_FROM_NAME = 'Urbankiff'

# Email configuration - MailHog for development, SMTP for production
if ENV == DEV:
    # MailHog configuration for development - reads from env file
    EMAIL_HOST = os.environ.get('SMTP_SERVER', 'mailhog')
    EMAIL_PORT = int(os.environ.get('SMTP_PORT', 1025))
    EMAIL_HOST_USER = os.environ.get('SMTP_USERNAME', "")
    EMAIL_HOST_PASSWORD = os.environ.get('SMTP_PASSWORD', "")
    EMAIL_USE_TLS = False
    EMAIL_USE_SSL = False
    SEND_MAIL = True
else:
    # Production SMTP configuration
    EMAIL_HOST = os.environ.get('SMTP_SERVER', 'smtp.postmarkapp.com')
    EMAIL_PORT = os.environ.get('SMTP_PORT', 587)
    EMAIL_HOST_USER = os.environ.get('SMTP_USERNAME', None)
    EMAIL_HOST_PASSWORD = os.environ.get('SMTP_PASSWORD', None)
    EMAIL_USE_TLS = False
    EMAIL_USE_SSL = True
    SEND_MAIL = True if EMAIL_HOST_USER and EMAIL_HOST_PASSWORD else False


# ==================================================================================================
# HEROKU & GITHUB
# ==================================================================================================

if ENV in [STAGING, PRODUCTION]:
    django_heroku.settings(locals(), staticfiles=False)

if TESTING:
    try:
        del DATABASES['default']['OPTIONS']['sslmode']
    except KeyError:
        pass


# ==================================================================================================
# FAKER Settings
# ==================================================================================================
FAKER_LOCALE = None
FAKER_PROVIDERS = None


ROLEPERMISSIONS_MODULE = 'project.roles'
# ==================================================================================================
# Push notifications Settings
# ==================================================================================================
PUSH_NOTIFICATIONS_SETTINGS = {
    "FCM_API_KEY": os.environ.get("FCM_API_KEY", ""),
    "GCM_API_KEY": os.environ.get("FCM_API_KEY", ""),
    # "APNS_CERTIFICATE": "/path/to/your/certificate.pem",
}
# ==================================================================================================
# Social login Settings
# ==================================================================================================

AUTHENTICATION_BACKENDS = (
    # Google  OAuth2
    'social_core.backends.google.GoogleOAuth2',

    # Normal Auth
    'drf_social_oauth2.backends.DjangoOAuth2',
    'django.contrib.auth.backends.ModelBackend',
)
# Google configuration
SOCIAL_AUTH_GOOGLE_OAUTH2_KEY = os.environ.get('SOCIAL_AUTH_GOOGLE_OAUTH2_KEY', '')
SOCIAL_AUTH_GOOGLE_OAUTH2_SECRET = os.environ.get('SOCIAL_AUTH_GOOGLE_OAUTH2_SECRET', '')
SOCIAL_AUTH_GOOGLE_OAUTH2_SCOPE = [
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/userinfo.profile',
]


# ===================================================================================================
#  Minio Configuration
# ===================================================================================================

MINIO_STORAGE_ENDPOINT = os.environ.get('MINIO_ENDPOINT')  # Replace with your MinIO server address
MINIO_STORAGE_ACCESS_KEY = os.environ.get('MINIO_ROOT_USER')   # Replace with your MinIO access key
MINIO_STORAGE_SECRET_KEY = os.environ.get('MINIO_ROOT_PASSWORD')   # Replace with your MinIO secret key
# MINIO_STORAGE_USE_HTTPS =  True if ENV == PRODUCTION else False  # Set to True if using HTTPS
MINIO_STORAGE_USE_HTTPS = False
MINIO_STORAGE_BUCKET_NAME = os.environ.get('MINIO_DEFAULT_BUCKETS')

# CDN endpoint for serving files (can be different from MinIO endpoint)
FILES_CDN_ENDPOINT = os.environ.get('FILES_CDN_ENDPOINT')

CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': os.environ.get('REDIS_ENDPOINT'),
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
        },
        'KEY_PREFIX': 'drf_cache'
    }
}
