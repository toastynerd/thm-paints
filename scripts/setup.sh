#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SERVICE_NAME="thm-paints"
REGION="us-west-2"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  AWS Lightsail Setup for thm-paints${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
  echo -e "${RED}Error: AWS CLI is not installed!${NC}"
  echo -e "${BLUE}Install with: brew install awscli${NC}"
  exit 1
fi

# Check if lightsailctl is installed
if ! command -v lightsailctl &> /dev/null; then
  echo -e "${RED}Error: lightsailctl plugin is not installed!${NC}"
  echo -e "${BLUE}Install with: brew install aws/tap/lightsailctl${NC}"
  exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
  echo -e "${RED}Error: AWS credentials not configured!${NC}"
  echo -e "${BLUE}Run: aws configure${NC}"
  echo ""
  echo "You'll need:"
  echo "  - AWS Access Key ID"
  echo "  - AWS Secret Access Key"
  echo "  - Default region: us-west-2"
  echo "  - Default output format: json"
  exit 1
fi

echo -e "${GREEN}✓ AWS CLI and lightsailctl are installed and configured${NC}"
echo ""

# Check if service already exists
SERVICE_EXISTS=$(aws lightsail get-container-services --service-name ${SERVICE_NAME} --region ${REGION} 2>&1 | grep -q "NotFoundException" && echo "false" || echo "true")

if [ "$SERVICE_EXISTS" == "true" ]; then
  echo -e "${YELLOW}Warning: Container service '${SERVICE_NAME}' already exists!${NC}"
  read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Deleting existing service...${NC}"
    aws lightsail delete-container-service --service-name ${SERVICE_NAME} --region ${REGION}
    echo -e "${BLUE}Waiting for deletion to complete (this takes ~5 minutes)...${NC}"
    sleep 300
  else
    echo -e "${BLUE}Keeping existing service. You can deploy with 'make publish'${NC}"
    exit 0
  fi
fi

# Create Lightsail container service
echo -e "${BLUE}Creating Lightsail container service...${NC}"
echo -e "${BLUE}  Name: ${SERVICE_NAME}${NC}"
echo -e "${BLUE}  Power: nano (0.25 vCPU, 512 MB)${NC}"
echo -e "${BLUE}  Scale: 1 node${NC}"
echo -e "${BLUE}  Cost: $7/month${NC}"
echo ""

aws lightsail create-container-service \
  --service-name ${SERVICE_NAME} \
  --power nano \
  --scale 1 \
  --region ${REGION}

echo -e "${GREEN}✓ Container service created!${NC}"
echo ""
echo -e "${BLUE}Waiting for service to become ready (this takes ~5-10 minutes)...${NC}"

# Wait for service to become ready
for i in {1..60}; do
  SERVICE_STATE=$(aws lightsail get-container-services --service-name ${SERVICE_NAME} --region ${REGION} --query 'containerServices[0].state' --output text 2>/dev/null || echo "UNKNOWN")

  if [ "$SERVICE_STATE" == "ACTIVE" ] || [ "$SERVICE_STATE" == "RUNNING" ] || [ "$SERVICE_STATE" == "READY" ]; then
    echo -e "${GREEN}✓ Service is ready! (State: ${SERVICE_STATE})${NC}"
    break
  fi

  echo -e "${BLUE}  Current state: ${SERVICE_STATE} (waiting...)${NC}"
  sleep 10
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Deploy your site: ${GREEN}make publish${NC}"
echo "  2. Wait 2-3 minutes for deployment"
echo "  3. Your site will be live at the Lightsail URL"
echo ""
echo -e "${BLUE}To set up custom domain (thmpaints.com):${NC}"
echo "  See LIGHTSAIL.md for instructions"
echo ""
echo -e "${YELLOW}Cost: $7/month (includes everything: hosting, SSL, load balancer)${NC}"
