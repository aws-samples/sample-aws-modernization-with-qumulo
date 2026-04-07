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

set -e # Exit on any error

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

# Function to load CloudFormation variables
load_variables() {
  log_step "Loading CloudFormation variables from JSON file"

  if [ ! -f "$VARIABLES_FILE" ]; then
    log_error "Variables file not found: $VARIABLES_FILE"
    return 1
  fi

  # Extract variables from JSON file
  AWS_REGION=$(jq -r '.AWSRegion' "$VARIABLES_FILE")
  VPC_ID=$(jq -r '.VPCId' "$VARIABLES_FILE")
  PRIVATE_SUBNET_A=$(jq -r '.PrivateSubnetA' "$VARIABLES_FILE")
  PRIVATE_SUBNET_B=$(jq -r '.PrivateSubnetB' "$VARIABLES_FILE")
  PRIVATE_SUBNET_C=$(jq -r '.PrivateSubnetC' "$VARIABLES_FILE")
  WORKSHOP_UTILITY_BUCKET=$(jq -r '.WorkshopUtilityBucket' "$VARIABLES_FILE")
  WORKSHOP_PASSWORD=$(jq -r '.QumuloPassword' "$VARIABLES_FILE")
  QUMULO_VERSION=$(jq -r '.QumuloVersion' "$VARIABLES_FILE")

  # Key pair name provided by Workshop Studio
  KEY_NAME=$(jq -r '.KeyPairName' "$VARIABLES_FILE")

  # Randomly select one of the three private subnets
  SUBNETS=("$PRIVATE_SUBNET_A" "$PRIVATE_SUBNET_B" "$PRIVATE_SUBNET_C")
  RANDOM_INDEX=$((RANDOM % 3))
  SELECTED_SUBNET=${SUBNETS[$RANDOM_INDEX]}

  log_info "Loaded variables:"
  log_info "  AWS Region: $AWS_REGION"
  log_info "  VPC ID: $VPC_ID"
  log_info "  Key Pair Name: $KEY_NAME"
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

# Function to configure persistent storage backend.tf
configure_persistent_storage_backend() {
  log_step "Configuring persistent-storage backend for local state"

  local backend_file="$DEPLOYMENT_DIR/persistent-storage/backend.tf"

  if [ ! -f "$backend_file" ]; then
    log_error "Persistent-storage backend file not found: $backend_file"
    return 1
  fi

  cp "$backend_file" "${backend_file}.backup"
  log_info "Created backup $backend_file.backup"

  # Comment out entire S3 backend block (Terraform will use local backend)
  sed -i 's/^terraform {/# terraform {/' "$backend_file"
  sed -i 's/^[[:space:]]*backend "s3" {/#   backend "s3" {/' "$backend_file"
  sed -i 's/^[[:space:]]*bucket/#     bucket/' "$backend_file"
  sed -i 's/^[[:space:]]*key/#     key/' "$backend_file"
  sed -i 's/^[[:space:]]*region/#     region/' "$backend_file"
  sed -i 's/^[[:space:]]*use_lockfile/#     use_lockfile/' "$backend_file"
  sed -i 's/^[[:space:]]*workspace_key_prefix/#     workspace_key_prefix/' "$backend_file"
  sed -i '/^[[:space:]]*}$/s/^/#   /' "$backend_file"
  sed -i 's/^}$/# }/' "$backend_file"

  log_info "Commented out S3 backend block in persistent-storage backend.tf"
  return 0
}

# Function to configure compute backend.tf
configure_compute_backend() {
  log_step "Configuring compute backend for local state"

  local backend_file="$DEPLOYMENT_DIR/backend.tf"

  if [ ! -f "$backend_file" ]; then
    log_error "Compute backend file not found: $backend_file"
    return 1
  fi

  cp "$backend_file" "${backend_file}.backup"
  log_info "Created backup $backend_file.backup"

  # Comment out entire S3 backend block (Terraform will use local backend)
  sed -i 's/^terraform {/# terraform {/' "$backend_file"
  sed -i 's/^[[:space:]]*backend "s3" {/#   backend "s3" {/' "$backend_file"
  sed -i 's/^[[:space:]]*bucket/#     bucket/' "$backend_file"
  sed -i 's/^[[:space:]]*key/#     key/' "$backend_file"
  sed -i 's/^[[:space:]]*region/#     region/' "$backend_file"
  sed -i 's/^[[:space:]]*use_lockfile/#     use_lockfile/' "$backend_file"
  sed -i 's/^[[:space:]]*workspace_key_prefix/#     workspace_key_prefix/' "$backend_file"
  sed -i '/^[[:space:]]*}$/s/^/#   /' "$backend_file"
  sed -i 's/^}$/# }/' "$backend_file"

  log_info "Commented out S3 backend block in compute backend.tf"
  return 0
}

# Function to configure persistent storage terraform.tfvars
configure_persistent_storage_tfvars() {
  log_step "Configuring persistent storage tfvars (6.7)"

  local tfvars_file="$DEPLOYMENT_DIR/persistent-storage/terraform.tfvars"

  if [ ! -f "$tfvars_file" ]; then
    log_error "Persistent storage tfvars file not found: $tfvars_file"
    return 1
  fi

  cp "$tfvars_file" "${tfvars_file}.backup"
  log_info "Created backup ${tfvars_file}.backup"

  # deployment_name (default: "my-storage-deployment-name")
  sed -i \
    's/^deployment_name *=.*/deployment_name = "qum-wks-cls-pri-str"/' \
    "$tfvars_file"

  # aws_region (default: "us-west-2")
  sed -i \
    "s/^aws_region *=.*/aws_region = \"$AWS_REGION\"/" \
    "$tfvars_file"

  # prevent_destroy (default: true)
  sed -i \
    's/^prevent_destroy *=.*/prevent_destroy = false/' \
    "$tfvars_file"

  # tags (default: null)
  sed -i \
    's/^tags *=.*/tags = { "department" = "se", "owner" = "awsworkshop", "purpose" = "aws-workshop", "long_running" = "false" }/' \
    "$tfvars_file"

  log_info "Updated persistent storage terraform.tfvars for 6.7"
  return 0
}

# Function to configure compute config-standard.tfvars
configure_compute_tfvars() {
  log_step "Configuring compute config-standard.tfvars (6.7)"

  local tfvars_file="$DEPLOYMENT_DIR/config-standard.tfvars"
  local auto_tfvars_file="$DEPLOYMENT_DIR/terraform.tfvars"

  if [ ! -f "$tfvars_file" ]; then
    log_error "Compute tfvars file not found: $tfvars_file"
    return 1
  fi

  cp "$tfvars_file" "${tfvars_file}.backup"
  log_info "Created backup ${tfvars_file}.backup"

  # deployment_name (default: "")
  sed -i \
    's/^deployment_name *=.*/deployment_name = "qum-wks-cls-pri"/' \
    "$tfvars_file"

  # s3_bucket_name (default: "")
  sed -i \
    "s/^s3_bucket_name *=.*/s3_bucket_name = \"$WORKSHOP_UTILITY_BUCKET\"/" \
    "$tfvars_file"

  # s3_bucket_prefix (default: "")
  sed -i \
    's/^s3_bucket_prefix *=.*/s3_bucket_prefix = "qumulo_installs\/"/' \
    "$tfvars_file"

  # s3_bucket_region (default: "")
  sed -i \
    "s/^s3_bucket_region *=.*/s3_bucket_region = \"$AWS_REGION\"/" \
    "$tfvars_file"

  # aws_region (default: "")
  sed -i \
    "s/^aws_region *=.*/aws_region = \"$AWS_REGION\"/" \
    "$tfvars_file"

  # aws_vpc_id (default: "")
  sed -i \
    "s/^aws_vpc_id *=.*/aws_vpc_id = \"$VPC_ID\"/" \
    "$tfvars_file"

  # ec2_key_pair (default: "")
  sed -i \
    "s/^ec2_key_pair *=.*/ec2_key_pair = \"$KEY_NAME\"/" \
    "$tfvars_file"

  # private_subnet_id (default: "")
  sed -i \
    "s/^private_subnet_id *=.*/private_subnet_id = \"$SELECTED_SUBNET\"/" \
    "$tfvars_file"

  # term_protection (default: true)
  sed -i \
    's/^term_protection *=.*/term_protection = false/' \
    "$tfvars_file"

  # q_cluster_admin_password (default: "")
  sed -i \
    "s/^q_cluster_admin_password *=.*/q_cluster_admin_password = \"$WORKSHOP_PASSWORD\"/" \
    "$tfvars_file"

  # q_cluster_name (default: "")
  sed -i \
    's/^q_cluster_name *=.*/q_cluster_name = "demopri"/' \
    "$tfvars_file"

  # q_cluster_version (default: "")
  sed -i \
    "s/^q_cluster_version *=.*/q_cluster_version = \"$QUMULO_VERSION\"/" \
    "$tfvars_file"

  # q_instance_type (default: "m6idn.xlarge")
  sed -i \
    's/^q_instance_type *=.*/q_instance_type = "i4i.xlarge"/' \
    "$tfvars_file"

  # q_node_count (default: 0)
  sed -i \
    's/^q_node_count *=.*/q_node_count = 3/' \
    "$tfvars_file"

  # dev_environment (default: false)
  sed -i \
    's/^dev_environment *=.*/dev_environment = true/' \
    "$tfvars_file"

  # tf_persistent_storage_backend_type (default: "s3")
  sed -i \
    's/^tf_persistent_storage_backend_type *=.*/tf_persistent_storage_backend_type = "local"/' \
    "$tfvars_file"

  # q_cluster_fqdn (default: "")
  sed -i \
    's/^q_cluster_fqdn *=.*/q_cluster_fqdn = "demopri.qumulo.local"/' \
    "$tfvars_file"

  # tags (default: null)
  sed -i \
    's/^tags *=.*/tags = { "department" = "se", "owner" = "awsworkshop", "purpose" = "aws-workshop", "long_running" = "false" }/' \
    "$tfvars_file"

  log_info "Updated compute config-standard.tfvars for 6.7 with local persistent-storage state"

  # Promote to terraform.tfvars so terraform picks it up without -var-file
  cp "$tfvars_file" "$auto_tfvars_file"
  log_info "Copied config-standard.tfvars to terraform.tfvars for automatic use"

  return 0
}

# Function to verify configuration
verify_configuration() {
  log_step "Verifying configuration"

  log_info "Checking file structure:"

  # Check key files exist
  local files_to_check=(
    "${DEPLOYMENT_DIR}/provider.tf"
    "${DEPLOYMENT_DIR}/backend.tf"
    "${DEPLOYMENT_DIR}/persistent-storage/provider.tf"
    "${DEPLOYMENT_DIR}/persistent-storage/backend.tf"
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
  echo "AWS Region:           $AWS_REGION"
  echo "VPC ID:               $VPC_ID"
  echo "Selected Subnet:      $SELECTED_SUBNET"
  echo "Key Pair Name:        $KEY_NAME"
  echo "Utility Bucket:       $WORKSHOP_UTILITY_BUCKET"
  echo "Workshop Password:    $WORKSHOP_PASSWORD"
  echo "Qumulo Version:       $QUMULO_VERSION"
  echo ""
  echo "Configuration Files Modified:"
  echo "  - Root backend.tf: Commented out S3 backend for local state"
  echo "  - Persistent storage backend.tf: Commented out S3 backend for local state"
  echo "  - Persistent storage terraform.tfvars: Updated with workshop values"
  echo "  - Root config-standard.tfvars: Updated with workshop values"
  echo "  - Root terraform.tfvars: Promoted from config-standard.tfvars"
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

  # Step 3: Configure persistent storage backend.tf
  if ! configure_persistent_storage_backend; then
    log_error "Failed to configure persistent storage backend.tf"
    exit 1
  fi

  # Step 4: Configure compute backend.tf
  if ! configure_compute_backend; then
    log_error "Failed to configure compute backend.tf"
    exit 1
  fi

  # Step 5: Configure persistent storage terraform.tfvars
  if ! configure_persistent_storage_tfvars; then
    log_error "Failed to configure persistent storage terraform.tfvars"
    exit 1
  fi

  # Step 6: Configure compute config-standard.tfvars
  if ! configure_compute_tfvars; then
    log_error "Failed to configure compute config-standard.tfvars"
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
