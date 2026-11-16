from .base import AbstractEmailUser
from django.db import models
from django.utils import timezone
from datetime import timedelta
import uuid


class Device(models.Model):
    created_at = models.DateTimeField(auto_now_add=True, auto_now=False)
    registration_id = models.CharField(max_length=1000)


class User(AbstractEmailUser):
    bio = models.TextField(null=True, blank=True)
    id_img = models.CharField(max_length=1000, blank=True, null=True)
    nationality = models.CharField(max_length=100, blank=True, null=True)
    residence_country = models.CharField(
        max_length=100, blank=True, null=True)
    address = models.CharField(max_length=1000, blank=True, null=True)
    birthday = models.DateField(blank=True, null=True)
    devices = models.ManyToManyField(Device, related_name="user")


class PasswordResetToken(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='password_reset_tokens')
    token = models.CharField(max_length=255, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    used = models.BooleanField(default=False)

    class Meta:
        ordering = ['-created_at']

    def save(self, *args, **kwargs):
        if not self.expires_at:
            # Set expiration to 1 hour from creation
            self.expires_at = timezone.now() + timedelta(hours=1)
        super().save(*args, **kwargs)

    def is_expired(self):
        """Check if the token has expired"""
        return timezone.now() > self.expires_at

    def is_valid(self):
        """Check if the token is valid (not expired and not used)"""
        return not self.is_expired() and not self.used

    def mark_as_used(self):
        """Mark the token as used"""
        self.used = True
        self.save()

    def __str__(self):
        return f"PasswordResetToken for {self.user.email} - {'Valid' if self.is_valid() else 'Invalid'}"


class Invitation(models.Model):
    PENDING = 'pending'
    ACCEPTED = 'accepted'
    EXPIRED = 'expired'
    REJECTED = 'rejected'

    STATUS_CHOICES = [
        (PENDING, 'Pending'),
        (ACCEPTED, 'Accepted'),
        (EXPIRED, 'Expired'),
        (REJECTED, 'Rejected'),
    ]

    inviter = models.ForeignKey(User, on_delete=models.CASCADE, related_name='sent_invitations')
    invitee_email = models.EmailField(max_length=255)
    token = models.CharField(max_length=255, unique=True, default=uuid.uuid4)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=PENDING)
    role = models.CharField(max_length=50, default='contributor')
    message = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()

    class Meta:
        ordering = ['-created_at']
        unique_together = ['inviter', 'invitee_email']

    def save(self, *args, **kwargs):
        if not self.expires_at:
            # Set expiration to 7 days from creation
            self.expires_at = timezone.now() + timedelta(days=7)
        super().save(*args, **kwargs)

    def is_expired(self):
        """Check if the invitation has expired"""
        return timezone.now() > self.expires_at

    def is_valid(self):
        """Check if the invitation is valid (not expired and pending)"""
        return not self.is_expired() and self.status == self.PENDING

    def mark_as_accepted(self):
        """Mark the invitation as accepted"""
        self.status = self.ACCEPTED
        self.save()

    def mark_as_rejected(self):
        """Mark the invitation as rejected"""
        self.status = self.REJECTED
        self.save()

    def mark_as_expired(self):
        """Mark the invitation as expired"""
        self.status = self.EXPIRED
        self.save()

    def __str__(self):
        return f"Invitation from {self.inviter.email} to {self.invitee_email} - {self.status}"
