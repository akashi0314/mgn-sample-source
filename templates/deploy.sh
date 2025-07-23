#!/bin/bash

# AWS Education Content - CloudFormation Stack Deployment Script
# This script deploys the stacks in the correct dependency order

PROJECT_NAME="aws-education"
REGION="us-east-1"

echo "=== AWS Education Content CloudFormation Deployment ==="
echo "Project: $PROJECT_NAME"
echo "Region: $REGION"
echo

# Function to wait for stack completion
wait_for_stack() {
    local stack_name=$1
    local action=$2
    
    echo "Waiting for stack $stack_name to complete $action..."
    aws cloudformation wait stack-${action}-complete \
        --stack-name $stack_name \
        --region $REGION
    
    if [ $? -eq 0 ]; then
        echo "✓ Stack $stack_name $action completed successfully"
    else
        echo "✗ Stack $stack_name $action failed"
        exit 1
    fi
}

# Deploy network stack
echo "1. Deploying network-stack..."
aws cloudformation deploy \
    --template-file network-stack.yaml \
    --stack-name ${PROJECT_NAME}-network-stack \
    --parameter-overrides ProjectName=$PROJECT_NAME \
    --region $REGION \
    --no-fail-on-empty-changeset

wait_for_stack "${PROJECT_NAME}-network-stack" "deploy"

# Deploy security stack
echo
echo "2. Deploying security-stack..."
aws cloudformation deploy \
    --template-file security-stack.yaml \
    --stack-name ${PROJECT_NAME}-security-stack \
    --parameter-overrides ProjectName=$PROJECT_NAME \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $REGION \
    --no-fail-on-empty-changeset

wait_for_stack "${PROJECT_NAME}-security-stack" "deploy"

# Deploy AP server stack
echo
echo "3. Deploying ap-server-stack..."
aws cloudformation deploy \
    --template-file ap-server-stack.yaml \
    --stack-name ${PROJECT_NAME}-ap-server-stack \
    --parameter-overrides ProjectName=$PROJECT_NAME \
    --region $REGION \
    --no-fail-on-empty-changeset

wait_for_stack "${PROJECT_NAME}-ap-server-stack" "deploy"

# Deploy DB server stack
echo
echo "4. Deploying db-server-stack..."
aws cloudformation deploy \
    --template-file db-server-stack.yaml \
    --stack-name ${PROJECT_NAME}-db-server-stack \
    --parameter-overrides ProjectName=$PROJECT_NAME \
    --region $REGION \
    --no-fail-on-empty-changeset

wait_for_stack "${PROJECT_NAME}-db-server-stack" "deploy"

echo
echo "=== Deployment Complete ==="
echo "Getting stack outputs..."

# Get important outputs
AP_SERVER_URL=$(aws cloudformation describe-stacks \
    --stack-name ${PROJECT_NAME}-ap-server-stack \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`APServerWebURL`].OutputValue' \
    --output text)

DB_SERVER_IP=$(aws cloudformation describe-stacks \
    --stack-name ${PROJECT_NAME}-db-server-stack \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`DBServerPrivateIP`].OutputValue' \
    --output text)

echo
echo "=== Access Information ==="
echo "AP Server Web URL: $AP_SERVER_URL"
echo "DB Server Private IP: $DB_SERVER_IP"
echo
echo "Note: The private DB server can only be accessed from the AP server."
echo "Use the AP server as a bastion host to connect to the DB server."
