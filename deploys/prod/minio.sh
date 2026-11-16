# Setup script for urbankiff-minio
cd prod
rm -rf prod_minio
unzip minio.zip -d prod_minio
rm minio.zip
cd ./prod_minio

# # Stop docker compose
docker compose down || true

# Force rebuild without cache
docker compose build --no-cache

# # Start docker compose
docker compose up -d