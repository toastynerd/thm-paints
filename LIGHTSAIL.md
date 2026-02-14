# AWS Lightsail Deployment Guide

This project is configured to deploy to **AWS Lightsail Container Service** for cost-effective hosting.

## Cost

**$7/month** for everything:
- Container hosting (0.25 vCPU, 512 MB RAM)
- Load balancer with SSL/TLS
- 500 GB data transfer
- Static IP
- No hidden costs

## Prerequisites

### 1. Install AWS CLI

```bash
brew install awscli
```

### 2. Install Lightsail Control Plugin

The `lightsailctl` plugin is required to push Docker images to Lightsail:

```bash
brew install aws/tap/lightsailctl
```

Verify it works:
```bash
lightsailctl --version
```

### 3. Configure AWS Credentials

You'll need an AWS account and IAM credentials:

1. Create an AWS account at https://aws.amazon.com
2. Create an IAM user with **AdministratorAccess** (or at minimum: `AmazonLightsailFullAccess`)
3. Generate access key and secret key for that user
4. Configure AWS CLI:

```bash
aws configure
# AWS Access Key ID: <your-key>
# AWS Secret Access Key: <your-secret>
# Default region name: us-west-2
# Default output format: json
```

Verify it works:
```bash
aws sts get-caller-identity
```

## Initial Setup

### Create the Lightsail Container Service

Run this **once** to create the service:

```bash
make setup
```

This will:
- Create a Lightsail container service named "thm-paints"
- Use the "nano" power tier (0.25 vCPU, 512 MB)
- Set scale to 1 node
- Cost: $7/month
- Wait for service to become active (~2-3 minutes)

## Deployment

### Deploy Your Site

After setup, deploy with:

```bash
make publish
```

This will:
1. Build your Docker image
2. Push it to Lightsail's container registry
3. Deploy to your container service
4. Wait for deployment to complete (~2-3 minutes)
5. Display your live site URL

### Local Testing

Before deploying, test locally:

```bash
make run
# Visit http://localhost:5000
```

Stop local container:
```bash
make stop
```

## Custom Domain Setup

By default, your site will be at a Lightsail URL like:
`https://thm-paints.xxxxxxxxxxxxx.us-west-2.cs.amazonlightsail.com`

To use **thmpaints.com**, follow these steps:

### Option 1: Using Lightsail DNS (Simplest)

1. **Create SSL certificate in Lightsail:**
   ```bash
   aws lightsail create-certificate \
     --certificate-name thm-paints-cert \
     --domain-name thmpaints.com \
     --subject-alternative-names www.thmpaints.com \
     --region us-west-2
   ```

2. **Validate certificate** by adding DNS records shown in output to your domain registrar

3. **Attach certificate to container service:**
   ```bash
   aws lightsail attach-certificate-to-distribution \
     --certificate-name thm-paints-cert \
     --region us-west-2
   ```

4. **Get Lightsail nameservers** (if you want to use Lightsail DNS zones):
   ```bash
   aws lightsail create-domain \
     --domain-name thmpaints.com \
     --region us-west-2
   ```

5. **Update domain registrar** to use Lightsail nameservers

6. **Create DNS records** pointing to your container service:
   ```bash
   # Get your container service URL first
   aws lightsail get-container-services \
     --service-name thm-paints \
     --region us-west-2 \
     --query 'containerServices[0].url' \
     --output text

   # Create A record for apex
   aws lightsail create-domain-entry \
     --domain-name thmpaints.com \
     --domain-entry name=@,type=A,target=<container-service-url> \
     --region us-west-2

   # Create A record for www
   aws lightsail create-domain-entry \
     --domain-name thmpaints.com \
     --domain-entry name=www,type=A,target=<container-service-url> \
     --region us-west-2
   ```

### Option 2: Using Existing DNS Provider (Route53, Namecheap, etc.)

1. **Get your Lightsail container service URL:**
   ```bash
   aws lightsail get-container-services \
     --service-name thm-paints \
     --region us-west-2 \
     --query 'containerServices[0].url' \
     --output text
   ```

2. **In your DNS provider**, create CNAME records:
   - `thmpaints.com` → CNAME → `<lightsail-url>` (or ALIAS if supported)
   - `www.thmpaints.com` → CNAME → `<lightsail-url>`

3. **Enable custom domain in Lightsail console:**
   - Go to: https://lightsail.aws.amazon.com/ls/webapp/home/containers
   - Click on your service
   - Go to "Custom domains" tab
   - Click "Create certificate"
   - Add your domains: `thmpaints.com` and `www.thmpaints.com`
   - Validate via DNS (add records shown)
   - Attach certificate when validated

## Ongoing Usage

### Regular Deployments

```bash
# Make changes to HTML/CSS/images
git add .
git commit -m "Update content"
make publish
```

### Check Service Status

```bash
aws lightsail get-container-services \
  --service-name thm-paints \
  --region us-west-2
```

### View Logs

```bash
aws lightsail get-container-log \
  --service-name thm-paints \
  --container-name thm-paints \
  --region us-west-2
```

### Get Service URL

```bash
aws lightsail get-container-services \
  --service-name thm-paints \
  --region us-west-2 \
  --query 'containerServices[0].url' \
  --output text
```

## Scaling & Upgrades

### Change Power Tier

If you need more resources:

```bash
# Micro: 0.5 vCPU, 1 GB - $10/month
aws lightsail update-container-service \
  --service-name thm-paints \
  --power micro \
  --region us-west-2

# Small: 1.0 vCPU, 2 GB - $20/month
aws lightsail update-container-service \
  --service-name thm-paints \
  --power small \
  --region us-west-2
```

### Increase Scale (Multiple Containers)

```bash
# Run 2 containers for high availability
aws lightsail update-container-service \
  --service-name thm-paints \
  --scale 2 \
  --region us-west-2

# Cost: $7 × 2 = $14/month
```

## Cleanup / Deletion

To delete the service and stop charges:

```bash
aws lightsail delete-container-service \
  --service-name thm-paints \
  --region us-west-2
```

**Warning:** This deletes everything. Your container images will be lost.

## Troubleshooting

### Deployment fails

Check service state:
```bash
aws lightsail get-container-services \
  --service-name thm-paints \
  --region us-west-2 \
  --query 'containerServices[0].state' \
  --output text
```

If not ACTIVE or RUNNING, wait a few minutes and try again.

### Site not loading

1. Check deployment completed:
   ```bash
   aws lightsail get-container-services \
     --service-name thm-paints \
     --region us-west-2 \
     --query 'containerServices[0].state'
   ```

2. Check container logs:
   ```bash
   aws lightsail get-container-log \
     --service-name thm-paints \
     --container-name thm-paints \
     --region us-west-2
   ```

3. Test the Lightsail URL directly (not custom domain) to isolate DNS issues

### Custom domain not working

1. Verify DNS records are correct:
   ```bash
   dig thmpaints.com
   dig www.thmpaints.com
   ```

2. Check certificate status in Lightsail console

3. DNS propagation can take 24-48 hours

### AWS CLI errors

Verify credentials:
```bash
aws sts get-caller-identity
```

Check region:
```bash
aws configure get region
# Should be: us-west-2
```

## File Structure

```
thm-paints/
├── lightsail/
│   ├── containers.json         # Container configuration
│   └── public-endpoint.json    # Load balancer configuration
├── scripts/
│   ├── setup.sh                # Initial service creation
│   └── deploy.sh               # Deployment script
├── Dockerfile                  # Container definition
├── Makefile                    # Commands: setup, publish, run, stop
└── LIGHTSAIL.md                # This file
```

## Additional Resources

- [Lightsail Container Services Documentation](https://docs.aws.amazon.com/lightsail/latest/userguide/amazon-lightsail-container-services.html)
- [Lightsail Pricing](https://aws.amazon.com/lightsail/pricing/)
- [AWS CLI Lightsail Commands](https://docs.aws.amazon.com/cli/latest/reference/lightsail/)

## Support

If you run into issues:
1. Check logs with `aws lightsail get-container-log`
2. Verify service state is ACTIVE/RUNNING
3. Test local Docker build with `make run`
4. Check AWS service health: https://status.aws.amazon.com/
