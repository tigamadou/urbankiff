# Setup script for urbankiff-api
cd preprod
rm -rf preprod_api
unzip api.zip -d preprod_api
rm api.zip
cd preprod_api

# Stop docker compose
docker compose down || true

# Force rebuild without cache
docker compose build --no-cache

# Start docker compose
docker compose up -d