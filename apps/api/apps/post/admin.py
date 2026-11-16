from django.contrib import admin
from .models import Post, Tag
from apps.comment.models import Report

# Register your models here.
admin.site.register(Tag)


@admin.register(Post)
class PostAdmin(admin.ModelAdmin):
    list_display = ("title", "category")


@admin.register(Report)
class ReportAdmin(admin.ModelAdmin):
    list_display = ["reason", "ip", "browser", 'date', "reporter", "post"]
