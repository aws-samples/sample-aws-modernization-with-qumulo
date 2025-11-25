#!/bin/bash
# Qumulo Workshop - Add Cluster Node Script
# This script adds 2 nodes node to the existing primary cluster

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
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
WORKSHOP_DIR="$HOME/qumulo-workshop"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$ADDNODE_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$ADDNODE_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$ADDNODE_LOG"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1" | tee -a "$ADDNODE_LOG"
}

log_header() {
    echo "" | tee -a "$ADDNODE_LOG"
    echo -e "${PURPLE}========================================${NC}" | tee -a "$ADDNODE_LOG"
    echo -e "${PURPLE}$1${NC}" | tee -a "$ADDNODE_LOG"
    echo -e "${PURPLE}========================================${NC}" | tee -a "$ADDNODE_LOG"
    echo "" | tee -a "$ADDNODE_LOG"
}

# Function to display usage
usage() {
    echo "Usage: $0"
    echo ""
    echo "This script adds 2 nodes to the existing primary Qumulo cluster."
    echo "It automatically finds the primary cluster from the registry and updates the node count."
    echo ""
    echo "Example:"
    echo "  $0"
    echo ""
    exit 1
}

# Function to validate prerequisites
validate_prerequisites() {
    log_step "Validating prerequisites"
    
    # Check if workshop directory exists
    if [[ ! -d "$WORKSHOP_DIR" ]]; then
        log_error "Workshop directory does not exist: $WORKSHOP_DIR"
        exit 1
    fi
    
    # Check if cluster registry exists
    local registry_file="$WORKSHOP_DIR/cluster-access-info.json"
    if [[ ! -f "$registry_file" ]]; then
        log_error "Cluster registry file not found: $registry_file"
        exit 1
    fi
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed"
        exit 1
    fi
    
    # Check if terraform is available
    if ! command -v terraform &> /dev/null; then
        log_error "terraform is required but not installed"
        exit 1
    fi
    
    log_info "Prerequisites validation completed successfully"
}

# Function to find primary cluster from registry
find_primary_cluster() {
    log_step "Finding primary cluster from registry"
    
    local registry_file="$WORKSHOP_DIR/cluster-access-info.json"
    
    # Look for active primary cluster - check deployment_name contains "primary" AND status is "active"
    PRIMARY_DEPLOYMENT_NAME=$(jq -r '.clusters[] | select(.status == "active" and (.deployment_name | contains("primary"))) | .deployment_name' "$registry_file" | head -1)
    
    if [[ -z "$PRIMARY_DEPLOYMENT_NAME" || "$PRIMARY_DEPLOYMENT_NAME" == "null" ]]; then
        log_error "Could not find active primary cluster in registry"
        log_info "Available active clusters:"
        jq -r '.clusters[] | select(.status == "active") | "- \(.deployment_name // "unnamed") (\(.description // "no description"))"' "$registry_file" | tee -a "$ADDNODE_LOG"
        exit 1
    fi
    
    PRIMARY_DEPLOYMENT_DIR="$WORKSHOP_DIR/$PRIMARY_DEPLOYMENT_NAME"
    
    if [[ ! -d "$PRIMARY_DEPLOYMENT_DIR" ]]; then
        log_error "Primary cluster deployment directory not found: $PRIMARY_DEPLOYMENT_DIR"
        exit 1
    fi
    
    log_info "Primary cluster deployment name: $PRIMARY_DEPLOYMENT_NAME"
    log_info "Primary cluster deployment directory: $PRIMARY_DEPLOYMENT_DIR"
    
    # Get current cluster information for display only
    local cluster_info=$(jq --arg deployment "$PRIMARY_DEPLOYMENT_NAME" '.clusters[] | select(.deployment_name == $deployment)' "$registry_file")
    local cluster_name=$(echo "$cluster_info" | jq -r '.cluster_name // "unknown"')
    local cluster_description=$(echo "$cluster_info" | jq -r '.description // "No description"')
    
    log_info "Cluster name: $cluster_name"
    log_info "Cluster description: $cluster_description"
}



# Function to get current node count and update tfvars
update_node_count() {
    log_step "Updating cluster node count"
    
    local tfvars_file="$PRIMARY_DEPLOYMENT_DIR/terraform.tfvars"
    
    if [[ ! -f "$tfvars_file" ]]; then
        log_error "terraform.tfvars file not found: $tfvars_file"
        exit 1
    fi
    
    # Create backup of tfvars file
    local backup_file="$tfvars_file.backup-$TIMESTAMP"
    cp "$tfvars_file" "$backup_file"
    log_info "Created backup: $backup_file"
    
    # Extract current node count - find the first non-commented line with q_node_count
    local current_node_count=$(grep -v "^[[:space:]]*#" "$tfvars_file" | grep "q_node_count" | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' ')
    
    if [[ -z "$current_node_count" ]]; then
        log_error "Could not find q_node_count in terraform.tfvars"
        exit 1
    fi
    
    # Calculate new node count
    local new_node_count=$((current_node_count + 2))
    
    log_info "Current node count: $current_node_count"
    log_info "New node count: $new_node_count"
    
    # Update the tfvars file - only update the first non-commented occurrence
    sed -i "0,/^[[:space:]]*q_node_count[[:space:]]*=/s/q_node_count[[:space:]]*=[[:space:]]*.*/q_node_count = $new_node_count/" "$tfvars_file"
    
    # Verify the change
    local updated_count=$(grep -v "^[[:space:]]*#" "$tfvars_file" | grep "q_node_count" | head -1 | sed 's/.*=[[:space:]]*//' | tr -d ' ')
    if [[ "$updated_count" != "$new_node_count" ]]; then
        log_error "Failed to update node count in terraform.tfvars"
        log_error "Expected: $new_node_count, Found: $updated_count"
        exit 1
    fi
    
    log_info "Successfully updated q_node_count from $current_node_count to $new_node_count"
    
    # Show the change
    echo "" | tee -a "$ADDNODE_LOG"
    echo "TERRAFORM.TFVARS CHANGES:" | tee -a "$ADDNODE_LOG"
    echo "=========================" | tee -a "$ADDNODE_LOG"
    echo "Before: q_node_count = $current_node_count" | tee -a "$ADDNODE_LOG"
    echo "After:  q_node_count = $new_node_count" | tee -a "$ADDNODE_LOG"
    echo "" | tee -a "$ADDNODE_LOG"
}


# Function to apply terraform changes
apply_terraform_changes() {
    log_step "Applying terraform changes"
    
    cd "$PRIMARY_DEPLOYMENT_DIR"
    
    # Initialize terraform
    log_info "Initializing Terraform..."
    if terraform init 2>&1 | tee -a "$ADDNODE_LOG"; then
        log_info "Terraform initialization completed successfully"
    else
        log_error "Terraform initialization failed"
        return 1
    fi
    
    # Plan the changes
    log_info "Planning terraform changes..."
    echo "" | tee -a "$ADDNODE_LOG"
    echo "TERRAFORM PLAN OUTPUT:" | tee -a "$ADDNODE_LOG"
    echo "=====================" | tee -a "$ADDNODE_LOG"
    
    if terraform plan 2>&1 | tee -a "$ADDNODE_LOG"; then
        log_info "Terraform plan completed successfully"
    else
        log_error "Terraform plan failed"
        return 1
    fi
    
    # Apply the changes
    log_info "Applying terraform changes..."
    echo "" | tee -a "$ADDNODE_LOG"
    echo "TERRAFORM APPLY OUTPUT:" | tee -a "$ADDNODE_LOG"
    echo "======================" | tee -a "$ADDNODE_LOG"
    
    if terraform apply -auto-approve 2>&1 | tee -a "$ADDNODE_LOG"; then
        log_info "Terraform apply completed successfully"
        echo "" | tee -a "$ADDNODE_LOG"
        return 0
    else
        log_error "Terraform apply failed"
        return 1
    fi
}

# Function to generate deployment summary
generate_summary() {
    log_step "Generating deployment summary"
    
    local tfvars_file="$PRIMARY_DEPLOYMENT_DIR/terraform.tfvars"
    local current_node_count=$(grep "q_node_count" "$tfvars_file" | sed 's/.*= *//' | tr -d ' ')
    
    echo "" | tee -a "$ADDNODE_LOG"
    echo "CLUSTER NODE ADDITION SUMMARY" | tee -a "$ADDNODE_LOG"
    echo "============================" | tee -a "$ADDNODE_LOG"
    echo "Primary Cluster: $PRIMARY_DEPLOYMENT_NAME" | tee -a "$ADDNODE_LOG"
    echo "New Node Count: $current_node_count nodes" | tee -a "$ADDNODE_LOG"
    echo "Deployment Directory: $PRIMARY_DEPLOYMENT_DIR" | tee -a "$ADDNODE_LOG"
    echo "Timestamp: $(date)" | tee -a "$ADDNODE_LOG"
    echo "" | tee -a "$ADDNODE_LOG"
    echo "NEXT STEPS:" | tee -a "$ADDNODE_LOG"
    echo "- The new node will be automatically added to the cluster" | tee -a "$ADDNODE_LOG"
    echo "- Cluster performance will be increased" | tee -a "$ADDNODE_LOG"
    echo "- No additional configuration is required" | tee -a "$ADDNODE_LOG"
    echo "" | tee -a "$ADDNODE_LOG"
    echo "Log file: $ADDNODE_LOG" | tee -a "$ADDNODE_LOG"
    echo "" | tee -a "$ADDNODE_LOG"
}

# Function to handle script failure
handle_failure() {
    local exit_code=$1
    local failed_step=$2
    log_error "Add cluster node operation failed at step: $failed_step"
    log_error "Exit code: $exit_code"
    echo ""
    echo "ADD CLUSTER NODE FAILED"
    echo "======================"
    echo "Failed step: $failed_step"
    echo "Check log file: $ADDNODE_LOG"
    echo ""
    exit $exit_code
}

# Main execution function
main() {
    # Set up logging
    ADDNODE_LOG="$WORKSHOP_DIR/logs/qumulo-add-node-$TIMESTAMP.log"
    mkdir -p "$(dirname "$ADDNODE_LOG")"
    
    log_header "Qumulo Cluster - Add Node Operation"
    log_info "Starting add cluster node operation"
    log_info "Log file: $ADDNODE_LOG"
    
    # Step 1: Validate prerequisites
    if ! validate_prerequisites; then
        handle_failure $? "validate_prerequisites"
    fi
    
    # Step 2: Find primary cluster
    if ! find_primary_cluster; then
        handle_failure $? "find_primary_cluster"
    fi
    
    # Step 3: Update node count in tfvars
    if ! update_node_count; then
        handle_failure $? "update_node_count"
    fi
    
    # Step 4: Apply terraform changes
    if ! apply_terraform_changes; then
        handle_failure $? "apply_terraform_changes"
    fi

    # Stop current load testing (this will also unmount)
    log_info "Stopping current load testing..."
    if $WORKSHOP_DIR/scripts/start-load-testing.sh stop; then
        log_info "Load testing stopped successfully"
    else
        log_warning "Load testing stop may have failed, continuing..."
    fi

    # Wait for 10 Seconds for connections to clear
    log_info "Waiting 10 seconds for connections to clear..."
    sleep 10

    # Start load testing with new DNS resolution
    log_info "Starting load testing with new cluster..."
    if $WORKSHOP_DIR/scripts/start-load-testing.sh start; then
        log_info "Load testing restarted successfully with new cluster"
    else
        log_error "Failed to restart load testing"
    fi
    
   
    # Step 5: Generate summary
    generate_summary
    
    log_header "Add Cluster Node Operation Complete"
    log_info "Cluster node addition completed successfully"
    log_info "New node has been added to the primary cluster"
}

# Trap to handle script interruption
trap 'handle_failure 130 "script_interrupted"' INT TERM

# Execute main function
main "$@"
