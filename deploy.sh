#!/bin/bash

# SpiderMe Deployment Script
# This script builds the Docker image and deploys it to production

set -e  # Exit on any error

# Configuration
IMAGE_NAME="llllollooll/spiderme"
IMAGE_TAG="latest"
CONTAINER_NAME="spiderme-app"
NETWORK_NAME="network_public"
PORT="3000"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        error "Docker is not running. Please start Docker daemon."
    fi
    success "Docker is running"
}

# Build the Docker image
build_image() {
    log "Building Docker image ${IMAGE_NAME}:${IMAGE_TAG}"
    
    # Check if we're in the correct directory
    if [[ ! -f "Dockerfile" ]]; then
        error "Dockerfile not found. Please run this script from the project root."
    fi
    
    docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .
    
    if [[ $? -eq 0 ]]; then
        success "Image built successfully"
    else
        error "Failed to build image"
    fi
}

# Push image to Docker Hub
push_image() {
    log "Pushing image to Docker Hub"
    
    # Check if logged in to Docker Hub
    if ! docker login --username llllollooll > /dev/null 2>&1; then
        warning "Not logged in to Docker Hub. Please run: docker login --username llllollooll"
        return 1
    fi
    
    docker push "${IMAGE_NAME}:${IMAGE_TAG}"
    
    if [[ $? -eq 0 ]]; then
        success "Image pushed to Docker Hub"
    else
        error "Failed to push image"
    fi
}

# Deploy to production server (simulated - adjust for your environment)
deploy_production() {
    log "Deploying to production server"
    
    # This section would typically SSH into your production server
    # For now, we'll simulate the deploy commands
    
    echo "Production deployment commands:"
    echo "1. SSH into production server"
    echo "2. Run: ./deploy.sh"  # Your existing deploy script
    echo ""
    
    # Simulate the actual deploy script
    cat << 'EOF'
# On production server (automacao):
IMAGE="llllollooll/spiderme:latest"
CONTAINER="spiderme-app"
NETWORK="network_public"

echo "Pulling latest image..."
sudo docker pull "$IMAGE"

echo "Stopping and removing old container..."
sudo docker rm -f "$CONTAINER" 2>/dev/null

echo "Starting new container with Traefik labels..."
sudo docker run -d \
    --name "$CONTAINER" \
    --network "$NETWORK" \
    -p 3000:3000 \
    -e POSTGRES_HOST=postgres-main \
    -e POSTGRES_USER=n8n \
    -e POSTGRES_PASSWORD="zivyarsql_n8n@5123" \
    -e POSTGRES_DB=spider_db \
    --label "traefik.enable=true" \
    --label "traefik.http.routers.spiderme.rule=Host(\`spiderme.org\`) || Host(\`www.spiderme.org\`)" \
    --label "traefik.http.routers.spiderme.entrypoints=websecure" \
    --label "traefik.http.routers.spiderme.tls=true" \
    --label "traefik.http.routers.spiderme.tls.certresolver=letsencrypt" \
    --label "traefik.http.routers.spiderme.middlewares=spider-headers" \
    --label "traefik.http.services.spiderme.loadbalancer.server.port=3000" \
    --label "traefik.http.middlewares.spider-headers.headers.customRequestHeaders.X-HX-Request=*" \
    "$IMAGE"

echo "Deploy finished! Check https://spiderme.org"

# Instructions for server deployment
cat << 'EOF'

📋 SERVER DEPLOYMENT INSTRUCTIONS:

1. On your production server (automacao), create ~/deploy.sh:

#!/bin/bash
IMAGE="llllollooll/spiderme:latest"
CONTAINER="spiderme-app"
NETWORK="network_public"

echo "Pulling latest image..."
sudo docker pull "$IMAGE"

echo "Stopping and removing old container..."
sudo docker rm -f "$CONTAINER" 2>/dev/null

echo "Starting new container with Traefik labels..."
sudo docker run -d \
    --name "$CONTAINER" \
    --network "$NETWORK" \
    -p 3000:3000 \
    -e POSTGRES_HOST=postgres-main \
    -e POSTGRES_USER=n8n \
    -e POSTGRES_PASSWORD="zivyarsql_n8n@5123" \
    -e POSTGRES_DB=spider_db \
    --label "traefik.enable=true" \
    --label "traefik.http.routers.spiderme.rule=Host(\`spiderme.org\`) || Host(\`www.spiderme.org\`)" \
    --label "traefik.http.routers.spiderme.entrypoints=websecure" \
    --label "traefik.http.routers.spiderme.tls=true" \
    --label "traefik.http.routers.spiderme.tls.certresolver=letsencrypt" \
    --label "traefik.http.routers.spiderme.middlewares=spider-headers" \
    --label "traefik.http.services.spiderme.loadbalancer.server.port=3000" \
    --label "traefik.http.middlewares.spider-headers.headers.customRequestHeaders.X-HX-Request=*" \
    "$IMAGE"

echo "Deploy finished! Check https://spiderme.org"

2. Make it executable:
chmod +x ~/deploy.sh

3. Run deployment:
./deploy.sh

EOF