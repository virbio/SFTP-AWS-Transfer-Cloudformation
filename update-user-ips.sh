#!/bin/bash

# Script to update IP whitelist for an existing SFTP user
# Usage: ./update-user-ips.sh <username> <new-allowed-ips>

set -e

USERNAME=$1
NEW_ALLOWED_IPS=$2

if [ -z "$USERNAME" ] || [ -z "$NEW_ALLOWED_IPS" ]; then
    echo "Usage: $0 <username> <new-allowed-ips>"
    echo ""
    echo "Examples:"
    echo "  $0 john \"192.168.1.0/24,10.0.0.1,203.0.113.5\""
    echo "  $0 jane \"0.0.0.0/0\"  # Allow from any IP (not recommended)"
    echo ""
    exit 1
fi

# Get current secret
echo "Retrieving current configuration for user: $USERNAME"
CURRENT_SECRET=$(aws secretsmanager get-secret-value \
    --secret-id "sftp/$USERNAME" \
    --query "SecretString" \
    --output text)

if [ -z "$CURRENT_SECRET" ]; then
    echo "Error: User $USERNAME not found in secrets manager"
    exit 1
fi

# Parse current secret and update allowed_ips
echo "Updating allowed IPs..."

# Convert comma-separated IPs to JSON array format
IFS=',' read -ra IP_ARRAY <<< "$NEW_ALLOWED_IPS"
JSON_IPS=""
for ip in "${IP_ARRAY[@]}"; do
    # Trim whitespace
    ip=$(echo "$ip" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -z "$JSON_IPS" ]; then
        JSON_IPS="\"$ip\""
    else
        JSON_IPS="$JSON_IPS, \"$ip\""
    fi
done

# Update the secret with new allowed IPs
UPDATED_SECRET=$(echo "$CURRENT_SECRET" | jq --argjson new_ips "[$JSON_IPS]" '.allowed_ips = $new_ips')

# Update the secret in AWS
aws secretsmanager update-secret \
    --secret-id "sftp/$USERNAME" \
    --secret-string "$UPDATED_SECRET"

echo ""
echo "✅ IP whitelist updated successfully for user '$USERNAME'"
echo "New allowed IPs: $NEW_ALLOWED_IPS"
