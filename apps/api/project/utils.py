
from rolepermissions.checkers import has_role
from apps.post.models import Post


def is_admin(user):
    if has_role(user, "administrator"):
        return True
    return False


def is_editor(user):
    if has_role(user, "editor"):
        return True
    return False


def is_contributor(user):
    if has_role(user, "contributor"):
        return True
    return False


def have_role(user, role):
    if has_role(user, role):
        return True
    return False


def is_admin_or_editor(user):
    if has_role(user, "editor") or has_role(user, "administrator"):
        return True
    return False


def is_admin_or_editor_or_contributor(user):
    if has_role(user, "editor") or has_role(user, "administrator") or has_role(user, "contributor"):
        return True
    return False


def is_owner_of_post(user, post_id):
    post = Post.objects.get(id=post_id, author=user)
    if not post:
        return False
    return True
