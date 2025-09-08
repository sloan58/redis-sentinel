#!/bin/sh

ROLE=${1:-swarm}
CONTAINER_IP=$(hostname -i)
SERVICE_NAME=${REDIS_MASTER_SERVICE:-redis-sentinel}

echo "Starting Redis+Sentinel node in Docker Swarm mode"
echo "Container IP: $CONTAINER_IP"
echo "Service Name: $SERVICE_NAME"

# Determine if this should be master or slave based on task slot
TASK_SLOT=${DOCKER_TASK_SLOT:-1}
echo "Task Slot: $TASK_SLOT"

# First replica becomes master, others become slaves
if [ "$TASK_SLOT" = "1" ]; then
    REDIS_ROLE="master"
    echo "This node will be the Redis MASTER"
else
    REDIS_ROLE="slave"
    echo "This node will be a Redis SLAVE"
fi

# Start Redis server based on role
if [ "$REDIS_ROLE" = "master" ]; then
    echo "Starting Redis Master..."
    redis-server /usr/local/etc/redis/redis-master.conf --daemonize yes
else
    echo "Starting Redis Slave..."
    # Wait for master service to be available
    echo "Waiting for Redis master service to be ready..."
    until nslookup $SERVICE_NAME > /dev/null 2>&1; do
        echo "Master service not ready, waiting..."
        sleep 2
    done
    
    # Get master IP from service discovery
    MASTER_IP=$(nslookup $SERVICE_NAME | grep -A1 "Name:" | tail -1 | awk '{print $2}' | head -1)
    echo "Master IP resolved to: $MASTER_IP"
    
    # Update slave config with master IP
    cp /usr/local/etc/redis/redis-slave.conf /tmp/redis-slave.conf
    sed -i "s/MASTER_HOST/$MASTER_IP/g" /tmp/redis-slave.conf
    
    redis-server /tmp/redis-slave.conf --daemonize yes
fi

# Wait for Redis to start
sleep 3

# Configure and start Sentinel
echo "Starting Sentinel..."

# Copy sentinel config and update with container IP and master service
cp /usr/local/etc/redis/sentinel.conf /tmp/sentinel.conf
sed -i "s/PLACEHOLDER_IP/$CONTAINER_IP/g" /tmp/sentinel.conf

# For Swarm, use service name for master discovery
sed -i "s/MASTER_IP/$SERVICE_NAME/g" /tmp/sentinel.conf

# If this is not the master node, wait a bit more for master to be fully ready
if [ "$REDIS_ROLE" != "master" ]; then
    echo "Waiting for master Redis to be fully ready..."
    sleep 5
fi

# Start Sentinel
echo "Starting Sentinel monitoring service: $SERVICE_NAME"
exec redis-sentinel /tmp/sentinel.conf