from django.contrib.auth import get_user_model, authenticate
from django.db import IntegrityError
from rest_framework import generics, permissions, status
from rest_framework.authtoken.models import Token
from rest_framework.authtoken.views import ObtainAuthToken
from rest_framework.response import Response
from rest_framework.parsers import JSONParser
from rest_framework.views import APIView
from django.contrib.auth.tokens import default_token_generator
from django.utils import timezone
import pytz
import datetime
from django.conf import settings
from .authentication import ExpiringTokenAuthentication

from rolepermissions.roles import assign_role, remove_role, get_user_roles
from rolepermissions.checkers import has_role, has_permission
from rolepermissions.permissions import grant_permission, revoke_permission, available_perm_status
from rolepermissions.exceptions import RoleDoesNotExist, RolePermissionScopeException
from .permissions import IsOwner
from project.utils import is_admin, is_admin_or_editor_or_contributor
from .models import User, PasswordResetToken, Invitation
from rolepermissions.roles import clear_roles
from apps.mail.models import Mail, OTP
from apps.mail.tasks import test_smtp_connection
from . import mail
from .utils import generateOTP, notification_sender
from push_notifications.models import GCMDevice

from .serializers import (
    UserSerializer,
    CustomAuthTokenSerializer,
    ForgotPasswordSerializer,
    ResetPasswordSerializer,
    DeviceSerializer,
    Device,
    InvitationSerializer,
    SendInvitationSerializer,
    AcceptInvitationSerializer
)
import requests


class Me(generics.RetrieveUpdateAPIView):
    queryset = get_user_model().objects.all()
    serializer_class = UserSerializer
    authentication_classes = (ExpiringTokenAuthentication, )

    def get_object(self):
        return self.request.user


class UserCreate(generics.CreateAPIView):
    serializer_class = UserSerializer
    permission_classes = (permissions.AllowAny,)

    def post(self, request, *args, **kwargs):

        response = super().post(request, *args, **kwargs)
        user_id = response.data['id']
        token = Token.objects.create(user_id=user_id)
        user = get_user_model().objects.get(id=user_id)
        assign_role(user, "contributor")
        return Response(
            {'token': token.key, 'userId': token.user_id},
            status=status.HTTP_201_CREATED,
        )


class UserList(generics.ListCreateAPIView):
    queryset = get_user_model().objects.all()
    serializer_class = UserSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request, *args, **kwargs):
        user = request.user
        if not is_admin(user):
            return Response(status=status.HTTP_403_FORBIDDEN)
        users = User.objects.all()
        user_serialized = UserSerializer(users, many=True)
        return Response(user_serialized.data)

    def post(self, request, *args, **kwargs):
        try:
            user = request.user
            if not is_admin(user):
                return Response(status=status.HTTP_403_FORBIDDEN)
            data = JSONParser().parse(request)
            email = data["email"]
            contact = data["contact"]
            firstname = data["firstname"]
            lastname = data["lastname"]
            user_status = data["status"]
            password = data["password"]
            username = data["username"]
            user = get_user_model().objects.create(email=email, contact=contact,
                                                   firstname=firstname, lastname=lastname, status=user_status, username=username)
            user.set_password(password)
            try:
                assign_role(user, data["role"].lower())
                user.save()
            except RoleDoesNotExist:
                return Response({"message": f"The role {data['role']} does not exist."}, status=status.HTTP_400_BAD_REQUEST)

            return Response({"status": status.HTTP_201_CREATED})
        except IntegrityError:
            return Response("This email is already in use !")


class UserDetails(generics.RetrieveUpdateDestroyAPIView):
    queryset = get_user_model().objects.all()
    serializer_class = UserSerializer
    permission_classes = (permissions.IsAuthenticated, IsOwner,)
    lookup_field = "id"

    def put(self, request, *args, **kwargs):
        user = request.user
        found_user = get_user_model().objects.filter(
            id=kwargs["id"]).first()
        if not is_admin(user) and found_user != user:
            return Response(status=status.HTTP_403_FORBIDDEN)
        data = JSONParser().parse(request)

        fields_to_update = ["email", "contact", "firstname", "lastname",
                            "role", "avatar", "password", "status", "username"]
        update_fields = {}
        if found_user.is_staff:
            del data["role"]
        for field in fields_to_update:
            if field in data and data[field] is not None:
                if field == "password":
                    user = get_user_model().objects.get(id=kwargs["id"])
                    user.set_password(data[field])
                    user.save()
                elif field == "role" and is_admin(user):
                    try:
                        clear_roles(found_user)
                        assign_role(found_user, data["role"].lower())
                    except RoleDoesNotExist:
                        return Response({"message": f"The role {data['role']} does not exist."}, status=status.HTTP_400_BAD_REQUEST)
                else:
                    update_fields[field] = data[field]

        user_updated = get_user_model().objects.filter(
            id=kwargs["id"]).update(**update_fields)

        if user_updated:
            return Response({"message": "User updated successfully"}, status=status.HTTP_200_OK)
        else:
            return Response({"message": "No user found with the given ID"}, status=status.HTTP_404_NOT_FOUND)

    def delete(self, request, *args, **kwargs):
        user = request.user
        if not is_admin(user):
            return Response(status=status.HTTP_403_FORBIDDEN)

        user_to_delete = get_user_model().objects.get(id=kwargs["id"])
        user_to_delete.deleted = True
        user_to_delete.is_active = False
        user_to_delete.save()
        return Response({"status": status.HTTP_200_OK})


class UserLogin(ObtainAuthToken):
    serializer_class = CustomAuthTokenSerializer

    def post(self, request, *args, **kwargs):
        response = super().post(request, *args, **kwargs)
        token = Token.objects.get(key=response.data['token'])
        utc_now = datetime.datetime.utcnow()
        utc_now = utc_now.replace(tzinfo=pytz.utc)
        user = get_user_model().objects.get(pk=token.user_id)
        roles = [role.__name__.lower() for role in get_user_roles(user)]
        userRole = roles[0] if len(roles) > 0 else "administrator"
        if not is_admin_or_editor_or_contributor(user):
            return Response(status=status.HTTP_401_UNAUTHORIZED)
        Token.objects.filter(
            user=user, created__lt=utc_now - settings.TOKEN_EXPIRY_TIME).delete()
        token, created = Token.objects.get_or_create(user=user)
        user_gcm_token = user.devices.first()
        if user_gcm_token is not None:
            notification_sender(user_gcm_token.registration_id)
        return Response({'token': token.key, 'userId': token.user_id, 'role': userRole})


class UserForgotPassword(APIView):
    serializer_class = ForgotPasswordSerializer
    permission_classes = (permissions.AllowAny,)

    def post(self, request, *args, **kwargs):
        validated_data = request.data
        email = validated_data['email'].lower()
        user = None

        try:
            # Find user by email only
            user = get_user_model().objects.get(email=email)
        except get_user_model().DoesNotExist:
            # User not found by email
            user = None

        # Always send the same response message for security reasons
        # This prevents email enumeration attacks
        if user is not None:
            # Clean up any existing tokens for this user
            PasswordResetToken.objects.filter(user=user).delete()

            # Create a new password reset token with 1-hour expiration
            reset_token = default_token_generator.make_token(user)

            # Create PasswordResetToken instance
            PasswordResetToken.objects.create(
                user=user,
                token=reset_token
            )

            # Detect language from request or default to French
            language = getattr(request, 'language', 'fr')
            # Send password reset email using localized HTML template file
            try:
                mail.send_forgot_password_email_template(user, reset_token, 'fr')
            except Exception as e:
                print(f"Error sending password reset email: {e}")
                # Continue execution even if email fails

        # Return localized response message regardless of whether user exists
        language = getattr(request, 'language', 'fr')
        if language == 'fr':
            message = "Si un compte avec cet e-mail existe, vous recevrez un lien de réinitialisation de mot de passe sous peu."
        else:
            message = "If an account with this email exists, you will receive a password reset link shortly."

        return Response({
            "message": message,
            "status": status.HTTP_200_OK
        })


class UserChangePassword(generics.CreateAPIView):
    serializer_class = ResetPasswordSerializer
    permission_classes = (permissions.IsAuthenticated, IsOwner,)

    def post(self, request, *args, **kwargs):
        validated_data = JSONParser().parse(request)
        user_id = validated_data['user_id']
        password = validated_data['password']
        current_password = validated_data['current_password']
        email = validated_data['email']
        verify_current_password = authenticate(
            request=request, username=email.lower(), password=current_password)
        if verify_current_password:
            user = get_user_model().objects.get(id=user_id)

            user.set_password(password)
            user.save()
            return Response({"status": status.HTTP_200_OK})
        else:
            return Response({"status": status.HTTP_400_BAD_REQUEST})


class UserResetPassword(generics.CreateAPIView):
    serializer_class = ResetPasswordSerializer
    permission_classes = (permissions.AllowAny,)

    def post(self, request, *args, **kwargs):
        validated_data = request.data
        user_id = validated_data['user_id']
        password = validated_data['password']
        token = validated_data['token']

        try:
            user = get_user_model().objects.get(id=user_id)
        except get_user_model().DoesNotExist:
            return Response({"message": "User not found"}, status=status.HTTP_404_NOT_FOUND)

        # Check if the token exists and is valid (not expired and not used)
        try:
            password_reset_token = PasswordResetToken.objects.get(
                user=user,
                token=token
            )

            if not password_reset_token.is_valid():
                if password_reset_token.is_expired():
                    return Response({"message": "Token has expired"}, status=status.HTTP_400_BAD_REQUEST)
                elif password_reset_token.used:
                    return Response({"message": "Token has already been used"}, status=status.HTTP_400_BAD_REQUEST)
                else:
                    return Response({"message": "Invalid Token"}, status=status.HTTP_400_BAD_REQUEST)

            # Also verify with Django's token generator for additional security
            if not default_token_generator.check_token(user, token):
                return Response({"message": "Invalid Token"}, status=status.HTTP_400_BAD_REQUEST)

            # Reset the password
            user.set_password(password)
            user.save()

            # Mark the token as used
            password_reset_token.mark_as_used()

            return Response({"message": "Password Reset successfully"}, status=status.HTTP_200_OK)

        except PasswordResetToken.DoesNotExist:
            return Response({"message": "Invalid Token"}, status=status.HTTP_400_BAD_REQUEST)


class ValidatePasswordResetToken(APIView):
    permission_classes = (permissions.AllowAny,)

    def post(self, request, *args, **kwargs):
        """
        Validate if a password reset token is still valid
        Expected payload: {"user_id": int, "token": string}
        """
        validated_data = request.data
        user_id = validated_data.get('user_id')
        token = validated_data.get('token')

        if not user_id or not token:
            return Response({
                "valid": False,
                "message": "user_id and token are required"
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            user = get_user_model().objects.get(id=user_id)
        except get_user_model().DoesNotExist:
            return Response({
                "valid": False,
                "message": "User not found"
            }, status=status.HTTP_404_NOT_FOUND)

        try:
            password_reset_token = PasswordResetToken.objects.get(
                user=user,
                token=token
            )

            if password_reset_token.is_valid():
                # Also verify with Django's token generator for additional security
                if default_token_generator.check_token(user, token):
                    return Response({
                        "valid": True,
                        "message": "Token is valid",
                        "expires_at": password_reset_token.expires_at.isoformat(),
                        "time_remaining": str(password_reset_token.expires_at - timezone.now())
                    }, status=status.HTTP_200_OK)
                else:
                    return Response({
                        "valid": False,
                        "message": "Invalid token"
                    }, status=status.HTTP_400_BAD_REQUEST)
            else:
                if password_reset_token.is_expired():
                    return Response({
                        "valid": False,
                        "message": "Token has expired",
                        "expired_at": password_reset_token.expires_at.isoformat()
                    }, status=status.HTTP_400_BAD_REQUEST)
                elif password_reset_token.used:
                    return Response({
                        "valid": False,
                        "message": "Token has already been used"
                    }, status=status.HTTP_400_BAD_REQUEST)
                else:
                    return Response({
                        "valid": False,
                        "message": "Token is invalid"
                    }, status=status.HTTP_400_BAD_REQUEST)

        except PasswordResetToken.DoesNotExist:
            return Response({
                "valid": False,
                "message": "Token not found"
            }, status=status.HTTP_404_NOT_FOUND)


class UserProfilePictureUpload(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = UserSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def put(self, request, *args, **kwargs):
        data = JSONParser().parse(request)
        user = get_user_model().objects.get(id=kwargs["id"])
        avatar = data['avatar']

        user.avatar = avatar
        user.save()
        return Response({"status": status.HTTP_200_OK})


class AddUserRole(generics.RetrieveUpdateAPIView):
    queryset = get_user_model().objects.all()
    serializer_class = UserSerializer
    permission_classes = (permissions.AllowAny,)
    lookup_field = "id"
    http_method_names = ['get', 'put']

    def get(self, request, *args, **kwargs):
        user = get_user_model().objects.get(id=kwargs["id"])
        roles = get_user_roles(user)
        roles_lower = [role.__name__.lower() for role in roles]

        return Response({"data": roles_lower}, status=status.HTTP_200_OK)

    def put(self, request, *args, **kwargs):
        try:
            data = JSONParser().parse(request)
            role_name = data.get('role_name')
            user = get_user_model().objects.get(id=kwargs["id"])

            if has_role(user, role_name):
                return Response({"message": f"This user already has the role {role_name}"}, status=status.HTTP_400_BAD_REQUEST)

            assign_role(user, role_name)

            return Response({"message": f"The role {role_name} was added successfully"}, status=status.HTTP_200_OK)
        except RoleDoesNotExist:
            return Response({"message": f"The role {role_name} does not exist."}, status=status.HTTP_400_BAD_REQUEST)


class DeleteUserRole(generics.RetrieveUpdateDestroyAPIView):
    queryset = get_user_model().objects.all()
    serializer_class = UserSerializer
    permission_classes = (permissions.AllowAny,)
    lookup_field = "id"
    http_method_names = ['delete']

    def delete(self, request, id, role_name):
        try:
            user = get_user_model().objects.get(id=id)

            if has_role(user, role_name):
                remove_role(user, role_name)
                return Response({'message': f'The role "{role_name}" has been revoked from the user.'}, status=status.HTTP_200_OK)

            return Response({'message': f'The user does not have the role "{role_name}".'}, status=status.HTTP_400_BAD_REQUEST)
        except RoleDoesNotExist:
            return Response({'message': 'The specified role does not exist.'}, status=status.HTTP_400_BAD_REQUEST)


class UserPermissions(generics.RetrieveUpdateAPIView):
    queryset = get_user_model().objects.all()
    serializer_class = UserSerializer
    permission_classes = (permissions.AllowAny,)
    lookup_field = "id"
    http_method_names = ['get', 'put']

    def get(self, request, *args, **kwargs):
        user = get_user_model().objects.get(id=kwargs["id"])
        permissions = available_perm_status(user)

        return Response({"data": permissions}, status=status.HTTP_200_OK)

    def put(self, request, *args, **kwargs):
        try:
            data = JSONParser().parse(request)
            permission_name = data.get('permission_name')
            user = get_user_model().objects.get(id=kwargs["id"])

            if has_permission(user, permission_name):
                return Response({"message": f"This user already has the permission {permission_name}"}, status=status.HTTP_400_BAD_REQUEST)

            grant_permission(user, permission_name)

            return Response({"message": f"The permission {permission_name} was added successfully"}, status=status.HTTP_200_OK)
        except RolePermissionScopeException:
            return Response({"message": f"The permission {permission_name} does not exist."}, status=status.HTTP_400_BAD_REQUEST)


class DeleteUserPermission(generics.DestroyAPIView):
    queryset = get_user_model().objects.all()
    serializer_class = UserSerializer
    permission_classes = (permissions.AllowAny,)
    lookup_field = "id"

    def delete(self, request, id, permission_name):
        try:
            user = get_user_model().objects.get(id=id)

            if has_permission(user, permission_name):
                revoke_permission(user, permission_name)
                return Response({'message': f'The role {permission_name} has been revoked from the user.'}, status=status.HTTP_200_OK)

            return Response({'message': f'The user does not have the role {permission_name}.'}, status=status.HTTP_400_BAD_REQUEST)
        except RolePermissionScopeException:
            return Response({'message': 'The specified role does not exist.'}, status=status.HTTP_400_BAD_REQUEST)


class UserHavePermission(generics.RetrieveAPIView):
    queryset = get_user_model().objects.all()
    serializer_class = UserSerializer
    permission_classes = (permissions.AllowAny,)
    lookup_field = "id"

    def get(self, request, *args, **kwargs):
        user = get_user_model().objects.get(id=kwargs["id"])
        permission = has_permission(user, kwargs["permission_name"])

        return Response({'permission': permission}, status=status.HTTP_200_OK)


class UserHaveRole(generics.RetrieveAPIView):
    queryset = get_user_model().objects.all()
    serializer_class = UserSerializer
    permission_classes = (permissions.AllowAny,)
    lookup_field = "id"

    def get(self, request, *args, **kwargs):
        user = get_user_model().objects.get(id=kwargs["id"])
        role = has_role(user, kwargs["role_name"])

        return Response({'role': role}, status=status.HTTP_200_OK)


class UserMailVerification(generics.CreateAPIView):
    queryset = Mail.objects.all()
    serializer_class = UserSerializer
    permission_classes = (permissions.AllowAny,)

    def post(self, request, *args, **kwargs):
        data = JSONParser().parse(request)
        email = data["email"]
        otp = generateOTP()
        try:
            mail.send_otp_mail(email, otp)
            OTP.objects.create(email=email, otp=otp)
            return Response({"status": status.HTTP_200_OK})
        except Exception as e:
            print("Mail Exception :", e)
            return Response({"status": status.HTTP_500_INTERNAL_SERVER_ERROR})


class UserMailCodeVerification(generics.CreateAPIView):
    queryset = Mail.objects.all()
    serializer_class = UserSerializer
    permission_classes = (permissions.AllowAny,)

    def post(self, request, *args, **kwargs):
        data = JSONParser().parse(request)
        mail_otp = data['otp']
        email = data['email']
        print(mail_otp)
        verify = OTP.objects.get(email=email, otp=mail_otp)
        if verify is not None:
            return Response({"status": status.HTTP_200_OK})
        else:
            return Response({"status": status.HTTP_404_NOT_FOUND})


class ContributorCreateAPIView(generics.CreateAPIView):
    queryset = get_user_model().objects.all()
    serializer_class = UserSerializer
    permission_classes = (permissions.AllowAny,)

    def post(self, request, *args, **kwargs):
        try:
            data = JSONParser().parse(request)
            fields = ["email", "contact", "firstname", "lastname",
                      "avatar", "password", "bio", "id_img", "nationality", "residence_country", "address", "birthday"]
            create_fields = {}

            for field in fields:
                if field in data and data[field] is not None:
                    create_fields[field] = data[field]

            user = get_user_model().objects.create(**create_fields)
            user.set_password(data["password"])
            user.save()
            clear_roles(user)
            assign_role(user, "contributor")
            if user:
                return Response({"message": "User created successfully"}, status=status.HTTP_201_CREATED)
            else:
                return Response({"message": "Something went wrong"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        except IntegrityError:
            return Response("This email is already in use !")


class DeviceCreateView(generics.CreateAPIView):
    serializer_class = DeviceSerializer
    queryset = Device.objects.all
    permission_classes = (permissions.AllowAny,)

    def post(self, request, *args, **kwargs):
        data = JSONParser().parse(request)
        token = data.get("token", None)
        if token:
            device = Device.objects.create(registration_id=token)
            user = request.user
            user.devices.add(device)
            user.save()
            fcm_device = GCMDevice.objects.create(
                registration_id=token, user=request.user, cloud_message_type="FCM")
            fcm_device.send_message("You got a message")
            return Response("Device saved succesfully!", status=status.HTTP_200_OK)


class SocialLoginView(generics.CreateAPIView):
    serializer_class = UserSerializer
    permission_classes = (permissions.AllowAny,)
    queryset = get_user_model().objects.all()

    def post(self, request, *args, **kwargs):
        access_token = kwargs["token"]
        response = requests.get(f'https://www.googleapis.com/oauth2/v3/tokeninfo?id_token={access_token}')
        email = response.json()["email"]
        password = response.json()["sub"]
        try:
            user = get_user_model().objects.create_user(email=response.json()["email"], password=response.json()["sub"], firstname=response.json()["given_name"], lastname=response.json()["family_name"])
            token = Token.objects.create(user_id=user.id)
            assign_role(user, "contributor")
            return Response(
                {'token': token.key, 'userId': token.user_id},
                status=status.HTTP_201_CREATED,
            )
        except IntegrityError:
            if email and password:
                user = authenticate(
                    request=request,
                    username=email.lower(),
                    password=password
                )
                token = Token.objects.get(user_id=user.id)
                return Response(
                    {'token': token.key, 'userId': token.user_id},
                    status=status.HTTP_200_OK,
                )


class SendInvitationView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, *args, **kwargs):
        serializer = SendInvitationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        invitee_email = serializer.validated_data['email']
        role = serializer.validated_data.get('role', 'contributor')
        custom_message = serializer.validated_data.get('message', '')

        # Check if invitation already exists and is pending
        existing_invitation = Invitation.objects.filter(
            inviter=request.user,
            invitee_email=invitee_email,
            status=Invitation.PENDING
        ).first()

        if existing_invitation:
            if existing_invitation.is_valid():
                return Response({
                    "message": "An invitation has already been sent to this email address.",
                    "invitation": InvitationSerializer(existing_invitation).data
                }, status=status.HTTP_400_BAD_REQUEST)
            else:
                # Mark expired invitation as expired and create new one
                existing_invitation.mark_as_expired()

        # Test SMTP connection before creating invitation
        smtp_success, smtp_message = test_smtp_connection()
        if not smtp_success:
            return Response({
                "message": f"Unable to send invitation email. SMTP connection failed: {smtp_message}",
                "error": "SMTP_CONNECTION_FAILED"
            }, status=status.HTTP_503_SERVICE_UNAVAILABLE)

        # Create new invitation only if SMTP connection is working
        invitation = Invitation.objects.create(
            inviter=request.user,
            invitee_email=invitee_email,
            role=role,
            message=custom_message
        )

        # Detect language from request or default to French
        language = getattr(request, 'language', 'fr')

        # Send invitation email
        try:
            mail.send_invitation_email(invitation, language)
        except Exception as e:
            print(f"Error sending invitation email: {e}")
            # Continue execution even if email fails

        return Response({
            "message": "Invitation sent successfully",
            "invitation": InvitationSerializer(invitation).data
        }, status=status.HTTP_201_CREATED)


class AcceptInvitationView(generics.CreateAPIView):
    serializer_class = AcceptInvitationSerializer
    permission_classes = (permissions.AllowAny,)

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        token = serializer.validated_data['token']
        firstname = serializer.validated_data['firstname']
        lastname = serializer.validated_data['lastname']
        password = serializer.validated_data['password']

        # Get the invitation
        invitation = Invitation.objects.get(token=token)

        # Create the new user
        try:
            user = get_user_model().objects.create_user(
                email=invitation.invitee_email,
                firstname=firstname,
                lastname=lastname,
                password=password
            )

            # Assign the role specified in the invitation
            assign_role(user, invitation.role)

            # Mark invitation as accepted
            invitation.mark_as_accepted()

            # Create auth token for immediate login
            auth_token = Token.objects.create(user=user)

            return Response({
                "message": "Account created successfully",
                "token": auth_token.key,
                "userId": user.id,
                "user": UserSerializer(user).data
            }, status=status.HTTP_201_CREATED)

        except Exception as e:
            print(f"Error creating user from invitation: {e}")
            return Response({
                "message": "Error creating account. Please try again."
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class InvitationListView(generics.ListAPIView):
    serializer_class = InvitationSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        return Invitation.objects.filter(inviter=self.request.user)


class InvitationDetailView(generics.RetrieveDestroyAPIView):
    serializer_class = InvitationSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_queryset(self):
        return Invitation.objects.filter(inviter=self.request.user)

    def delete(self, request, *args, **kwargs):
        invitation = self.get_object()
        invitation.mark_as_rejected()
        return Response({
            "message": "Invitation cancelled successfully"
        }, status=status.HTTP_200_OK)
