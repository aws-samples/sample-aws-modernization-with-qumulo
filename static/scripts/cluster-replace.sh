#!/bin/bash

# Qumulo Workshop - Cluster Replacement Script
# This script replaces an existing cluster with a new cluster configuration

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

# set -e # Exit on any error

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

# Function to display usage
usage() {
    echo "Usage: $0 <new_cluster_deployment_directory> [cluster_description]"
    echo ""
    echo "Parameters:"
    echo "  new_cluster_deployment_directory   Path to the new cluster deployment directory"
    echo "  cluster_description               Optional description for the new cluster"
    echo ""
    echo "Example:"
    echo "  $0 /home/ssm-user/qumulo-workshop/terraform_deployment_primary_maz \"Multi-AZ replacement cluster\""
    echo ""
    exit 1
}

# Function to validate parameters
validate_parameters() {
    if [ $# -lt 1 ] || [ $# -gt 2 ]; then
        log_error "Invalid number of parameters"
        usage
    fi
    
    NEW_DEPLOYMENT_DIR="$1"
    NEW_CLUSTER_DESCRIPTION="${2:-Multi-AZ replacement cluster}"
    
    if [ ! -d "$NEW_DEPLOYMENT_DIR" ]; then
        log_error "New deployment directory does not exist: $NEW_DEPLOYMENT_DIR"
        exit 1
    fi
    
    # Extract deployment name from path
    NEW_DEPLOYMENT_NAME=$(basename "$NEW_DEPLOYMENT_DIR")
    
    # Set up logging
    REPLACEMENT_LOG="/home/ssm-user/qumulo-workshop/logs/qumulo-cluster-replacement-${NEW_DEPLOYMENT_NAME}-${TIMESTAMP}.log"
    
    log_info "New deployment directory: $NEW_DEPLOYMENT_DIR"
    log_info "New deployment name: $NEW_DEPLOYMENT_NAME"
    log_info "New cluster description: $NEW_CLUSTER_DESCRIPTION"
    log_info "Log file: $REPLACEMENT_LOG"
}

# Function to get existing cluster info from terraform.tfvars
get_existing_cluster_info() {
    log_step "Getting existing cluster information from terraform.tfvars"
    
    local tfvars_file="${NEW_DEPLOYMENT_DIR}/terraform.tfvars"
    
    if [[ ! -f "$tfvars_file" ]]; then
        log_error "terraform.tfvars file not found: $tfvars_file"
        exit 1
    fi
    
    # Extract q_existing_deployment_unique_name from tfvars
    EXISTING_CLUSTER_NAME=$(grep "^q_existing_deployment_unique_name" "$tfvars_file" | sed 's/.*=\s*"\([^"]*\)".*/\1/')
    
    if [[ -z "$EXISTING_CLUSTER_NAME" || "$EXISTING_CLUSTER_NAME" == "null" ]]; then
        log_error "Could not find q_existing_deployment_unique_name in terraform.tfvars"
        log_error "This script requires a replacement cluster configuration"
        exit 1
    fi
    
    log_info "Existing cluster name to replace: $EXISTING_CLUSTER_NAME"
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



# Function to find existing cluster deployment directory from registry
find_existing_cluster_deployment() {
    log_step "Finding existing cluster deployment directory from registry"
    
    local registry_file="${WORKSHOP_DIR}/cluster-access-info.json"
    
    if [[ ! -f "$registry_file" ]]; then
        log_error "Cluster registry file not found: $registry_file"
        exit 1
    fi
    
    # Find the deployment directory for the existing cluster
    EXISTING_DEPLOYMENT_NAME=$(jq -r --arg cluster_name "$EXISTING_CLUSTER_NAME" \
                              '.clusters[] | select(.cluster_name == $cluster_name and .status == "active") | .deployment_name' \
                              "$registry_file")
    
    if [[ -z "$EXISTING_DEPLOYMENT_NAME" || "$EXISTING_DEPLOYMENT_NAME" == "null" ]]; then
        log_error "Could not find active cluster with name: $EXISTING_CLUSTER_NAME"
        log_error "Available clusters:"
        jq -r '.clusters[] | "- \(.cluster_name) (\(.deployment_name)) - \(.status)"' "$registry_file" | tee -a "$REPLACEMENT_LOG"
        exit 1
    fi
    
    EXISTING_DEPLOYMENT_DIR="${WORKSHOP_DIR}/${EXISTING_DEPLOYMENT_NAME}"
    
    if [[ ! -d "$EXISTING_DEPLOYMENT_DIR" ]]; then
        log_error "Existing deployment directory not found: $EXISTING_DEPLOYMENT_DIR"
        exit 1
    fi
    
    log_info "Existing deployment name: $EXISTING_DEPLOYMENT_NAME"
    log_info "Existing deployment directory: $EXISTING_DEPLOYMENT_DIR"
}

# Function to deploy new cluster
deploy_new_cluster() {
    log_step "Deploying new cluster"
    
    cd "$NEW_DEPLOYMENT_DIR"
    
    # Initialize Terraform
    log_info "Initializing Terraform for new cluster..."
    if terraform init 2>&1 | tee -a "$REPLACEMENT_LOG"; then
        log_info "Terraform initialization completed successfully"
    else
        log_error "Terraform initialization failed"
        return 1
    fi
    
    # Apply deployment
    log_info "Applying new cluster deployment..."
    if terraform apply -auto-approve 2>&1 | tee -a "$REPLACEMENT_LOG"; then
        log_info "New cluster deployment completed successfully"
    else
        log_error "New cluster deployment failed"
        return 1
    fi
    
    return 0
}

# Function to register cluster DNS
register_cluster_dns() {
    log_step "Registering cluster DNS for replacement"
    
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
    local tfvars_file="${NEW_DEPLOYMENT_DIR}/terraform.tfvars"
    if [[ -f "$tfvars_file" ]]; then
        # Extract q_cluster_name from tfvars file, excluding comments
        actual_cluster_name=$(grep -v "^[[:space:]]*#" "$tfvars_file" | grep "^[[:space:]]*q_cluster_name[[:space:]]*=" | sed 's/.*=\s*"\([^"]*\)".*/\1/' | tr -d ' ')
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
    
    local dns_name="${actual_cluster_name}.qumulo.local"
    
    # First, check if there are existing DNS records and delete them
    log_info "Checking for existing DNS records for: $dns_name"
    local existing_records
    if existing_records=$(aws route53 list-resource-record-sets \
        --hosted-zone-id "$hosted_zone_id" \
        --query "ResourceRecordSets[?Name=='${dns_name}.']" \
        --region "$aws_region" 2>&1); then
        
        local record_count=$(echo "$existing_records" | jq '. | length')
        if [[ "$record_count" -gt 0 ]]; then
            log_info "Found $record_count existing DNS record(s), deleting them first"
            
            # Delete each existing record
            while IFS= read -r record; do
                if [[ -n "$record" ]]; then
                    local existing_type=$(echo "$record" | jq -r '.Type')
                    local existing_ttl=$(echo "$record" | jq -r '.TTL // 300')
                    local existing_resources=$(echo "$record" | jq -c '.ResourceRecords // []')
                    local existing_alias=$(echo "$record" | jq -c '.AliasTarget // null')
                    
                    # Skip SOA and NS records
                    if [[ "$existing_type" == "SOA" || "$existing_type" == "NS" ]]; then
                        continue
                    fi
                    
                    log_info "Deleting existing $existing_type record"
                    
                    local delete_batch=""
                    if [[ "$existing_alias" != "null" ]]; then
                        # Handle alias records
                        delete_batch="{
                            \"Changes\": [{
                                \"Action\": \"DELETE\",
                                \"ResourceRecordSet\": {
                                    \"Name\": \"$dns_name\",
                                    \"Type\": \"$existing_type\",
                                    \"AliasTarget\": $existing_alias
                                }
                            }]
                        }"
                    else
                        # Handle regular records
                        delete_batch="{
                            \"Changes\": [{
                                \"Action\": \"DELETE\",
                                \"ResourceRecordSet\": {
                                    \"Name\": \"$dns_name\",
                                    \"Type\": \"$existing_type\",
                                    \"TTL\": $existing_ttl,
                                    \"ResourceRecords\": $existing_resources
                                }
                            }]
                        }"
                    fi
                    
                    # Execute the delete
                    local delete_output
                    if delete_output=$(aws route53 change-resource-record-sets \
                        --hosted-zone-id "$hosted_zone_id" \
                        --change-batch "$delete_batch" \
                        --region "$aws_region" 2>&1); then
                        log_info "✓ Deleted existing $existing_type record"
                    else
                        log_warning "Failed to delete existing $existing_type record: $delete_output"
                    fi
                fi
            done <<< "$(echo "$existing_records" | jq -c '.[]')"
            
            # Wait a moment for deletion to propagate
            log_info "Waiting 5 seconds for DNS deletion to propagate..."
            sleep 5
        else
            log_info "No existing DNS records found"
        fi
    else
        log_warning "Could not check for existing DNS records: $existing_records"
    fi
    
    # Get cluster information from terraform outputs
    cd "$NEW_DEPLOYMENT_DIR"
    local new_cluster_outputs=$(terraform output -json 2>/dev/null || echo "{}")
    
    local floating_ips_raw=$(echo "$new_cluster_outputs" | jq -r '.qumulo_floating_ips.value // []')
    local nlb_dns=$(echo "$new_cluster_outputs" | jq -r '.qumulo_nlb_dns.value // ""')
    local primary_ips=$(echo "$new_cluster_outputs" | jq -r '.qumulo_primary_ips.value // []')
    
    log_info "Cluster name: $actual_cluster_name"
    log_info "Hosted zone ID: $hosted_zone_id"
    log_info "AWS region: $aws_region"
    
    # Determine DNS record type and values based on deployment type
    local record_type=""
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
                    \"Action\": \"CREATE\",
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
                \"Action\": \"CREATE\",
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
                    \"Action\": \"CREATE\",
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
    log_info "Creating new DNS record: $dns_name ($record_type)"
    
    # Capture AWS CLI output for debugging
    local aws_output
    if aws_output=$(aws route53 change-resource-record-sets \
        --hosted-zone-id "$hosted_zone_id" \
        --change-batch "$change_batch" \
        --region "$aws_region" 2>&1); then
        
        log_info "✓ DNS record registered successfully: $dns_name"
        log_info "Participants can now access the cluster at: $dns_name"
        
        # Export the DNS name for use by other functions
        export CLUSTER_DNS_NAME="$dns_name"
        
        return 0
    else
        local aws_exit_code=$?
        log_error "Failed to register DNS record"
        log_error "AWS CLI exit code: $aws_exit_code"
        log_error "AWS CLI output: $aws_output"
        return 1
    fi
}



# Function to update cluster registry with new cluster and mark old as replaced
update_cluster_registry() {
    log_step "Updating cluster registry"
    
    local registry_file="${WORKSHOP_DIR}/cluster-access-info.json"
    
    # Get new cluster information from terraform outputs
    cd "$NEW_DEPLOYMENT_DIR"
    local new_cluster_outputs=$(terraform output -json 2>/dev/null || echo "{}")
    
    # Extract comprehensive cluster information
    extract_cluster_access_info "$new_cluster_outputs"
    
    local new_webui_url="$CLUSTER_WEB_UI_URL"
    local new_cluster_name="$CLUSTER_NAME"
    
    # Build DNS-based URLs if DNS registration was successful
    local cluster_web_url="$new_webui_url"
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
    
    # Get password from CloudFormation variables
    local qumulo_password="!Qumulo123"
    if [[ -f "${WORKSHOP_DIR}/cloudformation-variables.json" ]]; then
        qumulo_password=$(jq -r '.QumuloPassword // "!Qumulo123"' "${WORKSHOP_DIR}/cloudformation-variables.json")
    fi
    
    # Update registry - mark old cluster as replaced and add new cluster
    local temp_json=$(mktemp)
    
    # First mark the old cluster as replaced - Use EXISTING_DEPLOYMENT_NAME
    log_info "Marking existing deployment as replaced: $EXISTING_DEPLOYMENT_NAME"
    jq --arg source_deployment "$EXISTING_DEPLOYMENT_NAME" \
       --arg timestamp "$(date -Iseconds)" \
       --arg new_deployment "$NEW_DEPLOYMENT_NAME" \
       '(.clusters[] | select(.deployment_name == $source_deployment)) |= (. + {
           status: "replaced",
           replaced_at: $timestamp,
           replaced_by: $new_deployment
       })' \
       "$registry_file" > "$temp_json"
    
    # Then add the new cluster with comprehensive information
    jq --arg deployment "$NEW_DEPLOYMENT_NAME" \
       --arg description "$NEW_CLUSTER_DESCRIPTION" \
       --arg url "$cluster_web_url" \
       --arg name "$new_cluster_name" \
       --arg password "$qumulo_password" \
       --arg dns_name "$CLUSTER_DNS_NAME" \
       --arg nfs_access "$cluster_nfs_access" \
       --arg smb_access "$cluster_smb_access" \
       --arg timestamp "$(date -Iseconds)" \
       '.clusters += [{
           deployment_name: $deployment,
           description: $description,
           status: "active",
           created_at: $timestamp,
           webui_url: $url,
           cluster_name: $name,
           username: "admin",
           password: $password,
           dns_name: $dns_name,
           nfs_access: $nfs_access,
           smb_access: $smb_access
       }]' \
       "$temp_json" > "${temp_json}.2"
    
    mv "${temp_json}.2" "$registry_file"
    rm -f "$temp_json"
    
    log_info "Cluster registry updated successfully"
    
    # Update the text file
    generate_cluster_access_info
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

🎯 ACTIVE CLUSTERS

EOF
    
    # Get active clusters and display details
    local active_clusters=$(jq -c '.clusters[] | select(.status == "active")' "$registry_file")
    local active_count=$(echo "$active_clusters" | grep -c . 2>/dev/null || echo 0)
    
    if [[ $active_count -gt 0 ]]; then
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


# Function to destroy old cluster
destroy_old_cluster() {
    log_step "Destroying old cluster infrastructure"
    
    cd "$EXISTING_DEPLOYMENT_DIR"
    
    # Initialize Terraform (in case state is stale)
    log_info "Initializing Terraform for existing cluster..."
    if terraform init 2>&1 | tee -a "$REPLACEMENT_LOG"; then
        log_info "Terraform initialization completed successfully"
    else
        log_error "Terraform initialization failed"
        return 1
    fi
    
    # Destroy infrastructure
    log_info "Destroying existing cluster infrastructure..."
    if terraform destroy -auto-approve 2>&1 | tee -a "$REPLACEMENT_LOG"; then
        log_info "Old cluster destruction completed successfully"
    else
        log_error "Old cluster destruction failed"
        return 1
    fi
    
    return 0
}

# Function to finalize new cluster configuration
finalize_new_cluster() {
    log_step "Finalizing new cluster configuration"
    
    cd "$NEW_DEPLOYMENT_DIR"
    
    # Update terraform.tfvars to set q_replacement_cluster = false
    local tfvars_file="${NEW_DEPLOYMENT_DIR}/terraform.tfvars"
    
    log_info "Setting q_replacement_cluster = false in terraform.tfvars"
    sed -i 's/^q_replacement_cluster[[:space:]]*=.*/q_replacement_cluster = false/' "$tfvars_file"
    
    # Initialize and apply finalization
    log_info "Initializing Terraform for finalization..."
    if terraform init 2>&1 | tee -a "$REPLACEMENT_LOG"; then
        log_info "Terraform initialization completed successfully"
    else
        log_error "Terraform initialization failed"
        return 1
    fi
    
    log_info "Applying cluster finalization..."
    if terraform apply -auto-approve 2>&1 | tee -a "$REPLACEMENT_LOG"; then
        log_info "Cluster finalization completed successfully"
    else
        log_error "Cluster finalization failed"
        return 1
    fi
    
    return 0
}

# Function to cleanup old deployment directory
cleanup_old_deployment() {
    log_step "Cleaning up old deployment directory"
    
    if [[ -d "$EXISTING_DEPLOYMENT_DIR" ]]; then
        log_info "Removing old deployment directory: $EXISTING_DEPLOYMENT_DIR"
        rm -rf "$EXISTING_DEPLOYMENT_DIR"
        log_info "Old deployment directory removed successfully"
    else
        log_warning "Old deployment directory not found: $EXISTING_DEPLOYMENT_DIR"
    fi
}

# Function to display replacement summary
display_replacement_summary() {
    log_step "Cluster Replacement Summary"
    
    echo ""
    echo "========================================="
    echo "CLUSTER REPLACEMENT COMPLETED SUCCESSFULLY"
    echo "========================================="
    echo "Old Cluster:"
    echo "  - Name: $EXISTING_CLUSTER_NAME"
    echo "  - Deployment: $EXISTING_DEPLOYMENT_NAME"
    echo "  - Status: DESTROYED and REMOVED"
    echo ""
    echo "New Cluster:"
    echo "  - Deployment: $NEW_DEPLOYMENT_NAME"
    echo "  - Directory: $NEW_DEPLOYMENT_DIR"
    echo "  - Description: $NEW_CLUSTER_DESCRIPTION"
    echo "  - Status: ACTIVE and FINALIZED"
    echo ""
    echo "Operations Completed:"
    echo "  ✓ Deployed new cluster"
    echo "  ✓ Updated cluster registry"
    echo "  ✓ Updated cluster access information"
    echo "  ✓ Destroyed old cluster infrastructure"
    echo "  ✓ Finalized new cluster configuration"
    echo "  ✓ Removed old deployment directory"
    echo ""
    echo "Access Information:"
    echo "  - JSON Registry: ${WORKSHOP_DIR}/cluster-access-info.json"
    echo "  - Text File: ${WORKSHOP_DIR}/cluster-access-info.txt"
    echo ""
    echo "Cluster replacement completed successfully!"
    echo "========================================="
    echo ""
}

# Function to handle script failure
handle_failure() {
    local exit_code="$1"
    local failed_step="$2"
    
    log_error "Cluster replacement failed at step: $failed_step"
    log_error "Exit code: $exit_code"
    
    echo ""
    echo "========================================="
    echo "CLUSTER REPLACEMENT FAILED"
    echo "========================================="
    echo "Failed step: $failed_step"
    echo "Exit code: $exit_code"
    echo ""
    echo "Check log file: $REPLACEMENT_LOG"
    echo ""
    echo "IMPORTANT: Manual cleanup may be required!"
    echo "- Check if new cluster was partially deployed"
    echo "- Verify old cluster status"
    echo "- Review cluster registry for inconsistencies"
    echo "========================================="
    
    exit "$exit_code"
}

# Main execution function
main() {
    # Step 1: Validate parameters
    validate_parameters "$@"
    
    log_header "Qumulo Cluster Replacement Execution"
    log_info "Starting cluster replacement process"
    log_warning "This will replace an existing cluster with a new configuration"
    
    # Step 2: Get existing cluster info from terraform.tfvars
    get_existing_cluster_info || handle_failure 2 "get_existing_cluster_info"
    
    # Step 3: Find existing cluster deployment directory
    find_existing_cluster_deployment || handle_failure 3 "find_existing_cluster_deployment"
    
    # Step 4: Deploy new cluster
    deploy_new_cluster || handle_failure 4 "deploy_new_cluster"
    
    # Step 5: Register cluster DNS and restart load testing if running
    if ! register_cluster_dns; then
        log_warning "DNS registration failed, but cluster deployment was successful"
    else
        log_info "DNS registration completed successfully"
    fi

    log_info "Restarting load testing with new cluster DNS"

    # Stop current load testing (this will also unmount)
    log_info "Stopping current load testing..."
    if $WORKSHOP_DIR/scripts/start-load-testing.sh stop; then
        log_info "Load testing stopped successfully"
    else
        log_warning "Load testing stop may have failed, continuing..."
    fi

    # Wait for DNS propagation (your TTL is 60 seconds)
    log_info "Waiting 60 seconds for DNS propagation..."
    sleep 60

    # Start load testing with new DNS resolution
    log_info "Starting load testing with new cluster..."
    if $WORKSHOP_DIR/scripts/start-load-testing.sh start; then
        log_info "Load testing restarted successfully with new cluster"
    else
        log_error "Failed to restart load testing"
    fi

    # Step 6: Update cluster registry
    update_cluster_registry || handle_failure 5 "update_cluster_registry"
    
    # Step 7: Destroy old cluster
    destroy_old_cluster || handle_failure 6 "destroy_old_cluster"
    
    # Step 8: Finalize new cluster
    finalize_new_cluster || handle_failure 7 "finalize_new_cluster"
    
    # Step 9: Cleanup old deployment directory
    cleanup_old_deployment || handle_failure 8 "cleanup_old_deployment"
    
    # Step 10: Display summary
    display_replacement_summary
    
    log_header "Cluster Replacement Complete"
    log_info "All replacement operations completed successfully"
    log_info "New cluster is active and ready for use"
}

# Trap to handle script interruption
trap 'handle_failure 130 "script_interrupted"' INT TERM

# Execute main function
main "$@"
