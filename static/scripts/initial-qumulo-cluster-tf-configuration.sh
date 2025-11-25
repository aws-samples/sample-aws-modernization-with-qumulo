#!/bin/bash

# Qumulo Workshop - Initial Cluster Deployment Script
# This script prepares Terraform configurations for a new Qumulo cluster deployment

# MIT No Attribution

# Copyright Amazon.com, Inc., Qumulo or its affiliates. All Rights Reserved.

# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_header() {
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Configuration
WORKSHOP_DIR="/home/ssm-user/qumulo-workshop"
TEMPLATE_DIR="${WORKSHOP_DIR}/terraform"
DEPLOYMENT_NAME="terraform_deployment_primary_saz"
DEPLOYMENT_DIR="${WORKSHOP_DIR}/${DEPLOYMENT_NAME}"
VARIABLES_FILE="${WORKSHOP_DIR}/cloudformation-variables.json"

load_variables() {
    log_step "Loading CloudFormation variables from JSON file"
    
    if [ ! -f "$VARIABLES_FILE" ]; then
        log_error "Variables file not found: $VARIABLES_FILE"
        return 1
    fi
    
    # Extract variables from JSON file
    AWS_REGION=$(jq -r '.AWSRegion' "$VARIABLES_FILE")
    VPC_ID=$(jq -r '.VPCId' "$VARIABLES_FILE")
    PRIVATE_KEY_ID=$(jq -r '.PrivateKeyID' "$VARIABLES_FILE")
    PRIVATE_SUBNET_A=$(jq -r '.PrivateSubnetA' "$VARIABLES_FILE")
    PRIVATE_SUBNET_B=$(jq -r '.PrivateSubnetB' "$VARIABLES_FILE")
    PRIVATE_SUBNET_C=$(jq -r '.PrivateSubnetC' "$VARIABLES_FILE")
    WORKSHOP_UTILITY_BUCKET=$(jq -r '.WorkshopUtilityBucket' "$VARIABLES_FILE")
    WORKSHOP_PASSWORD=$(jq -r '.QumuloPassword' "$VARIABLES_FILE")
    QUMULO_VERSION=$(jq -r '.QumuloVersion' "$VARIABLES_FILE")

    # Lookup Private Key Name from ID with AWS CLI

    KEY_NAME=$(aws ec2 describe-key-pairs --key-pair-ids "$PRIVATE_KEY_ID" --region "$AWS_REGION" --query 'KeyPairs[0].KeyName' --output text)


    # Randomly select one of the three private subnets
    SUBNETS=("$PRIVATE_SUBNET_A" "$PRIVATE_SUBNET_B" "$PRIVATE_SUBNET_C")
    RANDOM_INDEX=$((RANDOM % 3))
    SELECTED_SUBNET=${SUBNETS[$RANDOM_INDEX]}
    
    log_info "Loaded variables:"
    log_info "  AWS Region: $AWS_REGION"
    log_info "  VPC ID: $VPC_ID"
    log_info "  Private Key ID: $PRIVATE_KEY_ID"
    log_info "  Available Subnets: A=$PRIVATE_SUBNET_A, B=$PRIVATE_SUBNET_B, C=$PRIVATE_SUBNET_C"
    log_info "  Randomly Selected Subnet: $SELECTED_SUBNET (Index: $RANDOM_INDEX)"
    log_info "  Workshop Utility Bucket: $WORKSHOP_UTILITY_BUCKET"
    log_info "  Workshop Password: $WORKSHOP_PASSWORD"
    
    return 0
}

# Function to copy template files
copy_template_files() {
    log_step "Copying template files to deployment directory"
    
    if [ ! -d "$TEMPLATE_DIR" ]; then
        log_error "Template directory not found: $TEMPLATE_DIR"
        return 1
    fi
    
    # Remove existing deployment directory if it exists
    if [ -d "$DEPLOYMENT_DIR" ]; then
        log_warning "Deployment directory exists, removing: $DEPLOYMENT_DIR"
        rm -rf "$DEPLOYMENT_DIR"
    fi
    
    # Copy template files
    cp -r "$TEMPLATE_DIR" "$DEPLOYMENT_DIR"
    log_info "Template files copied to: $DEPLOYMENT_DIR"
    
    # List contents for verification
    log_info "Deployment directory structure:"
    find "$DEPLOYMENT_DIR" -type f -name "*.tf" -o -name "*.tfvars" | head -10
    
    return 0
}

# Function to configure persistent storage provider.tf
configure_persistent_storage_providers() {
    log_step "Configuring persistent storage provider.tf"
    
    local providers_file="${DEPLOYMENT_DIR}/persistent-storage/provider.tf"
    
    if [ ! -f "$providers_file" ]; then
        log_error "Providers file not found: $providers_file"
        return 1
    fi
    
    # Create backup
    cp "$providers_file" "${providers_file}.backup"
    log_info "Created backup: ${providers_file}.backup"
    
    # Comment out the S3 backend terraform block
    # Find the terraform block that starts after "# Comment out this block if you want to use a local backend"
    # sed -i '/# Comment out this block if you want to use a local backend/,/^}$/{
    #     s/^terraform {/#terraform {/
    #     s/^  backend/#  backend/
    #     s/^    bucket/#    bucket/
    #     s/^    key/#    key/
    #     s/^    region/#    region/
    #     s/^    use_lockfile/#    use_lockfile/
    #     s/^    workspace_key_prefix/#    workspace_key_prefix/
    #     s/^  }/#  }/
    #     s/^}$/#}/
    # }' "$providers_file"

    sed -i '/# Comment out this block if you want to use a local backend/,/^}$/{
        s/^terraform[[:space:]]*{/#terraform {/
        s/^[[:space:]]*backend/#  backend/
        s/^[[:space:]]*bucket/#    bucket/
        s/^[[:space:]]*key/#    key/
        s/^[[:space:]]*region/#    region/
        s/^[[:space:]]*use_lockfile/#    use_lockfile/
        s/^[[:space:]]*workspace_key_prefix/#    workspace_key_prefix/
        s/^[[:space:]]*}/#  }/
        s/^}$/#}/
    }' "$providers_file"
    
    log_info "Commented out S3 backend block in persistent storage provider.tf"
    
    return 0
}

configure_root_providers() {
    log_step "Configuring root provider.tf"

    local providers_file="${DEPLOYMENT_DIR}/provider.tf"

    if [ ! -f "$providers_file" ]; then
        log_error "Root providers file not found: $providers_file"
        return 1
    fi

    # Create backup
    cp "$providers_file" "${providers_file}.backup"
    log_info "Created backup: ${providers_file}.backup"

    # Comment out the S3 backend terraform block
    sed -i '/# Comment out this block if you want to use a local backend/,/^}$/{
        s/^[[:space:]]*terraform[[:space:]]*{/#terraform {/
        s/^[[:space:]]*backend/#  backend/
        s/^[[:space:]]*bucket/#    bucket/
        s/^[[:space:]]*key/#    key/
        s/^[[:space:]]*region/#    region/
        s/^[[:space:]]*use_lockfile/#    use_lockfile/
        s/^[[:space:]]*workspace_key_prefix/#    workspace_key_prefix/
        s/^[[:space:]]*}/#  }/
        s/^}$/#}/
    }' "$providers_file"

    # Comment out the S3 remote state data block
    sed -i '/^#Comment out this block if you are using a local backend/,/^}$/{
        s/^data[[:space:]]*/#data/
        s/^[[:space:]]*backend/#  backend/
        s/^[[:space:]]*config/#  config/
        s/^[[:space:]]*bucket/#    bucket/
        s/^[[:space:]]*key/#    key/
        s/^[[:space:]]*region/#    region/
        s/^[[:space:]]*workspace_key_prefix/#    workspace_key_prefix/
        s/^[[:space:]]*}/#  }/
        s/^}$/#}/
        s/^[[:space:]]*workspace[[:space:]]*=/#    workspace =/
    }' "$providers_file"

    # Uncomment the local backend data block
    sed -i '/^#Uncomment this block if you are using a local backend/,/^#}$/{
        s/^#data "terraform_remote_state" "persistent_storage" {/data "terraform_remote_state" "persistent_storage" {/
        s/^#[[:space:]]*backend = "local"/  backend = "local"/
        s/^#$/\n/
        s/^#[[:space:]]*config = {/  config = {/
        s/^#[[:space:]]*path = "\.\/persistent-storage\/terraform\.tfstate"/    path = ".\/persistent-storage\/terraform.tfstate"/
        s/^#[[:space:]]*}/  }/
        s/^#}$/}/
    }' "$providers_file"

    log_info "Configured root provider.tf for local backend"

    return 0
}


# Function to configure persistent storage terraform.tfvars
configure_persistent_storage_tfvars() {
    log_step "Configuring persistent storage terraform.tfvars"
    
    local tfvars_file="${DEPLOYMENT_DIR}/persistent-storage/terraform.tfvars"
    
    if [ ! -f "$tfvars_file" ]; then
        log_error "Persistent storage tfvars file not found: $tfvars_file"
        return 1
    fi

    # Get the Private Key ID from the variabls file:


    
    # Create backup
    cp "$tfvars_file" "${tfvars_file}.backup"
    log_info "Created backup: ${tfvars_file}.backup"
    
    # Update specific values while preserving file structure
    sed -i "s/^deployment_name[[:space:]]*=.*/deployment_name = \"qum-wks-cls-pri-str\"/" "$tfvars_file"
    sed -i "s/^aws_region[[:space:]]*=.*/aws_region = \"$AWS_REGION\"/" "$tfvars_file"
    sed -i "s/^prevent_destroy[[:space:]]*=.*/prevent_destroy = false/" "$tfvars_file"
    
    # Replace the tags section
    sed -i "s/^tags[[:space:]]*=.*/tags = { \"department\" = \"se\", \"owner\" = \"awsworkshop\", \"purpose\" = \"aws-workshop\", \"long_running\" = \"false\" }/" "$tfvars_file"
    
    log_info "Updated persistent storage terraform.tfvars"
    
    return 0
}


# Function to create root terraform.tfvars from config-standard.tfvars
configure_root_tfvars() {
    log_step "Creating root terraform.tfvars from config-standard.tfvars"
    
    local source_file="${DEPLOYMENT_DIR}/config-standard.tfvars"
    local tfvars_file="${DEPLOYMENT_DIR}/terraform.tfvars"
    
    if [ ! -f "$source_file" ]; then
        log_error "Source tfvars file not found: $source_file"
        return 1
    fi
    
    # Copy config-standard.tfvars to terraform.tfvars
    cp "$source_file" "$tfvars_file"
    log_info "Copied config-standard.tfvars to terraform.tfvars"
    
    # Update specific values while preserving file structure and comments
    sed -i "s/^deployment_name[[:space:]]*=.*/deployment_name = \"qum-wks-cls-pri\"/" "$tfvars_file"
    
    sed -i "s/^s3_bucket_name[[:space:]]*=.*/s3_bucket_name = \"$WORKSHOP_UTILITY_BUCKET\"/" "$tfvars_file"
    sed -i "s/^s3_bucket_prefix[[:space:]]*=.*/s3_bucket_prefix = \"qumulo_installs\/\"/" "$tfvars_file"
    sed -i "s/^s3_bucket_region[[:space:]]*=.*/s3_bucket_region = \"$AWS_REGION\"/" "$tfvars_file"
    
    sed -i "s/^aws_region[[:space:]]*=.*/aws_region = \"$AWS_REGION\"/" "$tfvars_file"
    sed -i "s/^aws_vpc_id[[:space:]]*=.*/aws_vpc_id = \"$VPC_ID\"/" "$tfvars_file"
    sed -i "s/^ec2_key_pair[[:space:]]*=.*/ec2_key_pair = \"$KEY_NAME\"/" "$tfvars_file"
    sed -i "s/^private_subnet_id[[:space:]]*=.*/private_subnet_id = \"$SELECTED_SUBNET\"/" "$tfvars_file"
    sed -i "s/^term_protection[[:space:]]*=.*/term_protection = false/" "$tfvars_file"
    
    sed -i "s/^q_cluster_admin_password[[:space:]]*=.*/q_cluster_admin_password = \"$WORKSHOP_PASSWORD\"/" "$tfvars_file"
    sed -i "s/^q_cluster_name[[:space:]]*=.*/q_cluster_name = \"demopri\"/" "$tfvars_file"
    sed -i "s/^q_cluster_version[[:space:]]*=.*/q_cluster_version = \"$QUMULO_VERSION\"/" "$tfvars_file"
    
    sed -i "s/^q_persistent_storage_type[[:space:]]*=.*/q_persistent_storage_type = \"hot_s3_int\"/" "$tfvars_file"
    sed -i "s/^q_instance_type[[:space:]]*=.*/q_instance_type = \"i4i.xlarge\"/" "$tfvars_file"
    sed -i "s/^q_node_count[[:space:]]*=.*/q_node_count = 3/" "$tfvars_file"
    sed -i "s/^dev_environment[[:space:]]*=.*/dev_environment = true/" "$tfvars_file"

    # Set up Qumulo DNS Resolver
    sed -i "s/^q_cluster_fqdn[[:space:]]*=.*/q_cluster_fqdn = \"demopri.qumulo.local\"/" "$tfvars_file"

0    # Replace the tags section with proper formatting
    sed -i "0,/^tags[[:space:]]*=.*/{s/^tags[[:space:]]*=.*/tags = { \"department\" = \"se\", \"owner\" = \"awsworkshop\", \"purpose\" = \"aws-workshop\", \"long_running\" = \"false\" }/}" "$tfvars_file"

    # Append the floating IPs line to the end of the file
    {
        echo ""
        echo "# Set the initial floating IPs to 5 for the purposes of this workshop, this line is not recommended or needed in production."
        echo "q_cluster_initial_floating_ips = 5"
    } >> "$tfvars_file"

    log_info "Updated terraform.tfvars with workshop values"
    return 0
}



# Function to verify configuration
verify_configuration() {
    log_step "Verifying configuration"
    
    log_info "Checking file structure:"
    
    # Check key files exist
    local files_to_check=(
        "${DEPLOYMENT_DIR}/provider.tf"
        "${DEPLOYMENT_DIR}/persistent-storage/provider.tf"
        "${DEPLOYMENT_DIR}/persistent-storage/terraform.tfvars"
        "${DEPLOYMENT_DIR}/terraform.tfvars"
    )
    
    for file in "${files_to_check[@]}"; do
        if [ -f "$file" ]; then
            log_info "  ✓ $file"
        else
            log_error "  ✗ $file (missing)"
            return 1
        fi
    done
    
    # Show sample of modified values
    log_info "Sample of modified values:"
    log_info "  Deployment name: $(grep '^deployment_name' ${DEPLOYMENT_DIR}/config-standard.tfvars)"
    log_info "  AWS Region: $(grep '^aws_region' ${DEPLOYMENT_DIR}/config-standard.tfvars)"
    log_info "  VPC ID: $(grep '^aws_vpc_id' ${DEPLOYMENT_DIR}/config-standard.tfvars)"
    
    log_info "Configuration verification completed successfully"
    
    return 0
}

# Function to display summary
display_summary() {
    log_header "Deployment Configuration Summary"
    
    echo "Deployment Directory: $DEPLOYMENT_DIR"
    echo "AWS Region: $AWS_REGION"
    echo "VPC ID: $VPC_ID"
    echo "Private Subnet: $PRIVATE_SUBNET_A"
    echo "Key Pair ID: $PRIVATE_KEY_ID"
    echo "Utility Bucket: $WORKSHOP_UTILITY_BUCKET"
    echo "Workshop Password: $WORKSHOP_PASSWORD"
    echo ""
    echo "Configuration Files Modified:"
    echo "  - Root provider.tf: Configured for local backend"
    echo "  - Persistent storage provider.tf: Configured for local backend"
    echo "  - Persistent storage terraform.tfvars: Updated with workshop values"
    echo "  - Root config-standard.tfvars: Updated with workshop values"
    echo ""
    echo "Next Steps:"
    echo "  1. Review the configuration files in: $DEPLOYMENT_DIR"
    echo "  2. Navigate to: cd $DEPLOYMENT_DIR"
    echo "  3. Manually run the deployment with: /home/ssm-user/qumulo-workshop/scripts/deploy-qumulo-cluster.sh $DEPLOYMENT_DIR \"Primary Workshop Qumulo Cluster - SAZ\""

}

# Main execution function
main() {
    log_header "Qumulo Workshop - Initial Cluster Deployment Setup"
    
    # Step 1: Load CloudFormation variables
    if ! load_variables; then
        log_error "Failed to load CloudFormation variables"
        exit 1
    fi
    
    # Step 2: Copy template files
    if ! copy_template_files; then
        log_error "Failed to copy template files"
        exit 1
    fi
    
    # Step 3: Configure persistent storage provider.tf
    if ! configure_persistent_storage_providers; then
        log_error "Failed to configure persistent storage provider.tf"
        exit 1
    fi
    
    # Step 4: Configure root provider.tf
    if ! configure_root_providers; then
        log_error "Failed to configure root provider.tf"
        exit 1
    fi
    
    # Step 5: Configure persistent storage terraform.tfvars
    if ! configure_persistent_storage_tfvars; then
        log_error "Failed to configure persistent storage terraform.tfvars"
        exit 1
    fi
    
    # Step 6: Configure root config-standard.tfvars
    if ! configure_root_tfvars; then
        log_error "Failed to configure root config-standard.tfvars"
        exit 1
    fi
    
    # Step 7: Verify configuration
    if ! verify_configuration; then
        log_error "Configuration verification failed"
        exit 1
    fi
    
    # Step 8: Display summary
    display_summary
    
    log_header "Setup Complete!"
    log_info "Deployment configuration is ready for testing"
}

# Run main function
main "$@"

# Call the deployment script to deploy the cluster
log_header "Initiating Cluster Deployment"
log_info "Calling deployment script to deploy the configured cluster..."

if [ -f "/home/ssm-user/qumulo-workshop/scripts/deploy-qumulo-cluster.sh" ]; then
    /home/ssm-user/qumulo-workshop/scripts/deploy-qumulo-cluster.sh "$DEPLOYMENT_DIR" "Primary Workshop Qumulo Cluster - SAZ"
else
    log_error "Deployment script not found at /home/ssm-user/qumulo-workshop/scripts/deploy-qumulo-cluster.sh"
    log_info "You can manually run the deployment with:"
    log_info "  /home/ssm-user/qumulo-workshop/scripts/deploy-qumulo-cluster.sh $DEPLOYMENT_DIR \"Primary Workshop Qumulo Cluster - SAZ\""
fi
