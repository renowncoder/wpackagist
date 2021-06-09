#!/bin/bash

# This script is taken from https://aws.amazon.com/blogs/security/how-to-manage-secrets-for-amazon-ec2-container-service-based-applications-by-using-amazon-s3-and-docker/
# and is used to set up app secrets in ECS without exposing them as widely as using ECS env vars directly would.

# Check that the environment variable has been set correctly
if [ -z "$SECRETS_URI" ]; then
  echo >&2 'error: missing SECRETS_URI environment variable'
  exit 1
fi

# Load the S3 secrets file contents into the environment variables
export $(aws s3 cp ${SECRETS_URI} - | grep -v '^#' | xargs)

echo "Dumping env..."
composer dump-env "${APP_ENV}"

echo "Clearing & warming cache..."
bin/console cache:clear --no-debug --env=$APP_ENV

echo "Generating Doctrine proxies..."
bin/console doctrine orm:generate-proxies --env=$APP_ENV

echo "Running DB migrations..."
bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration --env=$APP_ENV

# This might be needed for Doctrine's query parser cache to save things – we had runtime warnings before
# adding both this and the early proxy generation.
chmod -R 777 /var/www/html/var/cache

echo "Starting Apache..."
# Call the normal web server entry-point script
apache2-foreground "$@"
