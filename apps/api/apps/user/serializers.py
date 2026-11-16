from django.contrib.auth import get_user_model, authenticate
from django.contrib.auth.tokens import default_token_generator
from django.utils.translation import gettext_lazy as _
from rest_framework import serializers
from rest_framework.exceptions import ParseError
from rolepermissions.roles import get_user_roles
from rolepermissions.checkers import has_role
from .models import Device, Invitation


class UserSerializer(serializers.ModelSerializer):
    is_admin = serializers.SerializerMethodField(read_only=True)
    role = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = get_user_model()
        fields = ('id', 'email', 'password', 'is_admin', 'contact', 'deleted',
                  'firstname', "lastname", "role", "status", "avatar", "username")
        extra_kwargs = {
            'password': {'write_only': True}
        }

    def get_is_admin(self, obj):
        return obj.is_staff

    def validate_email(self, value):
        norm_email = value.lower()
        if get_user_model().objects.filter(email=norm_email).exists():
            raise serializers.ValidationError(
                "user with this email address already exists.")
        return norm_email

    def get_role(self, obj):
        roles = [role.__name__.lower() for role in get_user_roles(obj)]
        if roles:
            return roles[0].capitalize()
        elif has_role(obj, "administrator"):
            return "Administrator"
        else:
            return "Subscriber"

    def create(self, validated_data):
        user = get_user_model().objects.create_user(**validated_data)
        return user

    def update(self, obj, validated_data):
        password = validated_data.pop('password', None)
        if password:
            obj.set_password(password)
        return super().update(obj, validated_data)


class CustomAuthTokenSerializer(serializers.Serializer):
    '''
    Modified from rest_framework.authtoken.serializers.AuthTokenSerializer
    to accept email field instead of username
    '''
    email = serializers.CharField(label=_("Email"))
    password = serializers.CharField(
        label=_("Password"),
        style={'input_type': 'password'},
        trim_whitespace=False
    )

    def validate(self, attrs):
        email = attrs.get('email')
        password = attrs.get('password')

        if email and password:
            user = authenticate(
                request=self.context.get('request'),
                username=email.lower(),
                password=password
            )

            # The authenticate call simply returns None for is_active=False
            # users. (Assuming the default ModelBackend authentication
            # backend.)
            if not user:
                msg = _('Unable to log in with provided credentials.')
                raise serializers.ValidationError(msg, code='authorization')
        else:
            msg = _('Must include "email" and "password".')
            raise serializers.ValidationError(msg, code='authorization')

        attrs['user'] = user
        # mail.send_welcome_email(user)
        return attrs


class ForgotPasswordSerializer(serializers.Serializer):
    email = serializers.EmailField(write_only=True)

    def create(self, validated_data):
        email = validated_data['email'].lower()
        try:
            get_user_model().objects.get(email=email)
        except get_user_model().DoesNotExist:
            return {}

        # mail.send_forgot_password_email(user, reset_token=reset_token)

        return {}


class ResetPasswordSerializer(serializers.Serializer):
    token = serializers.CharField(write_only=True)
    user_id = serializers.IntegerField(write_only=True)
    password = serializers.CharField(write_only=True)

    def create(self, validated_data):
        token = validated_data['token']
        user_id = validated_data['user_id']
        password = validated_data['password']

        user = get_user_model().objects.get(id=user_id)
        if not default_token_generator.check_token(user, token):
            raise ParseError(detail='Invalid token')

        user.set_password(password)
        user.save()
        return {}


class DeviceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Device
        fields = "__all__"


class InvitationSerializer(serializers.ModelSerializer):
    inviter_name = serializers.SerializerMethodField(read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model = Invitation
        fields = ('id', 'inviter', 'inviter_name', 'invitee_email', 'token', 'status',
                  'status_display', 'role', 'message', 'created_at', 'expires_at')
        read_only_fields = ('id', 'token', 'created_at', 'expires_at')

    def get_inviter_name(self, obj):
        return f"{obj.inviter.firstname} {obj.inviter.lastname}".strip() or obj.inviter.email


class SendInvitationSerializer(serializers.Serializer):
    email = serializers.EmailField()
    role = serializers.CharField(max_length=50, default='contributor')
    message = serializers.CharField(required=False, allow_blank=True)

    def validate_email(self, value):
        email = value.lower()
        # Check if user already exists
        if get_user_model().objects.filter(email=email).exists():
            raise serializers.ValidationError("A user with this email already exists.")
        return email

    def validate_role(self, value):
        # Convert to lowercase for consistency
        role = value.lower()
        # You can add validation for valid roles here if needed
        return role


class AcceptInvitationSerializer(serializers.Serializer):
    token = serializers.CharField()
    firstname = serializers.CharField(max_length=200)
    lastname = serializers.CharField(max_length=200)
    password = serializers.CharField(min_length=8)

    def validate_token(self, value):
        try:
            invitation = Invitation.objects.get(token=value)
            if not invitation.is_valid():
                if invitation.is_expired():
                    raise serializers.ValidationError("This invitation has expired.")
                else:
                    raise serializers.ValidationError("This invitation is no longer valid.")
        except Invitation.DoesNotExist:
            raise serializers.ValidationError("Invalid invitation token.")
        return value
