# Setup script for panel
cd preprod
rm -rf preprod_panel
unzip panel.zip -d preprod_panel
rm panel.zip
cd ./preprod_panel

# # Stop docker compose
docker compose down || true

# Force rebuild without cache
docker compose build --no-cache

# # Start docker compose
docker compose up -d