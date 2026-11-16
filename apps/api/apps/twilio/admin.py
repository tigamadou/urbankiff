from django.contrib import admin
from .models import TwilioService
# Register your models here.


@admin.register(TwilioService)
class TwilioServiceAdmin(admin.ModelAdmin):
    list_display = ("service_id", "created_at")
