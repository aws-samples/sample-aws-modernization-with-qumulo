#!/bin/bash

# Qumulo Workshop - SAZ to MAZ Cluster Replacement Script
# This script converts a single-AZ cluster deployment to multi-AZ configuration

set -e # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
WORKSHOP_DIR="/home/ssm-user/qumulo-workshop"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
TARGET_DEPLOYMENT_NAME="terraform_deployment_primary_maz"
TARGET_DEPLOYMENT_DIR="${WORKSHOP_DIR}/${TARGET_DEPLOYMENT_NAME}"

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$REPLACEMENT_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$REPLACEMENT_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$REPLACEMENT_LOG"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1" | tee -a "$REPLACEMENT_LOG"
}

log_header() {
    echo "" | tee -a "$REPLACEMENT_LOG"
    echo -e "${PURPLE}================================${NC}" | tee -a "$REPLACEMENT_LOG"
    echo -e "${PURPLE}$1${NC}" | tee -a "$REPLACEMENT_LOG"
    echo -e "${PURPLE}================================${NC}" | tee -a "$REPLACEMENT_LOG"
}

# Function to validate cluster registry exists
validate_cluster_registry() {
    local registry_file="${WORKSHOP_DIR}/cluster-access-info.json"
    
    if [[ ! -f "$registry_file" ]]; then
        log_error "Cluster registry file not found: $registry_file"
        log_error "No existing cluster found to replace. Please deploy a cluster first."
        exit 1
    fi
    
    # Check if there are any active clusters
    local active_count=$(jq '.clusters[] | select(.status == "active") | length' "$registry_file" 2>/dev/null || echo 0)
    if [[ "$active_count" -eq 0 ]]; then
        log_error "No active clusters found in registry"
        log_error "Cannot perform cluster replacement without an active source cluster"
        exit 1
    fi
    
    log_info "Cluster registry validated successfully"
}

# Function to get source deployment information
get_source_deployment() {
    local registry_file="${WORKSHOP_DIR}/cluster-access-info.json"
    
    # Get the first active cluster (assuming single active cluster for SAZ scenario)
    SOURCE_DEPLOYMENT_NAME=$(jq -r '.clusters[] | select(.status == "active") | .deployment_name' "$registry_file" | head -1)
    
    if [[ -z "$SOURCE_DEPLOYMENT_NAME" || "$SOURCE_DEPLOYMENT_NAME" == "null" ]]; then
        log_error "Could not determine source deployment name from cluster registry"
        exit 1
    fi
    
    SOURCE_DEPLOYMENT_DIR="${WORKSHOP_DIR}/${SOURCE_DEPLOYMENT_NAME}"
    
    if [[ ! -d "$SOURCE_DEPLOYMENT_DIR" ]]; then
        log_error "Source deployment directory not found: $SOURCE_DEPLOYMENT_DIR"
        exit 1
    fi
    
    log_info "Source deployment: $SOURCE_DEPLOYMENT_NAME"
    log_info "Source directory: $SOURCE_DEPLOYMENT_DIR"
}

# Function to copy source deployment to target
copy_deployment_files() {
    log_step "Copying source deployment files to target directory"
    
    # Remove target directory if it exists
    if [[ -d "$TARGET_DEPLOYMENT_DIR" ]]; then
        log_warning "Target deployment directory exists, removing: $TARGET_DEPLOYMENT_DIR"
        rm -rf "$TARGET_DEPLOYMENT_DIR"
    fi
    
    # Copy all files from source to target
    log_info "Copying from $SOURCE_DEPLOYMENT_DIR to $TARGET_DEPLOYMENT_DIR"
    cp -r "$SOURCE_DEPLOYMENT_DIR" "$TARGET_DEPLOYMENT_DIR"
    
    # Verify copy was successful
    if [[ ! -d "$TARGET_DEPLOYMENT_DIR" ]]; then
        log_error "Failed to copy deployment files"
        exit 1
    fi
    
    log_info "Deployment files copied successfully"
}

# Function to clean state files
clean_state_files() {
    log_step "Cleaning Terraform state files from target deployment"
    
    local files_to_remove=(
        "${TARGET_DEPLOYMENT_DIR}/terraform.tfstate"
        "${TARGET_DEPLOYMENT_DIR}/terraform.tfstate.backup"
        "${TARGET_DEPLOYMENT_DIR}/tfplan"
        "${TARGET_DEPLOYMENT_DIR}/.terraform"
    )
    
    for file in "${files_to_remove[@]}"; do
        if [[ -e "$file" ]]; then
            log_info "Removing: $(basename "$file")"
            rm -rf "$file"
        fi
    done
    
    log_info "State files cleaned successfully"
}

# Function to load CloudFormation variables
load_cloudformation_variables() {
    log_step "Loading CloudFormation variables"
    
    local variables_file="${WORKSHOP_DIR}/cloudformation-variables.json"
    
    if [[ ! -f "$variables_file" ]]; then
        log_error "CloudFormation variables file not found: $variables_file"
        exit 1
    fi
    
    # Extract subnet information
    PRIVATE_SUBNET_A=$(jq -r '.PrivateSubnetA // empty' "$variables_file")
    PRIVATE_SUBNET_B=$(jq -r '.PrivateSubnetB // empty' "$variables_file")
    PRIVATE_SUBNET_C=$(jq -r '.PrivateSubnetC // empty' "$variables_file")
    
    if [[ -z "$PRIVATE_SUBNET_A" || -z "$PRIVATE_SUBNET_B" || -z "$PRIVATE_SUBNET_C" ]]; then
        log_error "Could not retrieve all private subnet IDs from CloudFormation variables"
        log_error "PrivateSubnetA: $PRIVATE_SUBNET_A"
        log_error "PrivateSubnetB: $PRIVATE_SUBNET_B"
        log_error "PrivateSubnetC: $PRIVATE_SUBNET_C"
        exit 1
    fi
    
    # Create comma-separated subnet list
    PRIVATE_SUBNET_LIST="${PRIVATE_SUBNET_A},${PRIVATE_SUBNET_B},${PRIVATE_SUBNET_C}"
    
    log_info "Private subnets loaded: $PRIVATE_SUBNET_LIST"
}

# Function to get existing cluster name for replacement reference
get_existing_cluster_name() {
    log_step "Getting existing cluster name for replacement reference"
    
    local registry_file="${WORKSHOP_DIR}/cluster-access-info.json"
    
    EXISTING_CLUSTER_NAME=$(jq -r --arg deployment "$SOURCE_DEPLOYMENT_NAME" \
                           '.clusters[] | select(.deployment_name == $deployment and .status == "active") | .cluster_name' \
                           "$registry_file")
    
    if [[ -z "$EXISTING_CLUSTER_NAME" || "$EXISTING_CLUSTER_NAME" == "null" ]]; then
        log_error "Could not determine existing cluster name from registry"
        exit 1
    fi
    
    log_info "Existing cluster name: $EXISTING_CLUSTER_NAME"
}

# Function to update terraform.tfvars for MAZ configuration
update_terraform_tfvars() {
    log_step "Updating terraform.tfvars for multi-AZ configuration"
    
    local tfvars_file="${TARGET_DEPLOYMENT_DIR}/terraform.tfvars"
    
    if [[ ! -f "$tfvars_file" ]]; then
        log_error "terraform.tfvars file not found: $tfvars_file"
        exit 1
    fi
    
    # Create backup
    cp "$tfvars_file" "${tfvars_file}.backup"
    log_info "Created backup: ${tfvars_file}.backup"
    
    # Update private_subnet_id with comma-separated list
    log_info "Updating private_subnet_id to: $PRIVATE_SUBNET_LIST"
    sed -i "s/^private_subnet_id[[:space:]]*=.*/private_subnet_id = \"$PRIVATE_SUBNET_LIST\"/" "$tfvars_file"

    #update node type to i7ie.xlarge
    log_info "Changing node type to i7ie.xlarge"
    sed -i "s/^q_instance_type[[:space:]]*=.*/q_instance_type = \"i7i.xlarge\"/" "$tfvars_file"

    # Update q_replacement_cluster to true
    log_info "Setting q_replacement_cluster = true"
    sed -i "s/^q_replacement_cluster[[:space:]]*=.*/q_replacement_cluster = true/" "$tfvars_file"
    
    # Update q_existing_deployment_unique_name with the existing cluster name
    log_info "Setting q_existing_deployment_unique_name = \"$EXISTING_CLUSTER_NAME\""
    sed -i "s/^q_existing_deployment_unique_name[[:space:]]*=.*/q_existing_deployment_unique_name = \"$EXISTING_CLUSTER_NAME\"/" "$tfvars_file"
    
    # Update NLB settings
    log_info "Enabling NLB configuration"
    sed -i "s/^q_nlb_provision[[:space:]]*=.*/q_nlb_provision = true/" "$tfvars_file"
    
    log_info "terraform.tfvars updated successfully"
}

# Function to display configuration summary
display_configuration_summary() {
    log_step "Configuration Summary"
    
    echo ""
    echo "========================================="
    echo "CLUSTER REPLACEMENT CONFIGURATION"
    echo "========================================="
    echo "Source Deployment: $SOURCE_DEPLOYMENT_NAME"
    echo "Target Deployment: $TARGET_DEPLOYMENT_NAME"
    echo "Existing Cluster: $EXISTING_CLUSTER_NAME"
    echo "Private Subnets: $PRIVATE_SUBNET_LIST"
    echo "Replacement Mode: Enabled"
    echo "NLB Configuration: Enabled"
    echo "========================================="
    echo ""
    
    # Show key changes in tfvars
    local tfvars_file="${TARGET_DEPLOYMENT_DIR}/terraform.tfvars"
    echo "Key terraform.tfvars changes:"
    echo "- private_subnet_id: $(grep "^private_subnet_id" "$tfvars_file" || echo "Not found")"
    echo "- q_replacement_cluster: $(grep "^q_replacement_cluster" "$tfvars_file" || echo "Not found")"
    echo "- q_existing_deployment_unique_name: $(grep "^q_existing_deployment_unique_name" "$tfvars_file" || echo "Not found")"
    echo "- q_nlb_provision: $(grep "^q_nlb_provision" "$tfvars_file" || echo "Not found")"
    echo ""
}

# Function to mark source cluster as replaced in registry
mark_source_cluster_replaced() {
    log_step "Marking source cluster as replaced in registry"
    
    local registry_file="${WORKSHOP_DIR}/cluster-access-info.json"
    local temp_json=$(mktemp)
    
    # Mark the source cluster as replaced
    jq --arg source_deployment "$SOURCE_DEPLOYMENT_NAME" \
       --arg timestamp "$(date -Iseconds)" \
       --arg target_deployment "$TARGET_DEPLOYMENT_NAME" \
       '(.clusters[] | select(.deployment_name == $source_deployment)) |= {
         status: "replaced",
         replaced_at: $timestamp,
         replaced_by: $target_deployment
       } + .' \
       "$registry_file" > "$temp_json"
    
    mv "$temp_json" "$registry_file"
    log_info "Source cluster marked as replaced in registry"
}

# Function to handle script failure
handle_failure() {
    local exit_code="$1"
    local failed_step="$2"
    
    log_error "Cluster replacement preparation failed at step: $failed_step"
    log_error "Exit code: $exit_code"
    
    # Clean up target directory if it was created
    if [[ -d "$TARGET_DEPLOYMENT_DIR" ]]; then
        log_info "Cleaning up target deployment directory"
        rm -rf "$TARGET_DEPLOYMENT_DIR"
    fi
    
    echo ""
    echo "========================================="
    echo "CLUSTER REPLACEMENT PREPARATION FAILED"
    echo "========================================="
    echo "Failed step: $failed_step"
    echo "Check log file: $REPLACEMENT_LOG"
    echo "========================================="
    
    exit "$exit_code"
}

# Main execution function
main() {
    # Set up logging
    REPLACEMENT_LOG="/home/ssm-user/qumulo-workshop/logs/qumulo-cluster-replacement-${TIMESTAMP}.log"
    
    log_header "Qumulo Cluster SAZ to MAZ Replacement Preparation"
    log_info "Starting cluster replacement preparation"
    log_info "Log file: $REPLACEMENT_LOG"
    
    # Step 1: Validate cluster registry
    validate_cluster_registry || handle_failure 1 "validate_cluster_registry"
    
    # Step 2: Get source deployment information
    get_source_deployment || handle_failure 2 "get_source_deployment"
    
    # Step 3: Load CloudFormation variables
    load_cloudformation_variables || handle_failure 3 "load_cloudformation_variables"
    
    # Step 4: Get existing cluster name
    get_existing_cluster_name || handle_failure 4 "get_existing_cluster_name"
    
    # Step 5: Copy deployment files
    copy_deployment_files || handle_failure 5 "copy_deployment_files"
    
    # Step 6: Clean state files
    clean_state_files || handle_failure 6 "clean_state_files"
    
    # Step 7: Update terraform.tfvars
    update_terraform_tfvars || handle_failure 7 "update_terraform_tfvars"
    
    # Step 8: Mark source cluster as replaced
    mark_source_cluster_replaced || handle_failure 8 "mark_source_cluster_replaced"
    
    # Step 9: Display summary
    display_configuration_summary
    
    log_header "Cluster Replacement Preparation Complete"
    log_info "Multi-AZ deployment configuration is ready"
    log_info "Target deployment directory: $TARGET_DEPLOYMENT_DIR"
    
    echo ""
    echo "🎉 CLUSTER REPLACEMENT PREPARATION COMPLETE!"
    echo ""
    echo "Next steps:"
    echo "1. Review the configuration summary above"
    echo "2. Deploy the multi-AZ cluster:"
    echo "   cd /home/ssm-user/qumulo-workshop/scripts"
    echo "   ./cluster-replace.sh \"$TARGET_DEPLOYMENT_DIR\" \"Multi-AZ replacement cluster with NLB\""
    echo ""
    echo "The new cluster will replace the existing single-AZ cluster."
    echo ""
}

# Trap to handle script interruption
trap 'handle_failure 130 "script_interrupted"' INT TERM

# Execute main function
main "$@"
