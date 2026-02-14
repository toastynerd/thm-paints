#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SERVICE_NAME="thm-paints"
REGION="us-west-2"

echo -e "${BLUE}Starting deployment of thm-paints to AWS Lightsail...${NC}"

# Check if Lightsail service exists
SERVICE_STATE=$(aws lightsail get-container-services --service-name ${SERVICE_NAME} --region ${REGION} --query 'containerServices[0].state' --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$SERVICE_STATE" == "NOT_FOUND" ]; then
  echo -e "${RED}Error: Lightsail container service '${SERVICE_NAME}' not found!${NC}"
  echo -e "${BLUE}Run 'make setup' first to create the service.${NC}"
  exit 1
fi

if [ "$SERVICE_STATE" != "ACTIVE" ] && [ "$SERVICE_STATE" != "RUNNING" ] && [ "$SERVICE_STATE" != "READY" ]; then
  echo -e "${RED}Warning: Service is in '${SERVICE_STATE}' state. Waiting for it to become active...${NC}"
  aws lightsail get-container-services --service-name ${SERVICE_NAME} --region ${REGION} 2>&1 | grep -q "ACTIVE\|RUNNING\|READY" || {
    echo -e "${RED}Service is not ready. Please wait and try again.${NC}"
    exit 1
  }
fi

# Build Docker image for AMD64 (Lightsail requirement)
echo -e "${BLUE}Building Docker image for linux/amd64...${NC}"
docker build --platform linux/amd64 -t ${SERVICE_NAME}:latest .

# Export credentials from aws login session so lightsailctl can use them
echo -e "${BLUE}Exporting AWS credentials for lightsailctl...${NC}"
eval $(aws configure export-credentials --format env)

# Push to Lightsail using lightsailctl (now with credentials available)
echo -e "${BLUE}Pushing image to Lightsail...${NC}"
aws lightsail push-container-image \
  --service-name ${SERVICE_NAME} \
  --label latest \
  --image ${SERVICE_NAME}:latest \
  --region ${REGION}

# Get the latest image tag
echo -e "${BLUE}Getting latest image reference...${NC}"
LATEST_IMAGE=$(aws lightsail get-container-images --service-name ${SERVICE_NAME} --region ${REGION} --query 'containerImages[0].image' --output text)

echo -e "${BLUE}Using image: ${LATEST_IMAGE}${NC}"

# Update containers.json with the actual image reference
sed "s|:${SERVICE_NAME}.latest|${LATEST_IMAGE}|g" lightsail/containers.json > /tmp/containers-deploy.json

# Deploy
echo -e "${BLUE}Deploying new version...${NC}"
aws lightsail create-container-service-deployment \
  --service-name ${SERVICE_NAME} \
  --containers file:///tmp/containers-deploy.json \
  --public-endpoint file://lightsail/public-endpoint.json \
  --region ${REGION}

# Clean up temp file
rm /tmp/containers-deploy.json

echo -e "${GREEN}✓ Deployment initiated!${NC}"
echo -e "${BLUE}Waiting for deployment to complete (this may take 2-3 minutes)...${NC}"

# Wait for deployment to complete
for i in {1..30}; do
  DEPLOYMENT_STATE=$(aws lightsail get-container-services --service-name ${SERVICE_NAME} --region ${REGION} --query 'containerServices[0].state' --output text 2>/dev/null || echo "UNKNOWN")

  if [ "$DEPLOYMENT_STATE" == "RUNNING" ]; then
    echo -e "${GREEN}✓ Deployment complete!${NC}"
    break
  fi

  echo -e "${BLUE}  Deployment state: ${DEPLOYMENT_STATE} (waiting...)${NC}"
  sleep 10
done

# Get service URL
SERVICE_URL=$(aws lightsail get-container-services --service-name ${SERVICE_NAME} --region ${REGION} --query 'containerServices[0].url' --output text)

echo -e "${GREEN}✓ Your site is live at: https://${SERVICE_URL}${NC}"
echo -e "${BLUE}Note: Custom domain (thmpaints.com) requires additional setup. See LIGHTSAIL.md${NC}"
