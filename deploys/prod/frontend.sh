# Setup script for urbankiff-api
cd prod
rm -rf prod_app
unzip frontend.zip -d prod_app
rm frontend.zip
cd ./prod_app

# # Stop docker compose
docker compose down || true

# Force rebuild without cache
docker compose build --no-cache

# # Start docker compose
docker compose up -d