#!/bin/bash

# AWS Education Content - SAM Stack Deployment Script
# This script deploys the stacks using SAM CLI in the correct dependency order

PROJECT_NAME="aws-education"
REGION="us-east-1"

echo "=== AWS Education Content SAM Deployment ==="
echo "Project: $PROJECT_NAME"
echo "Region: $REGION"
echo

# Debug: Show current AWS account and user information
echo "=== AWS Account Debug Information ==="
echo "Getting current AWS account information..."

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "AWS Account ID: $AWS_ACCOUNT_ID"
else
    echo "ERROR: Unable to get AWS Account ID. Please check your AWS credentials."
    exit 1
fi

# Get current AWS user/role ARN
AWS_USER_ARN=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "AWS User/Role ARN: $AWS_USER_ARN"
else
    echo "WARNING: Unable to get AWS User/Role ARN"
fi

# Get current AWS region
CURRENT_REGION=$(aws configure get region 2>/dev/null)
if [ ! -z "$CURRENT_REGION" ]; then
    echo "Configured AWS Region: $CURRENT_REGION"
    if [ "$CURRENT_REGION" != "$REGION" ]; then
        echo "WARNING: Configured region ($CURRENT_REGION) differs from deployment region ($REGION)"
    fi
else
    echo "No default region configured, using deployment region: $REGION"
fi

echo "=========================================="
echo

# Confirmation prompt
read -p "Do you want to proceed with deployment to Account ID: $AWS_ACCOUNT_ID? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

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
