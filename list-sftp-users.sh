#!/bin/bash

# Script to list all SFTP users and their configurations
# Usage: ./list-sftp-users.sh

set -e

echo "Listing all SFTP users..."
echo "========================="

# List all secrets with the sftp/ prefix
SECRETS=$(aws secretsmanager list-secrets \
    --filters Key=name,Values=sftp/ \
    --query "SecretList[].Name" \
    --output text)

if [ -z "$SECRETS" ]; then
    echo "No SFTP users found."
    exit 0
fi

for SECRET_NAME in $SECRETS; do
    USERNAME=$(echo "$SECRET_NAME" | sed 's/sftp\///')
    
    echo ""
    echo "User: $USERNAME"
    echo "---------------"
    
    # Get secret details
    SECRET_VALUE=$(aws secretsmanager get-secret-value \
        --secret-id "$SECRET_NAME" \
        --query "SecretString" \
        --output text)
    
    if [ ! -z "$SECRET_VALUE" ]; then
        echo "Allowed IPs: $(echo "$SECRET_VALUE" | jq -r '.allowed_ips | join(", ")')"
        echo "Home Directory: $(echo "$SECRET_VALUE" | jq -r '.home_directory')"
        echo "S3 Target: $(echo "$SECRET_VALUE" | jq -r '.home_directory_mappings[0].Target')"
    else
        echo "Error retrieving configuration"
    fi
done

echo ""
echo "========================="
echo "Total users: $(echo "$SECRETS" | wc -w)"
