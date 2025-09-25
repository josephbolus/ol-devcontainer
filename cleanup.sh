#!/bin/bash
set -e

# Check if running inside the devcontainer
if [ "$PWD" = "/workspace" ]; then
    echo "⚠️  ./cleanup.sh must be run outside of the devcontainer"
    exit 1
fi

# Check if docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed or not in PATH"
    exit 1
fi

cdir=$(basename "$PWD")
echo "-> Current directory: $cdir"

# Function to safely stop and remove containers
safe_cleanup() {
    local container=$1
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        echo "  Stopping $container..."
        docker stop "$container" 2>/dev/null || true
        echo "  Removing $container..."
        docker rm "$container" 2>/dev/null || true
    else
        echo "  Container $container not found (skipping)"
    fi
}

# Function to safely remove volumes
safe_volume_remove() {
    local volume=$1
    if docker volume ls --format '{{.Name}}' | grep -q "^${volume}$"; then
        echo "  Removing volume $volume..."
        docker volume rm "$volume" 2>/dev/null || true
    else
        echo "  Volume $volume not found (skipping)"
    fi
}

echo "-> Stopping and removing containers..."
safe_cleanup "${cdir}_devcontainer"
safe_cleanup "${cdir}-devcontainer"  # Alternative naming
safe_cleanup "mysql-replica"
safe_cleanup "mysql-primary"

echo "-> Removing data volumes..."
safe_volume_remove "${cdir}_devcontainer_mysql-primary-data"
safe_volume_remove "${cdir}_devcontainer_mysql-replica-data"
safe_volume_remove "${cdir}-devcontainer_mysql-primary-data"  # Alternative naming
safe_volume_remove "${cdir}-devcontainer_mysql-replica-data"  # Alternative naming

# Remove any dangling networks
echo "-> Cleaning up networks..."
docker network ls --format '{{.Name}}' | grep -E "${cdir}.*mysql-network" | while read -r network; do
    echo "  Removing network $network..."
    docker network rm "$network" 2>/dev/null || true
done

echo "-> ✅  All cleanup completed successfully"
