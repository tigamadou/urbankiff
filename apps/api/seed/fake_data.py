from apps.category.models import Category
from apps.user.models import User
from apps.post.models import Post
from faker import Faker
from django.utils.text import slugify
import random
from rolepermissions.roles import assign_role, remove_role, get_user_roles
from rolepermissions.checkers import has_role, has_permission
import os

myfake = Faker()
# =============Remove all old information on the database==============================
User.objects.all().delete()
Category.objects.all().delete()
Post.objects.all().delete()

# =============Add new seed information on the database================================
user = User.objects.create_superuser(
    email="ubnews@admin.com",
    password="password",
    contact="22999999999",
    firstname="Admin",
    lastname="Admin",
    status="active",
    avatar="images/fck2c7a8-gc4v-4q3s-behi-5fhnqti9mak4.jpg"
)
user.save()

if not has_role(user, "administrator"):
    assign_role(user, "administrator")

images = ["dummy_1920x1080_1.webp","dummy_1920x1080_2.webp","dummy_1920x1080_3.webp","dummy_1920x1080_4.webp"]
booleans = ["True", "False"]
categories= ["people", "cinema", "videos"]
languages = ["en", "fr"]

for language in languages:
    for category in categories:
        Category.objects.create(
            name=category,
            color=myfake.color(),
            language= language,
            slug=slugify(category)
        )
Category.objects.create(
        name="musiques",
        color=myfake.color(),
        language= "fr",
        slug=slugify("fr")
    )
Category.objects.create(
        name="artistes",
        color=myfake.color(),
        language= "fr",
        slug=slugify("fr")
    )
Category.objects.create(
        name="musics",
        color=myfake.color(),
        language= "en",
        slug=slugify("en")
    )
Category.objects.create(
        name="artists",
        color=myfake.color(),
        language= "en",
        slug=slugify("en")
    )

categories = Category.objects.all()
for category in categories:
    for i in range(20):
        title = myfake.text(max_nb_chars=40)
        Post.objects.create(
            title=title,
            slug= slugify(title),
            intro=myfake.text(max_nb_chars=100),
            content=myfake.text(max_nb_chars=500),
            image=f"{os.environ.get('API_URL')}/files/{random.choice(images)}",
            url="{}/{}".format(category.slug, slugify(title)),
            published=True,
            deleted=False,
            author=user,
            category=category,
            language=category.language
        )

posts = Post.objects.all()
print(posts.count())
