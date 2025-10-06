#!/bin/bash

set -e

STACK_NAME="sftp-server"
S3_BUCKET_NAME="my-sftp-bucket-unique-name"

echo "Deploying CloudFormation stack: $STACK_NAME"
echo "S3 Bucket: $S3_BUCKET_NAME"
echo ""

if ! aws cloudformation create-stack \
    --stack-name "$STACK_NAME" \
    --template-body file://sftp-server-template.yaml \
    --parameters ParameterKey=S3BucketName,ParameterValue="$S3_BUCKET_NAME" \
    --capabilities CAPABILITY_IAM 2>&1; then
    echo "Error: Failed to create CloudFormation stack"
    exit 1
fi

echo "Stack creation initiated successfully"
echo "Waiting for stack to complete..."

if aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" 2>&1; then
    echo "✅ Stack deployed successfully!"
    echo ""
    echo "SFTP Endpoint:"
    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --query "Stacks[0].Outputs[?OutputKey=='SftpServerEndpoint'].OutputValue" \
        --output text
else
    echo "Error: Stack creation failed or timed out"
    exit 1
fi
