#!/bin/bash
set -e

# Configuration
ENVIRONMENT=${1:-dev}
REGION=${2:-us-west-2}

echo "Deploying to environment: $ENVIRONMENT in region: $REGION"

# Check if required tools are installed
command -v terraform >/dev/null 2>&1 || { echo "Terraform is required but not installed. Aborting." >&2; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required but not installed. Aborting." >&2; exit 1; }

# Navigate to terraform directory
cd "$(dirname "$0")/../terraform"

# Install Python dependencies for Lambda functions
echo "Installing dependencies..."

# Lambda layer
mkdir -p dist
cd src/lambda_layer/python
pip install -r requirements.txt -t .
cd ../../..
zip -r dist/lambda_layer.zip src/lambda_layer/python

# Authorizer Lambda
cd src/authorizer
pip install -r requirements.txt -t .
cd ../..
zip -r dist/authorizer.zip src/authorizer

# Router Lambda
cd src/router
pip install -r requirements.txt -t .
cd ../..
zip -r dist/router.zip src/router

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Select workspace if it exists, create if it doesn't
if terraform workspace select $ENVIRONMENT 2>/dev/null; then
    echo "Switched to workspace: $ENVIRONMENT"
else
    terraform workspace new $ENVIRONMENT
    echo "Created and switched to workspace: $ENVIRONMENT"
fi

# Plan
echo "Planning deployment..."
terraform plan -var-file="$ENVIRONMENT.tfvars" -out=tfplan

# Apply
echo "Applying changes..."
terraform apply tfplan

# Get outputs
echo "Deployment complete. API Gateway URL:"
terraform output api_endpoint

echo "Done!"