#!/bin/bash

# Script to delete an SFTP user and optionally their S3 data
# Usage: ./delete-sftp-user.sh <username> [--delete-data]

set -e

USERNAME=$1
DELETE_DATA=$2

if [ -z "$USERNAME" ]; then
    echo "Usage: $0 <username> [--delete-data]"
    echo ""
    echo "Examples:"
    echo "  $0 john                    # Delete user but keep S3 data"
    echo "  $0 jane --delete-data      # Delete user and all S3 data"
    echo ""
    exit 1
fi

# Confirm deletion
echo "⚠️  WARNING: This will permanently delete the SFTP user '$USERNAME'"
if [ "$DELETE_DATA" = "--delete-data" ]; then
    echo "⚠️  WARNING: This will also delete ALL S3 data for this user"
fi
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Operation cancelled."
    exit 0
fi

# Delete the secret
echo "Deleting user secret..."
aws secretsmanager delete-secret \
    --secret-id "sftp/$USERNAME" \
    --force-delete-without-recovery

# Delete S3 data if requested
if [ "$DELETE_DATA" = "--delete-data" ]; then
    # Get stack name from user or use default
    read -p "Enter CloudFormation stack name (default: sftp-server): " STACK_NAME
    STACK_NAME=${STACK_NAME:-sftp-server}
    
    # Get S3 bucket name from CloudFormation output
    S3_BUCKET=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --query "Stacks[0].Outputs[?OutputKey=='S3BucketName'].OutputValue" \
        --output text)
    
    if [ ! -z "$S3_BUCKET" ]; then
        echo "Deleting S3 data for user..."
        aws s3 rm "s3://$S3_BUCKET/$USERNAME/" --recursive
        echo "S3 data deleted."
    else
        echo "Warning: Could not retrieve S3 bucket name, data not deleted."
    fi
fi

echo ""
echo "✅ SFTP user '$USERNAME' deleted successfully!"
