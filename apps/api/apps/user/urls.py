from django.urls import path

from . import views

urlpatterns = [
    path('me', views.Me.as_view(), name='me'),
    path('users', views.UserList.as_view(), name='user-list'),
    path('user/<int:id>', views.UserDetails.as_view(), name='user-details'),
    path('auth/signup', views.UserCreate.as_view(), name='signup'),
    path('auth/contributor', views.ContributorCreateAPIView.as_view(),
         name='contributor'),
    path('auth/login', views.UserLogin.as_view(), name='login'),
    path('auth/forgot-password', views.UserForgotPassword.as_view(),
         name='forgot-password'),

    path('auth/reset-password', views.UserResetPassword.as_view(),
         name='reset-password'),
    path('auth/validate-reset-token', views.ValidatePasswordResetToken.as_view(),
         name='validate-reset-token'),
    path('auth/change-password', views.UserChangePassword.as_view(),
         name='change-password'),
    path('upload-avatar/<int:id>',
         views.UserProfilePictureUpload.as_view(), name='upload-avatar'),
    path('role/<int:id>', views.AddUserRole.as_view(), name='role'),
    path('role/<int:id>/<str:role_name>',
         views.DeleteUserRole.as_view(), name='delete-role'),
    path('permission/<int:id>', views.UserPermissions.as_view(), name='permission'),
    path('permission/<int:id>/<str:permission_name>',
         views.DeleteUserPermission.as_view(), name='delete-permission'),
    path('have-permission/<int:id>/<str:permission_name>',
         views.UserHavePermission.as_view(), name='have-permission'),
    path('have-role/<int:id>/<str:role_name>',
         views.UserHaveRole.as_view(), name='have-role'),
    path("auth/email-verification",
         views.UserMailVerification.as_view(), name="email-verification"),
    path("auth/verify-email-code",
         views.UserMailCodeVerification.as_view(), name="email-code-verification"),
    path('allow-notification', views.DeviceCreateView.as_view()),
    path("social-login/google/<str:token>", views.SocialLoginView.as_view(), name="google-social-login"),

    # Invitation URLs
    path('invitations/send', views.SendInvitationView.as_view(), name='send-invitation'),
    path('invitations/accept', views.AcceptInvitationView.as_view(), name='accept-invitation'),
    path('invitations', views.InvitationListView.as_view(), name='invitation-list'),
    path('invitations/<int:pk>', views.InvitationDetailView.as_view(), name='invitation-detail'),
]

# https://accounts.google.com/o/oauth2/v2/auth?redirect_uri=http://localhost:8000/auth/social/google/login/callback/&prompt=consent&response_type=token&client_id=173001637257-mbl62q1k3u713hc5luavp1n3eshpm8pj.apps.googleusercontent.com&scope=openid%20email%20profile
