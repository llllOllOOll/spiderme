# SpiderMe Deployment Guide

This document describes the complete deployment process for the SpiderMe application.

## 🚀 Quick Deployment

### Local Development
```bash
# Build and run locally
zig build run

# Or run directly
./spiderme
```

### Production Deployment Pipeline

#### 1. Build Docker Image
```bash
./deploy.sh build
```

#### 2. Push to Docker Hub
```bash
./deploy.sh push
```

#### 3. Deploy to Production Server
```bash
./deploy.sh deploy
```

#### 4. Complete Pipeline (All Steps)
```bash
./deploy.sh all
```

## 📋 Server Deployment Script

On your production server (`automacao`), create `~/deploy.sh`:

```bash
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
    --label "traefik.enable=true" \
    --label "traefik.http.routers.spiderme.rule=Host(\`spiderme.org\`)" \
    --label "traefik.http.routers.spiderme.entrypoints=websecure" \
    --label "traefik.http.routers.spiderme.tls.certresolver=letsencrypt" \
    "$IMAGE"

echo "Deploy finished! Check https://spiderme.org"
```

Make it executable:
```bash
chmod +x ~/deploy.sh
```

## 🔧 Manual Deployment Steps

### 1. Build Image Locally
```bash
docker build -t llllollooll/spiderme:latest .
```

### 2. Push to Docker Hub
```bash
docker push llllollooll/spiderme:latest
```

### 3. Deploy to Server
SSH into your production server and run:
```bash
# Pull latest image
sudo docker pull llllollooll/spiderme:latest

# Stop and remove old container
sudo docker rm -f spiderme-app

# Start new container
sudo docker run -d \
    --name spiderme-app \
    --network network_public \
    --label "traefik.enable=true" \
    --label "traefik.http.routers.spiderme.rule=Host(\`spiderme.org\`)" \
    --label "traefik.http.routers.spiderme.entrypoints=websecure" \
    --label "traefik.http.routers.spiderme.tls.certresolver=letsencrypt" \
    llllollooll/spiderme:latest
```

## 📊 Health Checks

### Verify Container Status
```bash
# Check if container is running
sudo docker ps | grep spiderme-app

# Check container logs
sudo docker logs spiderme-app

# Check Traefik routing
sudo docker exec traefik cat /etc/traefik/traefik.yml
```

### Test Application
```bash
# Test health endpoint
curl https://spiderme.org/ping

# Test documentation
curl https://spiderme.org/docs

# Check WebSocket demo
curl https://spiderme.org/chat
```

## 🔄 Rollback Procedure

If deployment fails, rollback to previous version:

```bash
# Stop current container
sudo docker stop spiderme-app

# Start previous version
sudo docker run -d \
    --name spiderme-app \
    --network network_public \
    --label "traefik.enable=true" \
    --label "traefik.http.routers.spiderme.rule=Host(\`spiderme.org\`)" \
    --label "traefik.http.routers.spiderme.entrypoints=websecure" \
    --label "traefik.http.routers.spiderme.tls.certresolver=letsencrypt" \
    llllollooll/spiderme:previous-version
```

## 📈 Monitoring

### Container Metrics
```bash
# Check resource usage
sudo docker stats spiderme-app

# Check disk space
sudo docker system df
```

### Application Logs
```bash
# Real-time logs
sudo docker logs -f spiderme-app

# Last 100 lines
sudo docker logs --tail 100 spiderme-app

# Logs with timestamps
sudo docker logs -t spiderme-app
```

## 🛠️ Troubleshooting

### Common Issues

1. **Container won't start**
   ```bash
   # Check error details
   sudo docker logs spiderme-app
   
   # Remove and recreate
   sudo docker rm -f spiderme-app
   sudo docker run ... [full command]
   ```

2. **Traefik routing issues**
   ```bash
   # Check Traefik configuration
   sudo docker exec traefik cat /etc/traefik/traefik.yml
   
   # Restart Traefik
   sudo docker restart traefik
   ```

3. **PostgreSQL connection issues**
   ```bash
   # Check PostgreSQL logs
   sudo docker logs postgres-container
   
   # Verify network connectivity
   sudo docker network inspect network_public
   ```

### Debug Commands

```bash
# Inspect container details
sudo docker inspect spiderme-app

# Check network configuration
sudo docker network ls
sudo docker network inspect network_public

# Check Traefik routing table
sudo docker exec traefik traefik --help
```

## 🔒 Security Considerations

- Keep Docker images updated
- Use strong passwords for PostgreSQL
- Enable SSL/TLS with Let's Encrypt
- Monitor container resource usage
- Regular security scans

## 📚 Related Documentation

- [Spider Framework Docs](https://spiderme.org/docs)
- [Docker Documentation](https://docs.docker.com)
- [Traefik Documentation](https://doc.traefik.io)
- [PostgreSQL Documentation](https://www.postgresql.org/docs)

---

**Maintained by:** SpiderMe Team  
**Last Updated:** $(date +%Y-%m-%d)