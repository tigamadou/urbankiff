# Setup script for urbankiff-minio
cd preprod
rm -rf preprod_minio
unzip minio.zip -d preprod_minio
rm minio.zip
cd ./preprod_minio

# # Stop docker compose
docker compose down || true

# Force rebuild without cache
docker compose build --no-cache

# # Start docker compose
docker compose up -d