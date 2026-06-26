#!/bin/bash
set -e

cd .agendum-data || exit 1

docker compose down -v --remove-orphans
docker compose ps

docker compose up -d --build --force-recreate
docker compose exec agendum migrate --wait-database

docker compose logs -f agendum
