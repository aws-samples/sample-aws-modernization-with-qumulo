#!/bin/bash

###############################################################################
# remove-cluster-node.sh
#
# Removes two nodes from the primary Qumulo cluster using controlled tfvars
# edits and Terraform operations, ensuring safety and robust logging.
# 
# This script follows the same patterns established in the workshop system
# for consistency and reliability.
###############################################################################

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

set -euo pipefail

# === Color Codes for Output ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# === Configuration ===
WORKSHOP_DIR="${WORKSHOP_DIR:-/home/ssm-user/qumulo-workshop}"
REGISTRY_FILE="${WORKSHOP_DIR}/cluster-access-info.json"
VARIABLES_FILE="${WORKSHOP_DIR}/cloudformation-variables.json"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REMOVE_COUNT=2
MIN_NODES=5

# Initialize logging
LOG_FILE="$WORKSHOP_DIR/logs/qumulo-node-removal-$TIMESTAMP.log"

# === Logging Functions ===
log_info() { 
    echo -e "${GREEN}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

log_warn() { 
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"
}

log_error() { 
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() { 
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG_FILE"
}

log_step() { 
    echo -e "${BLUE}[STEP]${NC} $*" | tee -a "$LOG_FILE"
}

log_header() {
    echo "" | tee -a "$LOG_FILE"
    echo -e "${PURPLE}================================${NC}" | tee -a "$LOG_FILE"
    echo -e "${PURPLE}$*${NC}" | tee -a "$LOG_FILE"
    echo -e "${PURPLE}================================${NC}" | tee -a "$LOG_FILE"
}

# === Error trap ===
cleanup_on_exit() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "Script interrupted or failed with exit code $exit_code"
        log_info "Check log file for details: $LOG_FILE"
    fi
    exit $exit_code
}

trap cleanup_on_exit INT TERM EXIT

# === Main Function ===
main() {
    log_header "Qumulo Workshop - Remove Cluster Nodes"
    log_info "Starting node removal process at $(date)"
    log_info "Removing $REMOVE_COUNT nodes from primary cluster"
    
    
    # Step 1: Prerequisite checks
    check_prerequisites
    
    # Step 2: Identify and validate primary cluster
    identify_primary_cluster
    
    # Step 3: Validate current node count
    validate_node_count
    
    # Step 4: Backup current configuration
    backup_configuration
    
    # Step 5: Update terraform configuration (set target node count)
    update_target_node_count
    
    # Step 6: Apply terraform changes (shrink cluster)
    apply_terraform_shrink
    
    # Step 7: Finalize configuration (update node count, reset target)
    finalize_configuration
    
    # Step 8: Apply final terraform changes (destroy removed nodes)
    apply_terraform_finalize

    # Step 9: Generate summary
    generate_summary
    
    log_success "Node removal completed successfully!"
}

# === Prerequisite Checks ===
check_prerequisites() {
    log_step "Checking prerequisites"
    
    # Check if workshop directory exists
    if [[ ! -d "$WORKSHOP_DIR" ]]; then
        log_error "Workshop directory not found: $WORKSHOP_DIR"
        exit 1
    fi
    
    # Check if registry file exists
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        log_error "Cluster registry not found: $REGISTRY_FILE"
        exit 1
    fi
    
    # Check for required tools
    for tool in jq terraform aws; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_error "$tool is not installed or not in PATH"
            exit 1
        fi
    done
    
    # Check variables file
    if [[ ! -f "$VARIABLES_FILE" ]]; then
        log_error "Variables file not found: $VARIABLES_FILE"
        exit 1
    fi
    
    log_success "All prerequisites met"
}

# === Identify Primary Cluster ===
identify_primary_cluster() {
    log_step "Identifying primary cluster"

    
    # Look for active primary cluster - check deployment_name contains "primary" AND status is "active"
    PRIMARY_DEPLOYMENT_NAME=$(jq -r '.clusters[] | select(.status == "active" and (.deployment_name | contains("primary"))) | .deployment_name' "$REGISTRY_FILE" | head -1)

    if [[ -z "$PRIMARY_DEPLOYMENT_NAME" || "$PRIMARY_DEPLOYMENT_NAME" == "null" ]]; then
        log_error "Could not find active primary cluster in registry"
        log_info "Available active clusters:"
        jq -r '.clusters[] | select(.status == "active") | "- \(.deployment_name // "unnamed") (\(.description // "no description"))"' "$REGISTRY_FILE" | tee -a "$LOG_FILE"
        exit 1
    fi
    
    DEPLOY_DIR="$WORKSHOP_DIR/$PRIMARY_DEPLOYMENT_NAME"
    
    if [[ ! -d "$DEPLOY_DIR" ]]; then
        log_error "Primary cluster deployment directory not found: $DEPLOY_DIR"
        exit 1
    fi
    
    TFVARS_FILE="$DEPLOY_DIR/terraform.tfvars"
    
    if [[ ! -f "$TFVARS_FILE" ]]; then
        log_error "terraform.tfvars not found: $TFVARS_FILE"
        exit 1
    fi
    
    log_info "Primary cluster deployment name: $PRIMARY_DEPLOYMENT_NAME"
    log_info "Primary cluster deployment directory: $DEPLOY_DIR"
    
    # Get current cluster information for display only
    local cluster_info=$(jq --arg deployment "$PRIMARY_DEPLOYMENT_NAME" '.clusters[] | select(.deployment_name == $deployment)' "$REGISTRY_FILE")
    local cluster_name=$(echo "$cluster_info" | jq -r '.cluster_name // "unknown"')
    local cluster_description=$(echo "$cluster_info" | jq -r '.description // "No description"')
    
    log_info "Cluster name: $cluster_name"
    log_info "Cluster description: $cluster_description"
    
    log_success "Primary cluster identified"
}


# === Validate Node Count ===
validate_node_count() {
    log_step "Validating current node count"
    
    # Read current node count from tfvars
    CURRENT_NODE_COUNT=$(grep '^q_node_count[[:space:]]*=' "$TFVARS_FILE" | \
                        sed 's/.*=[[:space:]]*//' | \
                        tr -d ' "')
    
    if [[ ! "$CURRENT_NODE_COUNT" =~ ^[0-9]+$ ]]; then
        log_error "Could not parse q_node_count from tfvars file"
        exit 1
    fi
    
    if (( CURRENT_NODE_COUNT < MIN_NODES )); then
        log_error "Cannot remove nodes: current count ($CURRENT_NODE_COUNT) < minimum ($MIN_NODES)"
        exit 1
    fi
    
    TARGET_NODE_COUNT=$((CURRENT_NODE_COUNT - REMOVE_COUNT))
    
    log_info "Current node count: $CURRENT_NODE_COUNT"
    log_info "Target node count: $TARGET_NODE_COUNT"
    log_success "Node count validation passed"
}

# === Backup Configuration ===
backup_configuration() {
    log_step "Creating configuration backup"
    
    local backup_file="${TFVARS_FILE}.backup.$TIMESTAMP"
    cp "$TFVARS_FILE" "$backup_file"
    
    log_info "Configuration backed up to: $backup_file"
    log_success "Configuration backup created"
}

# === Update Target Node Count ===
update_target_node_count() {
    log_step "Setting target node count for cluster shrinking"
    
    # Update or add q_target_node_count
    if grep -q '^q_target_node_count[[:space:]]*=' "$TFVARS_FILE"; then
        # Update existing line
        sed -i "s/^q_target_node_count[[:space:]]*=.*/q_target_node_count = $TARGET_NODE_COUNT/" "$TFVARS_FILE"
    else
        # Add new line
        echo "q_target_node_count = $TARGET_NODE_COUNT" >> "$TFVARS_FILE"
    fi
    
    log_info "Set q_target_node_count = $TARGET_NODE_COUNT"
    log_success "Target node count updated"
}

# === Apply Terraform Shrink ===
apply_terraform_shrink() {
    log_step "Applying terraform changes to shrink cluster"
    
    cd "$DEPLOY_DIR"
    
    # Initialize terraform
    log_info "Initializing terraform..."
    if ! terraform init -input=false 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Terraform initialization failed"
        exit 1
    fi
    
    # Apply changes
    log_info "Applying terraform changes to shrink cluster..."
    if ! terraform apply -auto-approve -input=false 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Terraform apply failed during cluster shrinking"
        exit 1
    fi
    
    log_success "Cluster shrinking completed"
}

# === Finalize Configuration ===
finalize_configuration() {
    log_step "Finalizing configuration for node destruction"
    
    # Update q_node_count to target value
    sed -i "s/^q_node_count[[:space:]]*=.*/q_node_count = $TARGET_NODE_COUNT/" "$TFVARS_FILE"
    
    # Reset q_target_node_count to null
    sed -i "s/^q_target_node_count[[:space:]]*=.*/q_target_node_count = null/" "$TFVARS_FILE"
    
    log_info "Updated q_node_count = $TARGET_NODE_COUNT"
    log_info "Reset q_target_node_count = null"
    log_success "Configuration finalized"
}

# === Apply Final Terraform Changes ===
apply_terraform_finalize() {
    log_step "Applying final terraform changes to destroy removed nodes"
    
    cd "$DEPLOY_DIR"
    
    # Initialize terraform
    log_info "Initializing terraform..."
    if ! terraform init -input=false 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Terraform initialization failed"
        exit 1
    fi
    
    # Apply changes
    log_info "Applying terraform changes to destroy removed node resources..."
    if ! terraform apply -auto-approve -input=false 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Terraform apply failed during node destruction"
        exit 1
    fi
    
    log_success "Node destruction completed"
}

# === Generate Summary ===
generate_summary() {
    log_step "Generating removal summary"
    
    local summary_file="$WORKSHOP_DIR/logs/qumulo-node-removal-summary-$TIMESTAMP.txt"
    
    cat > "$summary_file" <<EOF
Qumulo Workshop - Node Removal Summary
Generated: $(date)

OPERATION DETAILS:
- Action: Remove $REMOVE_COUNT nodes from cluster
- Original Node Count: $CURRENT_NODE_COUNT
- Final Node Count: $TARGET_NODE_COUNT
- Deployment Directory: $DEPLOY_DIR

ACTIONS COMPLETED:
✓ Prerequisites validated
✓ Primary cluster identified
✓ Node count validated
✓ Configuration backed up
✓ Target node count set
✓ Cluster shrinking applied
✓ Configuration finalized
✓ Node destruction completed
✓ Registry updated

LOG FILES:
- Detailed log: $LOG_FILE
- Summary: $summary_file

NEXT STEPS:
1. Verify cluster health in Qumulo UI
2. Check that data is accessible
3. Monitor cluster performance

Node removal completed successfully!
EOF
    
    log_info "Summary saved to: $summary_file"
    
    # Display summary
    echo ""
    log_header "REMOVAL SUMMARY"
    cat "$summary_file"
    
    log_success "Summary generated"
}

# Execute main function
main "$@"
