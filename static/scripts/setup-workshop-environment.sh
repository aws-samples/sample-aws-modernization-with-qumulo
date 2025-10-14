#!/bin/bash

# Qumulo Workshop Environment Setup Script
set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}" >&2
}

# Function to get AWS region using IMDSv2
get_aws_region() {
    print_status "Detecting AWS region using IMDSv2..."
    
    # Get IMDSv2 token
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$TOKEN" ]; then
        # Use token to get region
        AWS_REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" \
            http://169.254.169.254/latest/meta-data/placement/region -s 2>/dev/null)
        
        if [ $? -eq 0 ] && [ -n "$AWS_REGION" ]; then
            print_status "Detected region: $AWS_REGION"
            echo "$AWS_REGION"
            return 0
        fi
    fi
    
    # Fallback to IMDSv1 for older instances
    print_warning "IMDSv2 failed, trying IMDSv1..."
    AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null)
    
    if [ -n "$AWS_REGION" ]; then
        print_status "Detected region (IMDSv1): $AWS_REGION"
        echo "$AWS_REGION"
        return 0
    fi
    
    # Final fallback
    print_error "Could not detect region, using default: us-east-2"
    echo "us-east-2"
    return 1
}

# Function to discover CloudFormation stack name
get_stack_name() {
    local region="$1"
    print_status "Discovering CloudFormation stack name..."
    
    # Get instance ID
    TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s 2>/dev/null)
    
    if [ -n "$TOKEN" ]; then
        INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" \
            http://169.254.169.254/latest/meta-data/instance-id -s 2>/dev/null)
    else
        INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)
    fi
    
    if [ -z "$INSTANCE_ID" ]; then
        print_error "Could not get instance ID"
        return 1
    fi
    
    print_status "Instance ID: $INSTANCE_ID"
    
    # Method 1: Check CloudFormation stack tag
    STACK_NAME=$(aws ec2 describe-instances \
        --instance-id "$INSTANCE_ID" \
        --query 'Reservations[*].Instances[*].Tags[?Key==`aws:cloudformation:stack-name`].Value' \
        --region "$region" \
        --output text 2>/dev/null)
    
    if [ -n "$STACK_NAME" ] && [ "$STACK_NAME" != "None" ]; then
        print_status "Found stack name from tags: $STACK_NAME"
        echo "$STACK_NAME"
        return 0
    fi
    
    # Method 2: CloudFormation resource lookup
    print_status "Trying CloudFormation resource lookup..."
    STACK_NAME=$(aws cloudformation describe-stack-resources \
        --physical-resource-id "$INSTANCE_ID" \
        --query 'StackResources[0].StackName' \
        --region "$region" \
        --output text 2>/dev/null)
    
    if [ -n "$STACK_NAME" ] && [ "$STACK_NAME" != "None" ]; then
        print_status "Found stack name from CloudFormation: $STACK_NAME"
        echo "$STACK_NAME"
        return 0
    fi
    
    # Method 3: Default fallback
    print_warning "Could not auto-detect stack name, using default: qumulo-workshop-base"
    echo "qumulo-workshop-base"
    return 1
}

# Function to get parameter from Parameter Store
get_parameter() {
    local param_name="$1"
    local region="$2"
    local value=$(aws ssm get-parameter --name "$param_name" --with-decryption --query Parameter.Value --output text --region "$region" 2>/dev/null)
    if [ $? -eq 0 ] && [ "$value" != "None" ] && [ -n "$value" ]; then
        echo "$value"
    else
        print_warning "Parameter $param_name not found or empty"
        echo ""
    fi
}

# Function to get Qumulo version from S3 bucket
get_qumulo_version() {
    local utility_bucket="$1"
    local region="$2"
    
    print_status "Retrieving Qumulo version from S3 bucket..."
    
    if [ -z "$utility_bucket" ]; then
        print_warning "Utility bucket not provided, skipping Qumulo version detection"
        echo ""
        return 1
    fi
    
    # List the qumulo-core-install directory to find version folders
    local version_list=$(aws s3 ls "s3://$utility_bucket/qumulo_installs/qumulo-core-install/" \
        --region "$region" 2>/dev/null | grep "PRE" | awk '{print $2}' | sed 's/\///')
    
    if [ $? -eq 0 ] && [ -n "$version_list" ]; then
        # Get the first (and typically only) version
        local qumulo_version=$(echo "$version_list" | head -1)
        
        if [ -n "$qumulo_version" ]; then
            print_status "Found Qumulo version: $qumulo_version"
            echo "$qumulo_version"
            return 0
        fi
    fi
    
    # Fallback if detection fails
    print_warning "Could not detect Qumulo version from S3"
    echo "FAILED"
    return 1
}


# Function to retrieve CloudFormation variables from Parameter Store
get_cloudformation_variables() {
    local stack_name="$1"
    local region="$2"
    
    print_status "Retrieving CloudFormation variables from Parameter Store..."
    
    # Test Parameter Store access first
    aws ssm get-parameter \
        --name "/${stack_name}/vpc-id" \
        --region "$region" \
        --query 'Parameter.Value' \
        --output text >/dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        print_error "Cannot access AWS SSM Parameter Store. Check IAM permissions."
        return 1
    fi
    
    print_status "Parameter Store access verified!"
    
    # Retrieve all parameters
    print_status "Fetching workshop variables..."
    
    VPC_ID=$(get_parameter "/${stack_name}/vpc-id" "$region")
    PRIVATE_SUBNET_A=$(get_parameter "/${stack_name}/private-subnet-a" "$region")
    PRIVATE_SUBNET_B=$(get_parameter "/${stack_name}/private-subnet-b" "$region")
    PRIVATE_SUBNET_C=$(get_parameter "/${stack_name}/private-subnet-c" "$region")
    AWS_REGION_PARAM=$(get_parameter "/${stack_name}/aws-region" "$region")
    WINDOWS_SECURITY_GROUP=$(get_parameter "/${stack_name}/windows-security-group" "$region")
    LINUX_SECURITY_GROUP=$(get_parameter "/${stack_name}/linux-security-group" "$region")
    UTILITY_BUCKET=$(get_parameter "/${stack_name}/utility-bucket-name" "$region")
    PRIVATE_KEY_ID=$(get_parameter "/${stack_name}/private-key-id" "$region")
    STACK_NAME_PARAM=$(get_parameter "/${stack_name}/stack-name" "$region")
    ACCOUNT_ID=$(get_parameter "/${stack_name}/account-id" "$region")
    QUMULO_PASSWD=$(get_parameter "/${stack_name}/qumulo-environment-password" "$region")
    PHZ_ZONE_ID=$(get_parameter "/${stack_name}/private-hosted-zone-id" "$region")
    LOAD_INSTANCE_1_ID=$(get_parameter "/${stack_name}/load-testing-instance-id-1" "$region")
    LOAD_INSTANCE_2_ID=$(get_parameter "/${stack_name}/load-testing-instance-id-2" "$region")
    LOAD_INSTANCE_3_ID=$(get_parameter "/${stack_name}/load-testing-instance-id-3" "$region")
    LOAD_INSTANCE_4_ID=$(get_parameter "/${stack_name}/load-testing-instance-id-4" "$region")
    LOAD_INSTANCE_5_ID=$(get_parameter "/${stack_name}/load-testing-instance-id-5" "$region")

    # Use region from parameter store if available, otherwise use detected region
    if [ -n "$AWS_REGION_PARAM" ]; then
        AWS_REGION="$AWS_REGION_PARAM"
    fi

    # Get Qumulo version from S3 bucket
    QUMULO_VERSION=$(get_qumulo_version "$UTILITY_BUCKET" "$AWS_REGION")
    
    # Display retrieved values
    print_status "Retrieved CloudFormation variables:"
    echo "  VPC ID: $VPC_ID" >&2
    echo "  Private Subnet A: $PRIVATE_SUBNET_A" >&2
    echo "  Private Subnet B: $PRIVATE_SUBNET_B" >&2
    echo "  Private Subnet C: $PRIVATE_SUBNET_C" >&2
    echo "  AWS Region: $AWS_REGION" >&2
    echo "  Windows Security Group: $WINDOWS_SECURITY_GROUP" >&2
    echo "  Linux Security Group: $LINUX_SECURITY_GROUP" >&2
    echo "  Utility Bucket: $UTILITY_BUCKET" >&2
    echo "  Private Key ID: $PRIVATE_KEY_ID" >&2
    echo "  Stack Name: $STACK_NAME_PARAM" >&2
    echo "  Account ID: $ACCOUNT_ID" >&2
    echo "  Qumulo Environment Password: $QUMULO_PASSWD" >&2
    echo "  Qumulo Version: $QUMULO_VERSION" >&2
    echo "  Private Hosted Zone ID: $PHZ_ZONE_ID" >&2
    echo "  Load Test Instance 1: $LOAD_INSTANCE_1_ID" >&2
    echo "  Load Test Instance 2: $LOAD_INSTANCE_2_ID" >&2
    echo "  Load Test Instance 3: $LOAD_INSTANCE_3_ID" >&2
    echo "  Load Test Instance 4: $LOAD_INSTANCE_4_ID" >&2
    echo "  Load Test Instance 5: $LOAD_INSTANCE_5_ID" >&2
    echo "" >&2
    
    return 0
}

# Function to retrieve and save private key
retrieve_private_key() {
    local private_key_id="$1"
    local region="$2"
    
    print_status "Retrieving SSH private key..."
    if [ -n "$private_key_id" ]; then
        PRIVATE_KEY_PARAM="/ec2/keypair/$private_key_id"
        print_status "Downloading private key from parameter: $PRIVATE_KEY_PARAM"

        if aws ssm get-parameter --name "$PRIVATE_KEY_PARAM" --with-decryption --query Parameter.Value --output text --region "$region" > /home/ssm-user/qumulo-workshop/qumulo-workshop-keypair.pem 2>/dev/null; then
            chmod 600 /home/ssm-user/qumulo-workshop/qumulo-workshop-keypair.pem
            print_status "Private key saved to: /home/ssm-user/qumulo-workshop/qumulo-workshop-keypair.pem"
            return 0
        else
            print_warning "Could not retrieve private key from Parameter Store"
            return 1
        fi
    else
        print_warning "Private Key ID not found in Parameter Store"
        return 1
    fi
}

# Function to create environment files
create_environment_files() {
    local stack_name="$1"
    local region="$2"
    
    print_status "Creating CloudFormation variables file..."
    
    # Create CloudFormation variables file (shell format)
    cat > /home/ssm-user/qumulo-workshop/cloudformation-variables.env << VARS_EOF
# CloudFormation Stack Variables for Qumulo Workshop
# Generated at $(date)
# Source: Parameter Store (/${stack_name}/*)

# Network Infrastructure
export VPCId="$VPC_ID"
export PrivateSubnetA="$PRIVATE_SUBNET_A"
export PrivateSubnetB="$PRIVATE_SUBNET_B"
export PrivateSubnetC="$PRIVATE_SUBNET_C"
export AWSRegion="$region"
export PrivateHostedZoneId="$PHZ_ZONE_ID"

# Security Groups
export WindowsSecurityGroup="$WINDOWS_SECURITY_GROUP"
export LinuxSecurityGroup="$LINUX_SECURITY_GROUP"

# Workshop Resources
export WorkshopUtilityBucket="$UTILITY_BUCKET"
export PrivateKeyID="$PRIVATE_KEY_ID"
export PrivateKeyFile="/home/ssm-user/qumulo-workshop/qumulo-workshop-keypair.pem"
export QumuloPassword="$QUMULO_PASSWD"
export QumuloVersion="$QUMULO_VERSION"
export LoadTestInstance1ID="$LOAD_INSTANCE_1_ID"
export LoadTestInstance2ID="$LOAD_INSTANCE_2_ID"
export LoadTestInstance3ID="$LOAD_INSTANCE_3_ID"
export LoadTestInstance4ID="$LOAD_INSTANCE_4_ID"
export LoadTestInstance5ID="$LOAD_INSTANCE_5_ID"

# Stack Information
export StackName="$STACK_NAME_PARAM"
export AccountId="$ACCOUNT_ID"

# Usage Instructions
echo "CloudFormation variables loaded automatically"
echo "Variables file: /home/ssm-user/qumulo-workshop/cloudformation-variables.env"
echo "Private key: /home/ssm-user/qumulo-workshop/qumulo-workshop-keypair.pem"
echo "Qumulo version: $QUMULO_VERSION"
VARS_EOF

    # Create JSON version for programmatic use
    print_status "Creating JSON variables file..."
    cat > /home/ssm-user/qumulo-workshop/cloudformation-variables.json << JSON_EOF
{
  "VPCId": "$VPC_ID",
  "PrivateSubnetA": "$PRIVATE_SUBNET_A",
  "PrivateSubnetB": "$PRIVATE_SUBNET_B",
  "PrivateSubnetC": "$PRIVATE_SUBNET_C",
  "AWSRegion": "$region",
  "WindowsSecurityGroup": "$WINDOWS_SECURITY_GROUP",
  "LinuxSecurityGroup": "$LINUX_SECURITY_GROUP",
  "WorkshopUtilityBucket": "$UTILITY_BUCKET",
  "PrivateKeyID": "$PRIVATE_KEY_ID",
  "PrivateKeyFile": "/home/ssm-user/qumulo-workshop/qumulo-workshop-keypair.pem",
  "StackName": "$STACK_NAME_PARAM",
  "AccountId": "$ACCOUNT_ID",
  "GeneratedAt": "$(date -Iseconds)",
  "QumuloPassword": "$QUMULO_PASSWD",
  "QumuloVersion": "$QUMULO_VERSION",
  "PrivateHostedZoneId": "$PHZ_ZONE_ID",
  "LoadTestInstance1ID": "$LOAD_INSTANCE_1_ID",
  "LoadTestInstance2ID": "$LOAD_INSTANCE_2_ID",
  "LoadTestInstance3ID": "$LOAD_INSTANCE_3_ID",
  "LoadTestInstance4ID": "$LOAD_INSTANCE_4_ID",
  "LoadTestInstance5ID": "$LOAD_INSTANCE_5_ID"
}
JSON_EOF

    print_status "Environment files created successfully!"
    return 0
}

# Configure ssm-user for workshop logging
configure_workshop_logging() {
    # Add ssm-user to log-related groups
    usermod -a -G adm,systemd-journal ssm-user
    
    # Grant passwordless sudo for workshop
    #echo "ssm-user ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/ssm-user
    #chmod 440 /etc/sudoers.d/ssm-user
    
    # Create workshop log directory
    mkdir -p /home/ssm-user/qumulo-workshop/logs
    chown -R ssm-user:ssm-user /home/ssm-user/qumulo-workshop/logs
    chmod 755 /home/ssm-user/qumulo-workshop/logs
    
    # Create convenience symlink
    ln -sf /home/ssm-user/qumulo-workshop/logs /var/log/workshop
    
    # Set initial /var/log permissions
    chmod 777 /var/log
    
    print_status "Workshop logging configured successfully"
}

# Function to install Qumulo API for ssm-user
install_qumulo_api() {
    print_status "Installing Qumulo API for ssm-user..."
    
    # Install Qumulo API in user space to avoid system conflicts
    if runuser -l ssm-user -c 'pip3 install --user qumulo-api'; then
        print_status "Qumulo API installed successfully"
        
        # Add user's local bin to PATH in bashrc if not already present
        if ! grep -q '/.local/bin' /home/ssm-user/.bashrc; then
            echo 'export PATH="/home/ssm-user/.local/bin:$PATH"' >> /home/ssm-user/.bashrc
            print_status "Added .local/bin to PATH in .bashrc"
        fi
        
        # Verify installation
        if runuser -l ssm-user -c 'export PATH="/home/ssm-user/.local/bin:$PATH" && qq --version' > /var/log/qumulo-user-install.log 2>&1; then
            print_status "Qumulo API (qq command) verification successful"
        else
            print_warning "qq command verification failed - check /var/log/qumulo-user-install.log"
        fi
        
        # Test AWS CLI still works
        if runuser -l ssm-user -c 'aws --version' > /var/log/aws-cli-verification.log 2>&1; then
            print_status "AWS CLI verification successful"
        else
            print_warning "AWS CLI verification failed - check /var/log/aws-cli-verification.log"
        fi
        
        return 0
    else
        print_error "Failed to install Qumulo API"
        return 1
    fi
}

# Main execution function
main() {
    print_header "Qumulo Workshop Environment Setup"
    
    # Step 1: Get AWS Region
    AWS_REGION=$(get_aws_region)
    if [ $? -ne 0 ]; then
        print_warning "Using fallback region: $AWS_REGION"
    fi
    
    # Step 2: Discover Stack Name
    STACK_NAME=$(get_stack_name "$AWS_REGION")
    if [ $? -ne 0 ]; then
        print_warning "Using fallback stack name: $STACK_NAME"
    fi
    
    # Step 3: Retrieve CloudFormation Variables
    if ! get_cloudformation_variables "$STACK_NAME" "$AWS_REGION"; then
        print_error "Failed to retrieve CloudFormation variables"
        exit 1
    fi
    
    # Step 4: Retrieve Private Key
    if ! retrieve_private_key "$PRIVATE_KEY_ID" "$AWS_REGION"; then
        print_warning "Private key retrieval failed, continuing without it"
    fi
    
    # Step 5: Create Environment Files
    if ! create_environment_files "$STACK_NAME" "$AWS_REGION"; then
        print_error "Failed to create environment files"
        exit 1
    fi
    
    # Step 6: Load variables into current session
    source /home/ssm-user/qumulo-workshop/cloudformation-variables.env
    
    print_header "Setup Complete!"
    print_status "Stack: $STACK_NAME"
    print_status "Region: $AWS_REGION"
    print_status "Variables loaded! Use 'source cloudformation-variables.env' to reload."
    print_status "Private key: $([ -f /home/ssm-user/qumulo-workshop/qumulo-workshop-keypair.pem ] && echo 'Available' || echo 'Not found')"

    # Step 7: create the workshop logging facility
    configure_workshop_logging

    # Step 8: Install Qumulo API for ssm-user
    if ! install_qumulo_api; then
        print_warning "Qumulo API installation failed, continuing without it"
    fi

    # Step 9: Make all scripts executable
    print_status "Making all scripts executable..."
    if [ -d /home/ssm-user/qumulo-workshop/scripts ]; then
        chmod +x /home/ssm-user/qumulo-workshop/scripts/*
        print_status "All scripts in /home/ssm-user/qumulo-workshop/scripts are now executable"
    fi
}

# Run main function
main "$@"
