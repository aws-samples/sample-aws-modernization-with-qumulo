#!/bin/bash

# Qumulo Workshop - Terraform Deployment Script
# This script deploys a Qumulo cluster using Terraform configurations

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
WORKSHOP_DIR="/home/ssm-user/qumulo-workshop"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
CLUSTER_DESCRIPTION="${2:-}"  # Second parameter is cluster description

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$DEPLOYMENT_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$DEPLOYMENT_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$DEPLOYMENT_LOG"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1" | tee -a "$DEPLOYMENT_LOG"
}

log_header() {
    echo "" | tee -a "$DEPLOYMENT_LOG"
    echo -e "${PURPLE}================================${NC}" | tee -a "$DEPLOYMENT_LOG"
    echo -e "${PURPLE}$1${NC}" | tee -a "$DEPLOYMENT_LOG"
    echo -e "${PURPLE}================================${NC}" | tee -a "$DEPLOYMENT_LOG"
}

# Function to display usage
usage() {
    echo "Usage: $0 <terraform_deployment_directory> [cluster_description]"
    echo ""
    echo "Parameters:"
    echo "  terraform_deployment_directory   Path to the Terraform deployment directory"
    echo "  cluster_description             Optional description for the cluster"
    echo ""
    echo "Example:"
    echo "  $0 /home/ssm-user/qumulo-workshop/terraform_deployment_xyz"
    echo "  $0 /home/ssm-user/qumulo-workshop/terraform_deployment_xyz \"Primary cluster, Single-AZ\""
    echo ""
    exit 1
}

# Function to extract comprehensive cluster information from terraform outputs
extract_cluster_access_info() {
    local terraform_outputs="$1"
    
    # Extract basic information
    CLUSTER_WEB_UI_URL=$(echo "$terraform_outputs" | jq -r '.qumulo_private_url_node1.value // "N/A"')
    CLUSTER_NAME=$(echo "$terraform_outputs" | jq -r '.deployment_unique_name.value // "N/A"')
    
    # Extract floating IPs and determine cluster type
    local floating_ips_raw=$(echo "$terraform_outputs" | jq -r '.qumulo_floating_ips.value // []')
    
    log_info "Raw floating IPs from terraform: $floating_ips_raw"
    
    # Check if floating IPs contain actual IPs or null values
    if echo "$floating_ips_raw" | jq -e '. | type == "array" and length > 0' > /dev/null 2>&1; then
        # Check if the first element is not null or "null"
        local first_ip=$(echo "$floating_ips_raw" | jq -r '.[0] // "null"')
        if [[ "$first_ip" != "null" && "$first_ip" != "" && "$first_ip" != "N/A" ]]; then
            # SAZ deployment with actual floating IPs
            floating_ips_list=$(echo "$floating_ips_raw" | jq -r '. | join(", ")')
            log_info "Detected SAZ deployment with floating IPs: $floating_ips_list"
            
            # For SAZ, extract the custom DNS info
            CLUSTER_NFS_ACCESS=$(echo "$terraform_outputs" | jq -r '.qumulo_private_NFS.value // "N/A"')
            CLUSTER_SMB_ACCESS=$(echo "$terraform_outputs" | jq -r '.qumulo_private_SMB.value // "N/A"')
            CLUSTER_WEB_URL=$(echo "$terraform_outputs" | jq -r '.qumulo_private_url.value // "N/A"')
            CLUSTER_NLB_DNS="N/A"
        else
            # MAZ deployment with NLB
            floating_ips_list="N/A (Multi-AZ uses NLB)"
            log_info "Detected MAZ deployment with NLB"
            
            # For MAZ, extract the NLB DNS info
            CLUSTER_NLB_DNS=$(echo "$terraform_outputs" | jq -r '.qumulo_nlb_dns.value // "N/A"')
            CLUSTER_NFS_ACCESS=$(echo "$terraform_outputs" | jq -r '.qumulo_private_NFS.value // "N/A"')
            CLUSTER_SMB_ACCESS=$(echo "$terraform_outputs" | jq -r '.qumulo_private_SMB.value // "N/A"')
            CLUSTER_WEB_URL=$(echo "$terraform_outputs" | jq -r '.qumulo_private_url.value // "N/A"')
        fi
    else
        # No floating IPs array or empty array
        floating_ips_list="N/A (No floating IPs available)"
        log_info "No floating IPs detected"
        
        # Try to determine if this is MAZ by checking for NLB DNS
        CLUSTER_NLB_DNS=$(echo "$terraform_outputs" | jq -r '.qumulo_nlb_dns.value // "N/A"')
        if [[ "$CLUSTER_NLB_DNS" != "N/A" ]]; then
            # This is MAZ
            CLUSTER_NFS_ACCESS=$(echo "$terraform_outputs" | jq -r '.qumulo_private_NFS.value // "N/A"')
            CLUSTER_SMB_ACCESS=$(echo "$terraform_outputs" | jq -r '.qumulo_private_SMB.value // "N/A"')
            CLUSTER_WEB_URL=$(echo "$terraform_outputs" | jq -r '.qumulo_private_url.value // "N/A"')
        else
            # This is SAZ but no floating IPs
            CLUSTER_NFS_ACCESS=$(echo "$terraform_outputs" | jq -r '.qumulo_private_NFS.value // "N/A"')
            CLUSTER_SMB_ACCESS=$(echo "$terraform_outputs" | jq -r '.qumulo_private_SMB.value // "N/A"')
            CLUSTER_WEB_URL=$(echo "$terraform_outputs" | jq -r '.qumulo_private_url.value // "N/A"')
            CLUSTER_NLB_DNS="N/A"
        fi
    fi
    
    # Extract primary IPs
    CLUSTER_PRIMARY_IPS=$(echo "$terraform_outputs" | jq -r '.qumulo_primary_ips.value | join(", ")')
    
    log_info "Floating IPs: $floating_ips_list"
    log_info "NLB DNS: $CLUSTER_NLB_DNS"
    log_info "Primary IPs: $CLUSTER_PRIMARY_IPS"
    log_info "Cluster Web URL: $CLUSTER_WEB_URL"
    log_info "NFS Access: $CLUSTER_NFS_ACCESS"
    log_info "SMB Access: $CLUSTER_SMB_ACCESS"
}

# Function to validate parameters
validate_parameters() {
    if [ $# -lt 1 ] || [ $# -gt 2 ]; then
        log_error "Invalid number of parameters"
        usage
    fi
    
    DEPLOYMENT_DIR="$1"
    if [ $# -eq 2 ]; then
        CLUSTER_DESCRIPTION="$2"
    fi
    
    if [ ! -d "$DEPLOYMENT_DIR" ]; then
        log_error "Deployment directory does not exist: $DEPLOYMENT_DIR"
        exit 1
    fi
    
    # Extract deployment name from path
    DEPLOYMENT_NAME=$(basename "$DEPLOYMENT_DIR")
    
    # Set up logging
    DEPLOYMENT_LOG="/home/ssm-user/qumulo-workshop/logs/qumulo-deployment-${DEPLOYMENT_NAME}-${TIMESTAMP}.log"
    #DEPLOYMENT_JSON="${WORKSHOP_DIR}/deployment-${DEPLOYMENT_NAME}-${TIMESTAMP}.json"
    DEPLOYMENT_JSON="/home/ssm-user/qumulo-workshop/logs/deployment-${DEPLOYMENT_NAME}-${TIMESTAMP}.json"
    
    log_info "Deployment directory: $DEPLOYMENT_DIR"
    log_info "Deployment name: $DEPLOYMENT_NAME"
    log_info "Cluster description: ${CLUSTER_DESCRIPTION:-\"No description provided\"}"
    log_info "Log file: $DEPLOYMENT_LOG"
    log_info "JSON output: $DEPLOYMENT_JSON"
}

# Function to register cluster DNS
register_cluster_dns() {
    log_step "Registering cluster DNS"
    
    # Get the private hosted zone ID from CloudFormation variables
    local hosted_zone_id=""
    if [[ -f "${WORKSHOP_DIR}/cloudformation-variables.json" ]]; then
        hosted_zone_id=$(jq -r '.PrivateHostedZoneId // ""' "${WORKSHOP_DIR}/cloudformation-variables.json")
        local aws_region=$(jq -r '.AWSRegion // "us-east-1"' "${WORKSHOP_DIR}/cloudformation-variables.json")
    else
        log_error "CloudFormation variables file not found"
        return 1
    fi
    
    if [[ -z "$hosted_zone_id" ]]; then
        log_error "Private hosted zone ID not found in CloudFormation variables"
        return 1
    fi
    
    # Extract actual cluster name from tfvars file
    local actual_cluster_name=""
    local tfvars_file="${DEPLOYMENT_DIR}/terraform.tfvars"
    if [[ -f "$tfvars_file" ]]; then
        # Extract q_cluster_name from tfvars file, excluding comments
        actual_cluster_name=$(grep -v "^[[:space:]]*#" "$tfvars_file" | grep "q_cluster_name" | sed 's/.*=\s*"\([^"]*\)".*/\1/' | tr -d ' ')

        log_info "Extracted cluster name from tfvars: $actual_cluster_name"
    else
        log_warning "terraform.tfvars file not found: $tfvars_file"
    fi
    
    # Fall back to deployment unique name if cluster name extraction failed
    if [[ -z "$actual_cluster_name" || "$actual_cluster_name" == "" ]]; then
        log_warning "Could not extract cluster name from tfvars, using deployment unique name"
        if [[ -f "$DEPLOYMENT_JSON" ]]; then
            actual_cluster_name=$(jq -r '.compute_infrastructure.outputs.deployment_unique_name.value // "unknown"' "$DEPLOYMENT_JSON")
        else
            actual_cluster_name="unknown"
        fi
    fi
    
    # Extract cluster information from deployment JSON
    if [[ ! -f "$DEPLOYMENT_JSON" ]]; then
        log_error "Deployment JSON file not found: $DEPLOYMENT_JSON"
        return 1
    fi
    
    local floating_ips_raw=$(jq -r '.compute_infrastructure.outputs.qumulo_floating_ips.value // []' "$DEPLOYMENT_JSON")
    local nlb_dns=$(jq -r '.compute_infrastructure.outputs.qumulo_nlb_dns.value // ""' "$DEPLOYMENT_JSON")
    local primary_ips=$(jq -r '.compute_infrastructure.outputs.qumulo_primary_ips.value // []' "$DEPLOYMENT_JSON")
    
    log_info "Cluster name: $actual_cluster_name"
    log_info "Hosted zone ID: $hosted_zone_id"
    log_info "AWS region: $aws_region"
    
    # Determine DNS record type and values based on deployment type
    local dns_name="${actual_cluster_name}.qumulo.local"
    local record_type=""
    local record_values=""
    local change_batch=""
    
     # Check for floating IPs (SAZ deployment)
    if echo "$floating_ips_raw" | jq -e '. | type == "array" and length > 0' > /dev/null 2>&1; then
        local first_ip=$(echo "$floating_ips_raw" | jq -r '.[0] // "null"')
        if [[ "$first_ip" != "null" && "$first_ip" != "" && "$first_ip" != "N/A" ]]; then
            # SAZ deployment with floating IPs - create A record with multiple IPs
            log_info "Detected SAZ deployment with floating IPs"
            record_type="A"
           
            # Build resource records array for multiple IPs
            local resource_records=""
            while IFS= read -r ip; do
                if [[ -n "$resource_records" ]]; then
                    resource_records="${resource_records}, "
                fi
                resource_records="${resource_records}{\"Value\": \"$ip\"}"
            done < <(echo "$floating_ips_raw" | jq -r '.[]')
           
            change_batch="{
                \"Changes\": [{
                    \"Action\": \"UPSERT\",
                    \"ResourceRecordSet\": {
                        \"Name\": \"$dns_name\",
                        \"Type\": \"$record_type\",
                        \"TTL\": 60,
                        \"ResourceRecords\": [$resource_records]
                    }
                }]
            }"
           
            log_info "Creating A record for SAZ cluster with floating IPs"
        fi
    fi
    
    # Check for NLB DNS (MAZ deployment)
    if [[ -z "$change_batch" && -n "$nlb_dns" && "$nlb_dns" != "N/A" ]]; then
        log_info "Detected MAZ deployment with NLB"
        record_type="CNAME"
        
        change_batch="{
            \"Changes\": [{
                \"Action\": \"UPSERT\",
                \"ResourceRecordSet\": {
                    \"Name\": \"$dns_name\",
                    \"Type\": \"$record_type\",
                    \"TTL\": 60,
                    \"ResourceRecords\": [{\"Value\": \"$nlb_dns\"}]
                }
            }]
        }"
        
        log_info "Creating CNAME record for MAZ cluster pointing to NLB: $nlb_dns"
    fi
    
    # Check for single node (primary IPs only)
    if [[ -z "$change_batch" ]]; then
        if echo "$primary_ips" | jq -e '. | type == "array" and length > 0' > /dev/null 2>&1; then
            log_info "Detected single node deployment"
            record_type="A"
            local primary_ip=$(echo "$primary_ips" | jq -r '.[0]')
            
            change_batch="{
                \"Changes\": [{
                    \"Action\": \"UPSERT\",
                    \"ResourceRecordSet\": {
                        \"Name\": \"$dns_name\",
                        \"Type\": \"$record_type\",
                        \"TTL\": 60,
                        \"ResourceRecords\": [{\"Value\": \"$primary_ip\"}]
                    }
                }]
            }"
            
            log_info "Creating A record for single node cluster: $primary_ip"
        else
            log_error "No valid IP addresses found for DNS registration"
            return 1
        fi
    fi
    
    # Execute the DNS record creation
    log_info "Registering DNS record: $dns_name ($record_type)"
    
    if aws route53 change-resource-record-sets \
        --hosted-zone-id "$hosted_zone_id" \
        --change-batch "$change_batch" \
        --region "$aws_region" > /dev/null 2>&1; then
        
        log_info "✓ DNS record registered successfully: $dns_name"
        log_info "Participants can now access the cluster at: $dns_name"
        
        # Export the DNS name for use by other functions
        export CLUSTER_DNS_NAME="$dns_name"

        # Update deployment JSON with DNS information
        local temp_json=$(mktemp)
        jq --arg dns_name "$dns_name" \
           --arg record_type "$record_type" \
           --arg cluster_name "$actual_cluster_name" \
           '.dns_registration = {
               "dns_name": $dns_name,
               "record_type": $record_type,
               "cluster_name": $cluster_name,
               "status": "registered"
           }' "$DEPLOYMENT_JSON" > "$temp_json" && mv "$temp_json" "$DEPLOYMENT_JSON"
        
        return 0
    else
        log_error "Failed to register DNS record"
        return 1
    fi
}



# Function to create or update cluster registry
update_cluster_registry() {
    local deployment_name="$1"
    local cluster_description="$2"
    local webui_url="$3"
    local cluster_name="$4"
    local password="$5"
    local nfs_access="$6"
    local smb_access="$7"
    
    local registry_file="${WORKSHOP_DIR}/cluster-access-info.json"
    
    log_step "Updating cluster registry"
    
    # Create registry if it doesn't exist
    if [[ ! -f "$registry_file" ]]; then
        log_info "Creating new cluster registry"
        cat > "$registry_file" << EOF
{
  "clusters": []
}
EOF
    fi
    
    # Check if this deployment already exists (for updates)
    local temp_json=$(mktemp)
    if jq -e --arg deployment "$deployment_name" '.clusters[] | select(.deployment_name == $deployment)' "$registry_file" > /dev/null 2>&1; then
        # Update existing cluster
        log_info "Updating existing cluster: $deployment_name"
        jq --arg deployment "$deployment_name" \
           --arg description "$cluster_description" \
           --arg url "$webui_url" \
           --arg name "$cluster_name" \
           --arg password "$password" \
           --arg dns_name "$CLUSTER_DNS_NAME" \
           --arg nfs_access "$nfs_access" \
           --arg smb_access "$smb_access" \
           --arg timestamp "$(date -Iseconds)" \
           '.clusters = (.clusters | map(
               if .deployment_name == $deployment then
                   .deployment_name = $deployment |
                   .description = $description |
                   .status = "active" |
                   .updated_at = $timestamp |
                   .webui_url = $url |
                   .cluster_name = $name |
                   .username = "admin" |
                   .password = $password |
                   .dns_name = $dns_name |
                   .nfs_access = $nfs_access |
                   .smb_access = $smb_access
               else
                   .
               end
           ))' "$registry_file" > "$temp_json"
    else
        # Add new cluster
        log_info "Adding new cluster: $deployment_name"
        jq --arg deployment "$deployment_name" \
           --arg description "$cluster_description" \
           --arg url "$webui_url" \
           --arg name "$cluster_name" \
           --arg password "$password" \
           --arg dns_name "$CLUSTER_DNS_NAME" \
           --arg nfs_access "$nfs_access" \
           --arg smb_access "$smb_access" \
           --arg timestamp "$(date -Iseconds)" \
           '.clusters += [{
               "deployment_name": $deployment,
               "description": $description,
               "status": "active",
               "created_at": $timestamp,
               "webui_url": $url,
               "cluster_name": $name,
               "username": "admin",
               "password": $password,
               "dns_name": $dns_name,
               "nfs_access": $nfs_access,
               "smb_access": $smb_access
           }]' "$registry_file" > "$temp_json"
    fi
    
    mv "$temp_json" "$registry_file"
    log_info "✓ Cluster registry updated successfully"
}

# Function to generate cluster access text file
generate_cluster_access_info() {
    log_step "Generating cluster access information file"
    
    local registry_file="${WORKSHOP_DIR}/cluster-access-info.json"
    local info_file="${WORKSHOP_DIR}/cluster-access-info.txt"
    
    if [[ ! -f "$registry_file" ]]; then
        log_error "Cluster registry file not found: $registry_file"
        return 1
    fi
    
    # Start building the text file
    cat > "$info_file" << EOF
QUMULO WORKSHOP - CLUSTER ACCESS INFORMATION
Generated: $(date)

EOF
    
    # Get all active clusters
    local active_clusters=$(jq -c '.clusters[] | select(.status == "active")' "$registry_file")
    local active_count=$(echo "$active_clusters" | grep -c . 2>/dev/null || echo 0)
    
    if [[ $active_count -gt 0 ]]; then
        cat >> "$info_file" << EOF
🎯 ACTIVE CLUSTERS

EOF
        
        # List each active cluster with full details
        while IFS= read -r cluster; do
            if [[ -n "$cluster" ]]; then
                local deployment_name=$(echo "$cluster" | jq -r '.deployment_name')
                local description=$(echo "$cluster" | jq -r '.description // "No description provided"')
                local cluster_name=$(echo "$cluster" | jq -r '.cluster_name')
                local webui_url=$(echo "$cluster" | jq -r '.webui_url')
                local password=$(echo "$cluster" | jq -r '.password')
                local dns_name=$(echo "$cluster" | jq -r '.dns_name // "Not registered"')
                local nfs_access=$(echo "$cluster" | jq -r '.nfs_access // "N/A"')
                local smb_access=$(echo "$cluster" | jq -r '.smb_access // "N/A"')
                local created_at=$(echo "$cluster" | jq -r '.created_at')
                
                cat >> "$info_file" << EOF
Deployment: $deployment_name
Description: $description
Cluster Name: $cluster_name
DNS Name: $dns_name
Created: $created_at

🌐 WEB UI ACCESS
Management URL: $webui_url
Username: admin
Password: $password

📁 FILE SHARING ACCESS
NFS Access: $nfs_access
SMB Access: $smb_access

----------------------------------------

EOF
            fi
        done <<< "$active_clusters"
        
        cat >> "$info_file" << EOF
🚀 QUICK ACCESS INSTRUCTIONS
1. RDP to Windows instance (Administrator / $password)
2. Open browser to Management URL listed above
3. Login with admin / password from above
4. For file access, use the NFS/SMB paths shown above

EOF
    else
        cat >> "$info_file" << EOF
🎯 ACTIVE CLUSTERS
No active clusters found.

EOF
    fi
    
    # Add all clusters section including replaced ones
    cat >> "$info_file" << EOF
📋 ALL CLUSTERS (INCLUDING REPLACED)

EOF
    
    # List all clusters with status
    local cluster_count=$(jq '.clusters | length' "$registry_file")
    if [[ $cluster_count -gt 0 ]]; then
        jq -r '.clusters[] | "- \(.deployment_name) - \(.description // "No description") - \(.status) - \(.dns_name // "No DNS")"' "$registry_file" >> "$info_file"
    else
        echo "No clusters deployed yet." >> "$info_file"
    fi
    
    cat >> "$info_file" << EOF

📄 DEPLOYMENT DETAILS
Registry file: $registry_file
Generated: $(date)
EOF
    
    log_info "✓ Cluster access information saved to: $info_file"
}



# Function to get terraform outputs as JSON
get_terraform_outputs_json() {
    local terraform_dir="$1"
    local log_file="$2"
    
    cd "$terraform_dir"
    
    # Try to get JSON outputs directly from terraform
    if terraform output -json > /dev/null 2>&1; then
        terraform output -json
        return 0
    else
        # Fallback: parse the outputs from the log file
        log_warning "Could not get JSON outputs directly, parsing from log file"
        echo "{}"
        return 1
    fi
}

# Function to perform quality checks
quality_checks() {
    log_step "Performing quality checks on Terraform configuration"
    local errors=0
    
    # Check root directory files
    local root_files=(
        "${DEPLOYMENT_DIR}/provider.tf"
        "${DEPLOYMENT_DIR}/terraform.tfvars"
    )
    
    for file in "${root_files[@]}"; do
        if [ -f "$file" ]; then
            log_info "✓ Found: $(basename "$file")"
        else
            log_error "✗ Missing: $file"
            ((errors++))
        fi
    done
    
    # Check persistent storage directory files
    local persistent_storage_dir="${DEPLOYMENT_DIR}/persistent-storage"
    local persistent_files=(
        "${persistent_storage_dir}/provider.tf"
        "${persistent_storage_dir}/terraform.tfvars"
    )
    
    if [ -d "$persistent_storage_dir" ]; then
        log_info "✓ Found: persistent-storage directory"
        for file in "${persistent_files[@]}"; do
            if [ -f "$file" ]; then
                log_info "✓ Found: persistent-storage/$(basename "$file")"
            else
                log_error "✗ Missing: $file"
                ((errors++))
            fi
        done
    else
        log_error "✗ Missing: persistent-storage directory"
        ((errors++))
    fi
    
    # Check Terraform installation
    if command -v terraform &> /dev/null; then
        local tf_version=$(terraform version -json | jq -r '.terraform_version')
        log_info "✓ Terraform installed: v$tf_version"
    else
        log_error "✗ Terraform not found in PATH"
        ((errors++))
    fi
    
    # Check AWS CLI access
    if aws sts get-caller-identity &> /dev/null; then
        local account_id=$(aws sts get-caller-identity --query Account --output text)
        log_info "✓ AWS CLI access verified: Account $account_id"
    else
        log_error "✗ AWS CLI access failed"
        ((errors++))
    fi
    
    if [ $errors -gt 0 ]; then
        log_error "Quality checks failed with $errors errors"
        return 1
    fi
    
    log_info "All quality checks passed successfully"
    return 0
}

# Function to deploy persistent storage
deploy_persistent_storage() {
    log_step "Deploying persistent storage infrastructure"
    local persistent_dir="${DEPLOYMENT_DIR}/persistent-storage"
    local persistent_log="/home/ssm-user/qumulo-workshop/logs/qumulo-persistent-storage-${DEPLOYMENT_NAME}-${TIMESTAMP}.log"
    
    cd "$persistent_dir"
    
    # Initialize Terraform
    log_info "Initializing Terraform for persistent storage..."
    if terraform init 2>&1 | tee "$persistent_log"; then
        log_info "Terraform initialization completed successfully"
    else
        log_error "Terraform initialization failed"
        return 1
    fi
    
    # Plan deployment
    log_info "Planning persistent storage deployment..."
    if terraform plan -out=tfplan 2>&1 | tee -a "$persistent_log"; then
        log_info "Terraform plan completed successfully"
    else
        log_error "Terraform plan failed"
        return 1
    fi
    
    # Apply deployment
    log_info "Applying persistent storage deployment..."
    if terraform apply -auto-approve tfplan 2>&1 | tee -a "$persistent_log"; then
        log_info "Persistent storage deployment completed successfully"
    else
        log_error "Persistent storage deployment failed"
        return 1
    fi
    
    # Capture outputs in JSON format
    log_info "Capturing persistent storage outputs..."
    local persistent_outputs=$(get_terraform_outputs_json "$persistent_dir" "$persistent_log")
    
    # Create initial JSON structure
    cat > "$DEPLOYMENT_JSON" << EOF
{
  "deployment_name": "$DEPLOYMENT_NAME",
  "deployment_timestamp": "$TIMESTAMP",
  "deployment_directory": "$DEPLOYMENT_DIR",
  "persistent_storage": {
    "status": "completed",
    "log_file": "$persistent_log",
    "outputs": $persistent_outputs
  }
}
EOF
    
    log_info "Persistent storage outputs saved to: $DEPLOYMENT_JSON"
    
    # Display key outputs for user
    if echo "$persistent_outputs" | jq -e '.deployment_unique_name.value' > /dev/null 2>&1; then
        local unique_name=$(echo "$persistent_outputs" | jq -r '.deployment_unique_name.value')
        log_info "Deployment unique name: $unique_name"
    fi
    
    if echo "$persistent_outputs" | jq -e '.bucket_names.value' > /dev/null 2>&1; then
        local bucket_count=$(echo "$persistent_outputs" | jq -r '.bucket_names.value | length')
        log_info "Created $bucket_count storage buckets"
    fi
    
    return 0
}

# Function to deploy compute infrastructure
deploy_compute_infrastructure() {
    log_step "Deploying compute infrastructure"
    local compute_log="/home/ssm-user/qumulo-workshop/logs/qumulo-compute-${DEPLOYMENT_NAME}-${TIMESTAMP}.log"
    
    cd "$DEPLOYMENT_DIR"
    
    # Initialize Terraform
    log_info "Initializing Terraform for compute infrastructure..."
    if terraform init 2>&1 | tee "$compute_log"; then
        log_info "Terraform initialization completed successfully"
    else
        log_error "Terraform initialization failed"
        return 1
    fi
    
    # Plan deployment
    log_info "Planning compute infrastructure deployment..."
    if terraform plan -out=tfplan 2>&1 | tee -a "$compute_log"; then
        log_info "Terraform plan completed successfully"
    else
        log_error "Terraform plan failed"
        return 1
    fi
    
    # Apply deployment
    log_info "Applying compute infrastructure deployment..."
    if terraform apply -auto-approve tfplan 2>&1 | tee -a "$compute_log"; then
        log_info "Compute infrastructure deployment completed successfully"
    else
        log_error "Compute infrastructure deployment failed"
        return 1
    fi
    
    # Capture outputs in JSON format
    log_info "Capturing compute infrastructure outputs..."
    local compute_outputs=$(get_terraform_outputs_json "$DEPLOYMENT_DIR" "$compute_log")
    
    # Update JSON with compute outputs
    local temp_json=$(mktemp)
    jq --argjson compute_outputs "$compute_outputs" \
       --arg compute_log "$compute_log" \
       '.compute_infrastructure = {
         "status": "completed",
         "log_file": $compute_log,
         "outputs": $compute_outputs
       }' "$DEPLOYMENT_JSON" > "$temp_json" && mv "$temp_json" "$DEPLOYMENT_JSON"
    
    log_info "Compute infrastructure outputs saved to: $DEPLOYMENT_JSON"
    
    # Display key outputs for user
    if echo "$compute_outputs" | jq -e '.cluster_provisioned.value' > /dev/null 2>&1; then
        local cluster_status=$(echo "$compute_outputs" | jq -r '.cluster_provisioned.value')
        log_info "Cluster provisioned: $cluster_status"
    fi
    
    if echo "$compute_outputs" | jq -e '.qumulo_primary_ips.value' > /dev/null 2>&1; then
        local node_count=$(echo "$compute_outputs" | jq -r '.qumulo_primary_ips.value | length')
        log_info "Created $node_count Qumulo nodes"
    fi
    
    if echo "$compute_outputs" | jq -e '.qumulo_private_url_node1.value' > /dev/null 2>&1; then
        local node1_url=$(echo "$compute_outputs" | jq -r '.qumulo_private_url_node1.value')
        log_info "Primary node URL: $node1_url"
    fi
    
    return 0
}

# Function to create user-friendly cluster info file
create_cluster_info_file() {
    log_step "Creating cluster information files"
    
    # Extract key information from deployment JSON
    if [[ -f "$DEPLOYMENT_JSON" ]]; then
        local primary_url=$(jq -r '.compute_infrastructure.outputs.qumulo_private_url_node1.value // "N/A"' "$DEPLOYMENT_JSON")
        local cluster_name=$(jq -r '.compute_infrastructure.outputs.deployment_unique_name.value // "N/A"' "$DEPLOYMENT_JSON")
        
        # Get the Qumulo password from CloudFormation variables
        local qumulo_password="!Qumulo123"  # Default fallback
        if [[ -f "${WORKSHOP_DIR}/cloudformation-variables.json" ]]; then
            qumulo_password=$(jq -r '.QumuloPassword // "!Qumulo123"' "${WORKSHOP_DIR}/cloudformation-variables.json")
            log_info "Retrieved Qumulo password from CloudFormation variables"
        else
            log_warning "CloudFormation variables file not found, using default password"
        fi
        
        # Build DNS-based URLs if DNS registration was successful
        local cluster_web_url="$primary_url"
        local cluster_nfs_access="N/A"
        local cluster_smb_access="N/A"
        
        if [[ -n "$CLUSTER_DNS_NAME" ]]; then
            cluster_web_url="https://${CLUSTER_DNS_NAME}"
            cluster_nfs_access="${CLUSTER_DNS_NAME}:/NFS Export Name"
            cluster_smb_access="\\\\${CLUSTER_DNS_NAME}\\SMB Share Name"
            log_info "Using DNS-based URLs for cluster access"
        else
            log_warning "DNS name not available, using IP-based URLs"
        fi
        
        # Update the cluster registry with DNS information
        update_cluster_registry "$DEPLOYMENT_NAME" "$CLUSTER_DESCRIPTION" "$cluster_web_url" "$cluster_name" "$qumulo_password" "$cluster_nfs_access" "$cluster_smb_access"
        
        # Generate the text file
        generate_cluster_access_info
        
        # Display the key info on console
        echo ""
        echo ""
        echo "🎉 QUMULO CLUSTER READY!"
        echo ""
        echo "Web UI: $cluster_web_url"
        echo "Login: admin / $qumulo_password"
        if [[ -n "$CLUSTER_DESCRIPTION" ]]; then
            echo "Description: $CLUSTER_DESCRIPTION"
        fi
        echo ""
        echo "DNS Name: ${CLUSTER_DNS_NAME:-"Not registered"}"
        echo ""
        echo "Access information saved to:"
        echo "- JSON: ${WORKSHOP_DIR}/cluster-access-info.json"
        echo "- Text: ${WORKSHOP_DIR}/cluster-access-info.txt"
        echo ""
    else
        log_error "Deployment JSON file not found: $DEPLOYMENT_JSON"
        return 1
    fi
}



# Function to generate deployment summary
generate_deployment_summary() {
    log_step "Generating deployment summary"
    
    # Add summary information to JSON
    local temp_json=$(mktemp)
    jq --arg completion_time "$(date -Iseconds)" \
       '.deployment_summary = {
         "completion_time": $completion_time,
         "status": "success"
       }' "$DEPLOYMENT_JSON" > "$temp_json" && mv "$temp_json" "$DEPLOYMENT_JSON"
    
    # Display summary
    log_header "Deployment Summary"
    echo "Deployment Name: $DEPLOYMENT_NAME"
    echo "Deployment Directory: $DEPLOYMENT_DIR"
    echo "Completion Time: $(date)"
    echo "Log Files:"
    echo "  - Main Log: $DEPLOYMENT_LOG"
    echo "  - Persistent Storage: /home/ssm-user/qumulo-workshop/logs/qumulo-persistent-storage-${DEPLOYMENT_NAME}-${TIMESTAMP}.log"
    echo "  - Compute Infrastructure: /home/ssm-user/qumulo-workshop/logs/qumulo-compute-${DEPLOYMENT_NAME}-${TIMESTAMP}.log"
    echo "JSON Output: $DEPLOYMENT_JSON"
    echo ""
    
    # Extract and display key information from JSON
    if [ -f "$DEPLOYMENT_JSON" ]; then
        echo "Key Deployment Information:"
        
        # Persistent storage info
        if jq -e '.persistent_storage.outputs.deployment_unique_name.value' "$DEPLOYMENT_JSON" > /dev/null 2>&1; then
            local unique_name=$(jq -r '.persistent_storage.outputs.deployment_unique_name.value' "$DEPLOYMENT_JSON")
            echo "  - Unique Name: $unique_name"
        fi
        
        if jq -e '.persistent_storage.outputs.bucket_names.value' "$DEPLOYMENT_JSON" > /dev/null 2>&1; then
            local bucket_count=$(jq -r '.persistent_storage.outputs.bucket_names.value | length' "$DEPLOYMENT_JSON")
            echo "  - Storage Buckets: $bucket_count"
        fi
        
        # Compute info
        if jq -e '.compute_infrastructure.outputs.cluster_provisioned.value' "$DEPLOYMENT_JSON" > /dev/null 2>&1; then
            local cluster_status=$(jq -r '.compute_infrastructure.outputs.cluster_provisioned.value' "$DEPLOYMENT_JSON")
            echo "  - Cluster Status: $cluster_status"
        fi
        
        if jq -e '.compute_infrastructure.outputs.qumulo_primary_ips.value' "$DEPLOYMENT_JSON" > /dev/null 2>&1; then
            local node_count=$(jq -r '.compute_infrastructure.outputs.qumulo_primary_ips.value | length' "$DEPLOYMENT_JSON")
            echo "  - Qumulo Nodes: $node_count"
        fi
        
        if jq -e '.compute_infrastructure.outputs.qumulo_private_url_node1.value' "$DEPLOYMENT_JSON" > /dev/null 2>&1; then
            local primary_url=$(jq -r '.compute_infrastructure.outputs.qumulo_private_url_node1.value' "$DEPLOYMENT_JSON")
            echo "  - Primary Node: $primary_url"
        fi
    fi
    
    echo ""
    log_info "Deployment completed successfully!"
}

# Function to handle deployment failure
handle_deployment_failure() {
    local failed_stage="$1"
    local exit_code="$2"
    
    log_error "Deployment failed at stage: $failed_stage"
    
    # Update JSON with failure information
    if [ -f "$DEPLOYMENT_JSON" ]; then
        local temp_json=$(mktemp)
        jq --arg failed_stage "$failed_stage" \
           --arg failure_time "$(date -Iseconds)" \
           --arg exit_code "$exit_code" \
           '.deployment_summary = {
             "completion_time": $failure_time,
             "status": "failed",
             "failed_stage": $failed_stage,
             "exit_code": $exit_code
           }' "$DEPLOYMENT_JSON" > "$temp_json" && mv "$temp_json" "$DEPLOYMENT_JSON"
    fi
    
    echo ""
    log_header "Deployment Failed"
    echo "Failed Stage: $failed_stage"
    echo "Exit Code: $exit_code"
    echo "Check logs for details:"
    echo "  - Main Log: $DEPLOYMENT_LOG"
    echo "  - JSON Output: $DEPLOYMENT_JSON"
    
    exit "$exit_code"
}

# Main execution function
main() {
    # Step 1: Validate parameters FIRST (before any logging)
    if [ $# -lt 2 ] || [ $# -gt 3 ]; then
        echo "Usage: $0 <terraform_deployment_directory> <cluster_description> [cluster_type]"
        echo ""
        echo "Parameters:"
        echo "  terraform_deployment_directory   Path to the Terraform deployment directory"
        echo "  cluster_description             Description for the cluster"
        echo "  cluster_type                    Optional cluster type (default: single-az)"
        echo ""
        echo "Example:"
        echo "  $0 /home/ssm-user/qumulo-workshop/terraform_deployment_xyz \"Primary cluster\" single-az"
        exit 1
    fi
    
    DEPLOYMENT_DIR="$1"
    CLUSTER_DESCRIPTION="$2"
    CLUSTER_TYPE="${3:-single-az}"  # Default to single-az if not provided
    
    if [ ! -d "$DEPLOYMENT_DIR" ]; then
        echo "ERROR: Deployment directory does not exist: $DEPLOYMENT_DIR"
        exit 1
    fi
    
    # Extract deployment name from path
    DEPLOYMENT_NAME=$(basename "$DEPLOYMENT_DIR")
    
    # Set up logging
    DEPLOYMENT_LOG="/home/ssm-user/qumulo-workshop/logs/qumulo-deployment-${DEPLOYMENT_NAME}-${TIMESTAMP}.log"
    DEPLOYMENT_JSON="/home/ssm-user/qumulo-workshop/logs/deployment-${DEPLOYMENT_NAME}-${TIMESTAMP}.json"
    
    # NOW we can start using the logging functions
    log_header "Qumulo Cluster Deployment"
    log_info "Deployment directory: $DEPLOYMENT_DIR"
    log_info "Deployment name: $DEPLOYMENT_NAME"
    log_info "Cluster description: ${CLUSTER_DESCRIPTION:-\"No description provided\"}"
    log_info "Cluster type: $CLUSTER_TYPE"
    log_info "Log file: $DEPLOYMENT_LOG"
    log_info "JSON output: $DEPLOYMENT_JSON"
    
    # Step 2: Quality checks
    if ! quality_checks; then
        handle_deployment_failure "quality_checks" 1
    fi
    
    # Step 3: Deploy persistent storage
    if ! deploy_persistent_storage; then
        handle_deployment_failure "persistent_storage" 2
    fi
    
    # Step 4: Deploy compute infrastructure
    if ! deploy_compute_infrastructure; then
        handle_deployment_failure "compute_infrastructure" 3
    fi
    
    # Step 5: Register cluster DNS
    if ! register_cluster_dns; then
        log_warning "DNS registration failed, but cluster deployment was successful"
    else
        log_info "DNS registration completed successfully"
    fi

    # Step 6: Generate summary
    generate_deployment_summary
    
    # Step 7: Create user-friendly cluster info
    create_cluster_info_file
}

# Trap to handle script interruption
trap 'handle_deployment_failure "interrupted" 130' INT TERM

# Execute main function
main "$@"
