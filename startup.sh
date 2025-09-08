#!/bin/sh

# Start Redis server in background
redis-server /usr/local/etc/redis/redis.conf --port 6379 --daemonize yes

# Wait a moment for Redis to start
sleep 2

# Configure Sentinel based on container name
# Copy config to temp location to avoid "Resource busy" error
cp /usr/local/etc/redis/sentinel.conf /tmp/sentinel.conf
sed -i "s/PLACEHOLDER/$HOSTNAME/g" /tmp/sentinel.conf

# Start Sentinel with the modified config
redis-sentinel /tmp/sentinel.conf --port 26379
