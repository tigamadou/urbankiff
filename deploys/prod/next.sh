# Setup script for panel
cd prod
rm -rf next
unzip next.zip -d next
rm next.zip
cd ./next

# # Stop docker compose
docker compose down || true

# Force rebuild without cache
docker compose build --no-cache

# # Start docker compose
docker compose up -d