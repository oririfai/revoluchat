#!/bin/sh
# Script startup untuk Docker container
# Menjalankan migration sebelum start server

echo "Running migrations..."
/app/bin/revoluchat eval "Revoluchat.Release.migrate"

echo "Starting server..."
exec /app/bin/revoluchat start
