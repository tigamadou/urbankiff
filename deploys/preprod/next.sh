# Setup script for panel
cd preprod
rm -rf next_preprod
unzip next.zip -d next_preprod
rm next.zip
cd ./next_preprod

# # Stop docker compose
docker compose down || true

# Force rebuild without cache
docker compose build --no-cache

# # Start docker compose
docker compose up -d