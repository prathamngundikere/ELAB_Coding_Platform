#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to check if a port is free
check_port() {
    if lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null ; then
        echo -e "${RED}Port $1 is in use${NC}"
        return 1
    fi
    return 0
}

# Function to wait for service to be ready
wait_for_service() {
    local service=$1
    local port=$2
    local max_attempts=30
    local attempt=1

    echo -e "${YELLOW}Waiting for $service to be ready on port $port...${NC}"
    while ! nc -z localhost $port && [ $attempt -le $max_attempts ]; do
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    echo ""
    
    if [ $attempt -le $max_attempts ]; then
        echo -e "${GREEN}$service is ready!${NC}"
        return 0
    else
        echo -e "${RED}$service failed to start${NC}"
        return 1
    fi
}

# Check Docker
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

# Check ports
for port in 3000 4000 27017; do
    if ! check_port $port; then
        echo -e "${RED}Please free port $port and try again${NC}"
        exit 1
    fi
done

# Stop any running containers
echo -e "${YELLOW}Stopping any existing containers...${NC}"
docker-compose down --remove-orphans

# Remove any existing containers to ensure clean state
echo -e "${YELLOW}Cleaning up any existing containers...${NC}"
docker container prune -f

echo -e "${GREEN}Starting services in sequence...${NC}"

# 1. Start Judge0 Database and Redis
echo "1. Starting Judge0 Database and Redis..."
docker-compose up -d judge0-db judge0-redis
sleep 5

# 2. Start Judge0 Server
echo "2. Starting Judge0 Server..."
docker-compose up -d judge0-server
if ! wait_for_service "Judge0 Server" 3000; then
    echo -e "${RED}Failed to start Judge0 Server${NC}"
    docker-compose down
    exit 1
fi

# 3. Start Judge0 Workers
echo "3. Starting Judge0 Workers..."
docker-compose up -d judge0-workers
sleep 5

# 4. Start MongoDB
echo "4. Starting MongoDB..."
docker-compose up -d mongodb
if ! wait_for_service "MongoDB" 27017; then
    echo -e "${RED}Failed to start MongoDB${NC}"
    docker-compose down
    exit 1
fi

# 5. Finally, start the ELAB application
echo "5. Starting ELAB application..."
docker-compose up -d elab-app
if ! wait_for_service "ELAB" 4000; then
    echo -e "${RED}Failed to start ELAB${NC}"
    docker-compose logs elab-app
    exit 1
fi

# Final status check
echo -e "\n${GREEN}Checking final status of all services:${NC}"
docker-compose ps

echo -e "\n${GREEN}Setup complete! You can access:${NC}"
echo "- ELAB: http://localhost:4000"
echo "- Judge0: http://localhost:3000/docs"
echo "- MongoDB: localhost:27017"

# Show logs of ELAB app
echo -e "\n${YELLOW}Showing last few lines of ELAB app logs:${NC}"
docker-compose logs --tail=20 elab-app
