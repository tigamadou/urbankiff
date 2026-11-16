# Setup script for urbankiff-api
cd preprod
rm -rf preprod_app
unzip frontend.zip -d preprod_app
rm frontend.zip
cd ./preprod_app

# # Stop docker compose
docker compose down || true

# Force rebuild without cache
docker compose build --no-cache

# # Start docker compose
docker compose up -d