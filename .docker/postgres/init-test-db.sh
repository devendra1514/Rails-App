#!/bin/bash
set -e

# Create test database alongside default development database on initial volume initialization
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    SELECT 'CREATE DATABASE app_test'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'app_test')\gexec
    GRANT ALL PRIVILEGES ON DATABASE app_test TO $POSTGRES_USER;
EOSQL
