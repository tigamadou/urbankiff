FROM python:3.9.13-bullseye AS base

# =================================================================================================
# Setup system
# =================================================================================================
WORKDIR /app
COPY . .

# =================================================================================================
# Setup Python
# =================================================================================================
RUN pip install --upgrade pip wheel
RUN pip install -r requirements.txt

# =================================================================================================
# Production : gunicorn, utilisateur non root, ecriture seulement dans /tmp
# =================================================================================================
FROM base AS prod
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 HOME=/tmp
RUN groupadd --gid 10001 app \
    && useradd --uid 10001 --gid 10001 --no-create-home --shell /usr/sbin/nologin app \
    && chmod -R a+rX /app
USER 10001:10001
EXPOSE 8000
CMD ["gunicorn", "project.wsgi", "-c", "python:project.gunicorn"]

# =================================================================================================
# Developpement (derniere etape : cible par defaut du Compose local)
# =================================================================================================
FROM base AS dev
