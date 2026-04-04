#!/bin/sh
set -e

# Run migrations
/app/bin/revoluchat eval "Revoluchat.Release.migrate"

# Run seeds
/app/bin/revoluchat eval "Revoluchat.Release.seed"

# Start the application
exec /app/bin/revoluchat start
