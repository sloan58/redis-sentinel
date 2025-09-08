#!/bin/sh

# Start Redis server in background
redis-server /usr/local/etc/redis/redis.conf --port 6379 --daemonize yes

# Wait for Redis to start
sleep 2

# Get the service name and task slot from environment
SERVICE_NAME=${REDIS_MASTER_SERVICE:-redis-sentinel}
TASK_SLOT=${DOCKER_TASK_SLOT:-1}

# Copy config to temp location to avoid "Resource busy" error
cp /usr/local/etc/redis/sentinel.conf /tmp/sentinel.conf
sed -i "s/PLACEHOLDER/$SERVICE_NAME/g" /tmp/sentinel.conf

# Start Sentinel with the modified config
echo "Starting Sentinel with service name: $SERVICE_NAME"
redis-sentinel /tmp/sentinel.conf --port 26379
