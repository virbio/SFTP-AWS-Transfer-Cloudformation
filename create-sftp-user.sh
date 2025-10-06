#!/bin/bash

# Script to create a new SFTP user with IP whitelisting
# Usage: ./create-sftp-user.sh <username> <password> <allowed-ips> [home-directory]

set -e

USERNAME=$1
PASSWORD=$2
ALLOWED_IPS=$3
HOME_DIRECTORY=${4:-"/$USERNAME"}

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ] || [ -z "$ALLOWED_IPS" ]; then
    echo "Usage: $0 <username> <password> <allowed-ips> [home-directory]"
    echo ""
    echo "Examples:"
    echo "  $0 john SecurePass123! \"192.168.1.0/24,10.0.0.1\""
    echo "  $0 jane AnotherPass456! \"203.0.113.5\" /custom-jane-home"
    echo ""
    echo "allowed-ips can be a single IP, CIDR range, or comma-separated list"
    exit 1
fi

# Get stack name from user or use default
read -p "Enter CloudFormation stack name (default: sftp-server): " STACK_NAME
STACK_NAME=${STACK_NAME:-sftp-server}

# Get S3 bucket name from CloudFormation output
S3_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query "Stacks[0].Outputs[?OutputKey=='S3BucketName'].OutputValue" \
    --output text 2>&1)

if [ $? -ne 0 ] || [ -z "$S3_BUCKET" ] || [ "$S3_BUCKET" = "None" ]; then
    echo "Error: Could not retrieve S3 bucket name from stack $STACK_NAME"
    echo "Make sure the stack exists and has completed deployment."
    exit 1
fi

# Get SFTP User Role ARN from CloudFormation stack
USER_ROLE_ARN=$(aws cloudformation describe-stack-resources \
    --stack-name "$STACK_NAME" \
    --logical-resource-id "SftpUserRole" \
    --query "StackResources[0].PhysicalResourceId" \
    --output text 2>&1)

if [ $? -ne 0 ] || [ -z "$USER_ROLE_ARN" ] || [ "$USER_ROLE_ARN" = "None" ]; then
    echo "Error: Could not retrieve SFTP User Role from stack $STACK_NAME"
    exit 1
fi

AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>&1)
if [ $? -ne 0 ] || [ -z "$AWS_ACCOUNT" ]; then
    echo "Error: Could not retrieve AWS account ID"
    exit 1
fi

FULL_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT}:role/$USER_ROLE_ARN"

# Convert comma-separated IPs to JSON array format
IFS=',' read -ra IP_ARRAY <<< "$ALLOWED_IPS"
JSON_IPS=()
for ip in "${IP_ARRAY[@]}"; do
    ip=$(echo "$ip" | xargs)
    [ -n "$ip" ] && JSON_IPS+=("\"$ip\"")
done
JSON_IPS=$(IFS=,; echo "${JSON_IPS[*]}")

# Create the secret JSON
SECRET_JSON=$(cat <<EOF
{
  "password": "$PASSWORD",
  "role_arn": "$FULL_ROLE_ARN",
  "home_directory": "$HOME_DIRECTORY",
  "allowed_ips": [$JSON_IPS],
  "home_directory_mappings": [
    {
      "Entry": "/",
      "Target": "/$S3_BUCKET/$USERNAME"
    }
  ]
}
EOF
)

echo "Creating secret for user: $USERNAME"
echo "Allowed IPs: $ALLOWED_IPS"
echo "Home directory: $HOME_DIRECTORY"
echo "S3 path: /$S3_BUCKET/$USERNAME"

# Create the secret in AWS Secrets Manager
if ! aws secretsmanager create-secret \
    --name "sftp/$USERNAME" \
    --description "SFTP credentials and configuration for $USERNAME" \
    --secret-string "$SECRET_JSON" 2>&1; then
    echo "Error: Failed to create secret for user $USERNAME"
    exit 1
fi

# Create the user's home directory in S3
echo "Creating S3 directory structure for user..."
if ! aws s3api put-object \
    --bucket "$S3_BUCKET" \
    --key "$USERNAME/" \
    --content-length 0 2>&1; then
    echo "Warning: Failed to create S3 directory (user secret created successfully)"
fi

echo ""
echo "✅ SFTP user '$USERNAME' created successfully!"
echo ""
echo "User details:"
echo "- Username: $USERNAME"
echo "- Allowed IPs: $ALLOWED_IPS"
echo "- Home directory: $HOME_DIRECTORY"
echo "- S3 location: s3://$S3_BUCKET/$USERNAME/"
echo ""
echo "The user can now connect to the SFTP server using:"
echo "sftp $USERNAME@$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='SftpServerEndpoint'].OutputValue" --output text)"
