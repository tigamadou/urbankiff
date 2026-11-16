from rolepermissions.roles import AbstractUserRole


class Administrator(AbstractUserRole):
    available_permissions = {
        'create_post': True,
        'edit_post': True,
        'read_post': True,
        'delete_post': True,
        'publish_post': True,
        'unpublish_post': True,
        'create_page': True,
        'edit_page': True,
        'read_page': True,
        'delete_page': True,
        'publish_page': True,
        'unpublish_page': True,
        'create_user': True,
        'update_user': True,
        'read_user': True,
        'delete_user': True,
    }


class Editor(AbstractUserRole):
    available_permissions = {
        'create_post': True,
        'edit_post': True,
        'read_post': True,
        'delete_post': True,
        'publish_post': True,
        'unpublish_post': True,
        'create_page': False,
        'edit_page': False,
        'read_page': False,
        'delete_page': False,
        'publish_page': False,
        'unpublish_page': False,
        'create_user': False,
        'update_user': False,
        'read_user': False,
        'delete_user': False,
    }


class Contributor(AbstractUserRole):
    available_permissions = {
        'create_post': True,
        'edit_post': True,
        'read_post': True,
        'delete_post': True,
        'publish_post': False,
        'unpublish_post': False,
        'create_page': False,
        'edit_page': False,
        'read_page': False,
        'delete_page': False,
        'publish_page': False,
        'unpublish_page': False,
        'create_user': False,
        'update_user': False,
        'read_user': False,
        'delete_user': False,
    }


class User(AbstractUserRole):
    available_permissions = {
        'create_post': False,
        'edit_post': False,
        'read_post': False,
        'delete_post': False,
        'publish_post': False,
        'unpublish_post': False,
        'create_page': False,
        'edit_page': False,
        'read_page': False,
        'delete_page': False,
        'publish_page': False,
        'unpublish_page': False,
        'create_user': False,
        'update_user': False,
        'read_user': False,
        'delete_user': False,
    }
