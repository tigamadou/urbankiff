# Setup script for panel
cd prod
rm -rf prod_panel
unzip panel.zip -d prod_panel
rm panel.zip 
cd ./prod_panel

# # Stop docker compose
docker compose down || true

# Force rebuild without cache
docker compose build --no-cache

# # Start docker compose
docker compose up -d