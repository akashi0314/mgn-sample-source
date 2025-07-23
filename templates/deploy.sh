#!/bin/bash

# AWS Education Content - SAM Stack Deployment Script
# This script deploys the stacks using SAM CLI in the correct dependency order

PROJECT_NAME="aws-education"
REGION="us-east-1"

echo "=== AWS Education Content SAM Deployment ==="
echo "Project: $PROJECT_NAME"
echo "Region: $REGION"
echo

# Deploy network stack
echo "1. Deploying network-stack..."
sam deploy \
    --template-file network-stack.yaml \
    --stack-name ${PROJECT_NAME}-network-stack \
    --parameter-overrides ProjectName=$PROJECT_NAME \
    --region $REGION \
    --no-fail-on-empty-changeset \
    --no-confirm-changeset

# Deploy security stack
echo
echo "2. Deploying security-stack..."
sam deploy \
    --template-file security-stack.yaml \
    --stack-name ${PROJECT_NAME}-security-stack \
    --parameter-overrides ProjectName=$PROJECT_NAME \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION \
    --no-fail-on-empty-changeset \
    --no-confirm-changeset

# Deploy AP server stack
echo
echo "3. Deploying ap-server-stack..."
sam deploy \
    --template-file ap-server-stack.yaml \
    --stack-name ${PROJECT_NAME}-ap-server-stack \
    --parameter-overrides ProjectName=$PROJECT_NAME \
    --region $REGION \
    --no-fail-on-empty-changeset \
    --no-confirm-changeset

# Deploy DB server stack
echo
echo "4. Deploying db-server-stack..."
sam deploy \
    --template-file db-server-stack.yaml \
    --stack-name ${PROJECT_NAME}-db-server-stack \
    --parameter-overrides ProjectName=$PROJECT_NAME \
    --region $REGION \
    --no-fail-on-empty-changeset \
    --no-confirm-changeset

echo
echo "=== Deployment Complete ==="
echo "Getting stack outputs..."

# Get important outputs
AP_SERVER_URL=$(aws cloudformation describe-stacks \
    --stack-name ${PROJECT_NAME}-ap-server-stack \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`APServerWebURL`].OutputValue' \
    --output text)

AP_SERVER_DNS=$(aws cloudformation describe-stacks \
    --stack-name ${PROJECT_NAME}-ap-server-stack \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`APServerPublicDNS`].OutputValue' \
    --output text)

DB_SERVER_IP=$(aws cloudformation describe-stacks \
    --stack-name ${PROJECT_NAME}-db-server-stack \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`DBServerPrivateIP`].OutputValue' \
    --output text)

echo
echo "=== Access Information ==="
echo "AP Server Web URL: $AP_SERVER_URL"
echo "AP Server Public DNS: $AP_SERVER_DNS"
echo "DB Server Private IP: $DB_SERVER_IP"
echo
echo "Note: The private DB server can only be accessed from the AP server."
echo "Use the AP server as a bastion host to connect to the DB server."
