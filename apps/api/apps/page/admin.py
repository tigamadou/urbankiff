from django.contrib import admin
from .models import Page

# Register your models here.
# admin.site.register(Page)


@admin.register(Page)
class PageAdmin(admin.ModelAdmin):
    list_display = ("title", "language")
