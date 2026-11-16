# Setup script for urbankiff-api
cd prod
rm -rf prod_api
unzip api.zip -d prod_api
rm api.zip 
cd prod_api

# Stop docker compose
docker compose down || true

# Force rebuild without cache
docker compose build --no-cache

# Start docker compose
docker compose up -d