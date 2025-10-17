#!/bin/bash

set -e

STACK_NAME=${STACK_NAME:-"sftp-server-fixed-ip"}
S3_BUCKET_NAME="s3-vir-sftp-bucket-fixed-ip-$(date +%s)"
AWS_PROFILE=${AWS_PROFILE:-""}
PROFILE_FLAG=""

if [ -n "$AWS_PROFILE" ]; then
    PROFILE_FLAG="--profile $AWS_PROFILE"
fi

# Prompt for endpoint type
echo "Select SFTP endpoint type:"
echo "1) PUBLIC - Internet-facing with AWS-managed IPs"
echo "2) VPC - VPC-based with static Elastic IP"
read -p "Enter choice (1 or 2): " ENDPOINT_CHOICE

if [ "$ENDPOINT_CHOICE" = "2" ]; then
    ENDPOINT_TYPE="VPC"
    
    # Get VPC ID
    read -p "Enter VPC ID: " VPC_ID
    
    # Get Subnet IDs
    read -p "Enter Subnet IDs (comma-separated): " SUBNET_IDS
    
    PARAMS="ParameterKey=S3BucketName,ParameterValue=$S3_BUCKET_NAME ParameterKey=EndpointType,ParameterValue=$ENDPOINT_TYPE ParameterKey=VpcId,ParameterValue=$VPC_ID ParameterKey=SubnetIds,ParameterValue=\"$SUBNET_IDS\""
else
    ENDPOINT_TYPE="PUBLIC"
    PARAMS="ParameterKey=S3BucketName,ParameterValue=$S3_BUCKET_NAME ParameterKey=EndpointType,ParameterValue=$ENDPOINT_TYPE"
fi

echo ""
echo "Deploying CloudFormation stack: $STACK_NAME"
echo "Endpoint Type: $ENDPOINT_TYPE"
echo "S3 Bucket: $S3_BUCKET_NAME"
echo ""

if ! aws cloudformation create-stack \
    --stack-name "$STACK_NAME" \
    --template-body file://sftp-server-template.yaml \
    --parameters $PARAMS \
    --capabilities CAPABILITY_IAM \
    $PROFILE_FLAG 2>&1; then
    echo "Error: Failed to create CloudFormation stack"
    exit 1
fi

echo "Stack creation initiated successfully"
echo "Waiting for stack to complete..."

if aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" $PROFILE_FLAG 2>&1; then
    echo "✅ Stack deployed successfully!"
    echo ""
    echo "SFTP Endpoint:"
    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --query "Stacks[0].Outputs[?OutputKey=='SftpServerEndpoint'].OutputValue" \
        --output text \
        $PROFILE_FLAG
    
    if [ "$ENDPOINT_TYPE" = "VPC" ]; then
        echo ""
        echo "Static IP Address:"
        aws cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --query "Stacks[0].Outputs[?OutputKey=='ElasticIP'].OutputValue" \
            --output text \
            $PROFILE_FLAG
    fi
else
    echo "Error: Stack creation failed or timed out"
    exit 1
fi
