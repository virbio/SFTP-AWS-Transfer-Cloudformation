# SFTP Server with IP Whitelisting and AWS Secrets Manager

This CloudFormation template creates an AWS Transfer Family SFTP server with the following features:

- **IP Whitelisting**: Each user can have specific IP addresses or CIDR ranges that are allowed to connect
- **AWS Secrets Manager Integration**: User credentials and configurations are stored securely in AWS Secrets Manager
- **Custom Authentication**: Lambda function handles authentication and IP validation
- **S3 Backend**: User files are stored in S3 with proper isolation

## Architecture

The solution consists of:

1. **AWS Transfer Family SFTP Server**: The main SFTP endpoint
2. **Lambda Authentication Function**: Custom authentication with IP checking
3. **AWS Secrets Manager**: Secure storage for user credentials and configuration
4. **S3 Bucket**: Backend storage for user files
5. **IAM Roles**: Proper permissions for all components

## Prerequisites

- AWS CLI configured with appropriate permissions
- `jq` command-line tool (for user management scripts)
- Unique S3 bucket name (must be globally unique)

## Deployment

1. **Clone or download this repository**

2. **Make scripts executable**:
   ```bash
   chmod +x *.sh
   ```

3. **Deploy the CloudFormation stack**:
   ```bash
   # Edit the S3 bucket name to be globally unique
   aws cloudformation create-stack \
       --stack-name sftp-server \
       --template-body file://sftp-server-template.yaml \
       --parameters ParameterKey=S3BucketName,ParameterValue=your-unique-bucket-name \
       --capabilities CAPABILITY_IAM
   ```

   Or use the provided script:
   ```bash
   # Edit deploy.sh to use your unique bucket name first
   ./deploy.sh
   ```

4. **Wait for deployment to complete**:
   ```bash
   aws cloudformation wait stack-create-complete --stack-name sftp-server
   ```

5. **Get the SFTP server endpoint**:
   ```bash
   aws cloudformation describe-stacks \
       --stack-name sftp-server \
       --query "Stacks[0].Outputs[?OutputKey=='SftpServerEndpoint'].OutputValue" \
       --output text
   ```

## User Management

### Create a New User

Use the provided script to create a new SFTP user:

```bash
./create-sftp-user.sh <username> <password> <allowed-ips> [home-directory]
```

Examples:
```bash
# Single IP address
./create-sftp-user.sh john SecurePass123! "192.168.1.100"

# CIDR range
./create-sftp-user.sh jane AnotherPass456! "192.168.1.0/24"

# Multiple IPs and ranges
./create-sftp-user.sh bob ComplexPass789! "192.168.1.0/24,10.0.0.1,203.0.113.5"

# Custom home directory
./create-sftp-user.sh alice MyPass321! "0.0.0.0/0" "/custom-alice-home"
```

### List All Users

```bash
./list-sftp-users.sh
```

### Update User IP Whitelist

```bash
./update-user-ips.sh <username> <new-allowed-ips>
```

Example:
```bash
./update-user-ips.sh john "192.168.1.0/24,10.0.0.0/8"
```

### Delete a User

```bash
# Delete user but keep S3 data
./delete-sftp-user.sh john

# Delete user and all S3 data
./delete-sftp-user.sh jane --delete-data
```

## Manual User Creation

You can also create users manually by adding secrets to AWS Secrets Manager:

1. **Create a secret with the name pattern**: `sftp/<username>`

2. **Secret value should be JSON**:
   ```json
   {
     "password": "your-secure-password",
     "role_arn": "arn:aws:iam::ACCOUNT:role/STACK-SftpUserRole-XXXX",
     "home_directory": "/username",
     "allowed_ips": ["192.168.1.0/24", "10.0.0.1", "203.0.113.0/24"],
     "home_directory_mappings": [
       {
         "Entry": "/",
         "Target": "/your-s3-bucket/username"
       }
     ]
   }
   ```

## IP Whitelisting Format

The `allowed_ips` field supports:

- **Single IP addresses**: `"192.168.1.100"`
- **CIDR ranges**: `"192.168.1.0/24"`
- **Multiple entries**: `["192.168.1.0/24", "10.0.0.1", "203.0.113.5"]`
- **Allow all IPs**: `["0.0.0.0/0"]` (not recommended for production)

## Connecting to the SFTP Server

Once a user is created, they can connect using any SFTP client:

```bash
# Command line SFTP
sftp username@your-server-id.server.transfer.region.amazonaws.com

# Using specific port (default is 22)
sftp -P 22 username@your-server-id.server.transfer.region.amazonaws.com
```

Popular SFTP clients:
- **Command line**: `sftp`, `scp`
- **GUI clients**: FileZilla, WinSCP, Cyberduck
- **Programming**: Paramiko (Python), ssh2 (Node.js)

## Security Considerations

1. **Strong Passwords**: Use complex passwords for all SFTP users
2. **IP Restrictions**: Always specify the most restrictive IP ranges possible
3. **Regular Auditing**: Periodically review user access and IP whitelists
4. **Secrets Rotation**: Regularly rotate passwords in Secrets Manager
5. **Monitoring**: Enable CloudTrail logging for API calls
6. **S3 Bucket Policy**: Consider additional S3 bucket policies for enhanced security

## Monitoring and Logging

The SFTP server logs are stored in CloudWatch Logs under the log group `/aws/transfer/sftp-server`.

Monitor:
- Authentication attempts and failures
- File transfer activities
- IP address violations
- Lambda function errors

## Costs

This solution incurs costs for:
- AWS Transfer Family (per hour + per GB transferred)
- Lambda function invocations
- S3 storage and requests
- Secrets Manager secret storage
- CloudWatch Logs storage

## Troubleshooting

### Authentication Failures

1. Check CloudWatch Logs for the Lambda function
2. Verify the secret exists: `aws secretsmanager get-secret-value --secret-id sftp/username`
3. Verify IP is in allowed list
4. Check password is correct

### Connection Issues

1. Verify security groups allow SFTP traffic (port 22)
2. Check that the source IP is whitelisted
3. Ensure the SFTP server is in "ONLINE" state

### Permission Issues

1. Verify IAM roles have correct S3 permissions
2. Check S3 bucket policy doesn't conflict
3. Ensure home directory mappings are correct

## Customization

You can customize the template by:

1. **Adding more IAM policies** for specific S3 access patterns
2. **Modifying the Lambda function** for additional authentication logic
3. **Adding CloudWatch alarms** for monitoring
4. **Implementing logging to external systems**
5. **Adding VPC endpoints** for private connectivity

## Clean Up

To remove all resources:

```bash
# Delete all users first (optional - keep data)
./list-sftp-users.sh  # Get list of users
./delete-sftp-user.sh username  # Repeat for each user

# Delete the CloudFormation stack
aws cloudformation delete-stack --stack-name sftp-server

# If you want to keep the S3 data, back it up before deletion
aws s3 sync s3://your-bucket-name/ ./backup/
```

## Support

For issues or feature requests, please check:
1. AWS Transfer Family documentation
2. AWS Lambda documentation for Python
3. AWS Secrets Manager documentation
4. CloudFormation documentation