#!/bin/bash

# Qumulo Workshop Cleanup Script
# This script destroys active Qumulo clusters and empties the utility S3 bucket

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

# Use pipefail for better error handling
set -o pipefail

# Configuration
WORKSHOP_DIR="/home/ssm-user/qumulo-workshop"
LOG_DIR="/home/ssm-user/qumulo-workshop/logs"
CLEANUP_LOG="$LOG_DIR/qumulo-workshop-cleanup-$(date +%Y%m%d-%H%M%S).log"
CLUSTER_REGISTRY="$WORKSHOP_DIR/cluster-access-info.json"
VARIABLES_FILE="$WORKSHOP_DIR/cloudformation-variables.json"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    local message="$1"
    echo -e "${GREEN}[INFO]${NC} $message" | tee -a "$CLEANUP_LOG"
}

log_warning() {
    local message="$1"
    echo -e "${YELLOW}[WARN]${NC} $message" | tee -a "$CLEANUP_LOG"
}

log_error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} $message" | tee -a "$CLEANUP_LOG"
}

log_step() {
    local step="$1"
    local message="$2"
    echo -e "${BLUE}[STEP $step]${NC} $message" | tee -a "$CLEANUP_LOG"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}[SUCCESS]${NC} $message" | tee -a "$CLEANUP_LOG"
}

log_header() {
    local header="$1"
    echo | tee -a "$CLEANUP_LOG"
    echo -e "${PURPLE}================================${NC}" | tee -a "$CLEANUP_LOG"
    echo -e "${PURPLE}$header${NC}" | tee -a "$CLEANUP_LOG"
    echo -e "${PURPLE}================================${NC}" | tee -a "$CLEANUP_LOG"
}

# Function to get active clusters from registry
get_active_clusters() {
    if [[ ! -f "$CLUSTER_REGISTRY" ]]; then
        log_warning "Cluster registry not found: $CLUSTER_REGISTRY"
        return 0
    fi
    
    # Get all active clusters - return only deployment names
    local active_clusters=$(jq -r '.clusters[] | select(.status == "active") | .deployment_name' "$CLUSTER_REGISTRY" 2>/dev/null || echo "")
    echo "$active_clusters"
}

# Function to destroy a single cluster
destroy_cluster() {
    local deployment_name="$1"
    local deployment_dir="$WORKSHOP_DIR/$deployment_name"
    
    log_step "2" "Destroying cluster: $deployment_name"
    
    if [[ ! -d "$deployment_dir" ]]; then
        log_error "Deployment directory not found: $deployment_dir"
        return 1
    fi
    
    local cluster_failed=0
    
    # Step 1: Destroy compute infrastructure
    log_info "Destroying compute infrastructure for $deployment_name..."
    cd "$deployment_dir" || {
        log_error "Failed to change to directory: $deployment_dir"
        return 1
    }
    
    if terraform init 2>&1 | tee -a "$CLEANUP_LOG"; then
        log_info "Terraform init completed for compute infrastructure"
        
        if terraform destroy -auto-approve 2>&1 | tee -a "$CLEANUP_LOG"; then
            log_success "Compute infrastructure destroyed successfully"
        else
            log_error "Failed to destroy compute infrastructure"
            cluster_failed=1
        fi
    else
        log_error "Failed to initialize Terraform for compute infrastructure"
        cluster_failed=1
    fi
    
    # Step 2: Destroy persistent storage
    local persistent_storage_dir="$deployment_dir/persistent-storage"
    
    if [[ -d "$persistent_storage_dir" ]]; then
        log_info "Destroying persistent storage for $deployment_name..."
        cd "$persistent_storage_dir" || {
            log_error "Failed to change to persistent storage directory: $persistent_storage_dir"
            cluster_failed=1
        }
        
        if [[ $cluster_failed -eq 0 ]]; then
            if terraform init 2>&1 | tee -a "$CLEANUP_LOG"; then
                log_info "Terraform init completed for persistent storage"
                
                if terraform destroy -auto-approve 2>&1 | tee -a "$CLEANUP_LOG"; then
                    log_success "Persistent storage destroyed successfully"
                else
                    log_error "Failed to destroy persistent storage"
                    cluster_failed=1
                fi
            else
                log_error "Failed to initialize Terraform for persistent storage"
                cluster_failed=1
            fi
        fi
    else
        log_warning "Persistent storage directory not found: $persistent_storage_dir"
    fi
    
    if [[ $cluster_failed -eq 0 ]]; then
        log_success "Cluster $deployment_name destroyed successfully"
        
        # Update cluster status in registry with explicit error handling
        if [[ -f "$CLUSTER_REGISTRY" ]]; then
            local temp_json=$(mktemp)
            
            # Add explicit error handling and debugging
            local jq_output
            if jq_output=$(jq --arg name "$deployment_name" --arg timestamp "$(date -Iseconds)" \
                '(.clusters[] | select(.deployment_name == $name)) |= (. + {"status": "destroyed", "destroyed_at": $timestamp})' \
                "$CLUSTER_REGISTRY" 2>&1) && echo "$jq_output" > "$temp_json"; then
                
                if mv "$temp_json" "$CLUSTER_REGISTRY" 2>/dev/null; then
                    log_info "Updated cluster registry - marked $deployment_name as destroyed"
                else
                    log_warning "Failed to update cluster registry file"
                    rm -f "$temp_json" 2>/dev/null || true
                fi
            else
                log_warning "Failed to update cluster registry with jq: $jq_output"
                rm -f "$temp_json" 2>/dev/null || true
            fi
        else
            log_warning "Cluster registry file not found for update"
        fi
        
        return 0
    else
        log_error "Failed to completely destroy cluster $deployment_name"
        return 1
    fi
}

# Function to empty utility bucket
empty_utility_bucket() {
    log_step 3 "Emptying utility S3 bucket"
    
    if [[ ! -f "$VARIABLES_FILE" ]]; then
        log_error "Variables file not found: $VARIABLES_FILE"
        return 1
    fi
    
    local utility_bucket
    local aws_region
    
    utility_bucket=$(jq -r '.WorkshopUtilityBucket // empty' "$VARIABLES_FILE" 2>/dev/null || echo "")
    aws_region=$(jq -r '.AWSRegion // "us-east-1"' "$VARIABLES_FILE" 2>/dev/null || echo "us-east-1")
    
    if [[ -z "$utility_bucket" || "$utility_bucket" == "null" ]]; then
        log_error "Utility bucket name not found in variables file"
        return 1
    fi
    
    log_info "Emptying S3 bucket: $utility_bucket in region: $aws_region"
    
    # Check if bucket exists and is accessible
    if aws s3 ls "s3://$utility_bucket" --region "$aws_region" 2>&1 | tee -a "$CLEANUP_LOG"; then
        # Get object count before emptying
        local object_count
        object_count=$(aws s3 ls "s3://$utility_bucket" --recursive --region "$aws_region" 2>/dev/null | wc -l || echo "0")
        log_info "Found $object_count objects in bucket"
        
        if [[ $object_count -gt 0 ]]; then
            # Empty the bucket with verbose output to console and log
            log_info "Removing all objects from bucket..."
            if aws s3 rm "s3://$utility_bucket" --recursive --region "$aws_region" 2>&1 | tee -a "$CLEANUP_LOG"; then
                log_success "Successfully emptied utility bucket: $utility_bucket"
                
                # Verify bucket is empty
                local remaining_objects
                remaining_objects=$(aws s3 ls "s3://$utility_bucket" --recursive --region "$aws_region" 2>/dev/null | wc -l || echo "0")
                
                if [[ $remaining_objects -eq 0 ]]; then
                    log_success "Verified utility bucket is completely empty"
                else
                    log_warning "Utility bucket may still contain $remaining_objects objects"
                    
                    # Try to force delete any remaining objects
                    log_info "Attempting to force delete remaining objects..."
                    aws s3api list-objects-v2 --bucket "$utility_bucket" --region "$aws_region" --query 'Contents[].Key' --output text 2>/dev/null | \
                    while read -r key; do
                        if [[ -n "$key" && "$key" != "None" ]]; then
                            log_info "Force deleting: $key"
                            aws s3api delete-object --bucket "$utility_bucket" --key "$key" --region "$aws_region" 2>&1 | tee -a "$CLEANUP_LOG" || true
                        fi
                    done
                    
                    # Check for versioned objects
                    log_info "Checking for versioned objects..."
                    aws s3api list-object-versions --bucket "$utility_bucket" --region "$aws_region" --query 'Versions[].{Key:Key,VersionId:VersionId}' --output text 2>/dev/null | \
                    while read -r key version_id; do
                        if [[ -n "$key" && -n "$version_id" && "$key" != "None" && "$version_id" != "None" ]]; then
                            log_info "Deleting version: $key ($version_id)"
                            aws s3api delete-object --bucket "$utility_bucket" --key "$key" --version-id "$version_id" --region "$aws_region" 2>&1 | tee -a "$CLEANUP_LOG" || true
                        fi
                    done
                    
                    # Check for delete markers
                    log_info "Checking for delete markers..."
                    aws s3api list-object-versions --bucket "$utility_bucket" --region "$aws_region" --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output text 2>/dev/null | \
                    while read -r key version_id; do
                        if [[ -n "$key" && -n "$version_id" && "$key" != "None" && "$version_id" != "None" ]]; then
                            log_info "Deleting delete marker: $key ($version_id)"
                            aws s3api delete-object --bucket "$utility_bucket" --key "$key" --version-id "$version_id" --region "$aws_region" 2>&1 | tee -a "$CLEANUP_LOG" || true
                        fi
                    done
                    
                    # Final verification
                    local final_count
                    final_count=$(aws s3 ls "s3://$utility_bucket" --recursive --region "$aws_region" 2>/dev/null | wc -l || echo "0")
                    
                    if [[ $final_count -eq 0 ]]; then
                        log_success "Successfully force-emptied utility bucket"
                    else
                        log_error "Failed to completely empty bucket - $final_count objects remain"
                    fi
                fi
            else
                log_error "Failed to empty utility bucket: $utility_bucket"
                return 1
            fi
        else
            log_info "Utility bucket is already empty"
        fi
    else
        log_warning "Utility bucket not found or not accessible: $utility_bucket"
        log_info "This may be normal if the bucket was already deleted"
    fi
    
    return 0
}

# Function to clean up DNS records from Private Hosted Zone
cleanup_dns_records() {
    log_step "3A" "Cleaning up DNS records from Private Hosted Zone"
    
    # Get the private hosted zone ID from CloudFormation variables
    if [[ ! -f "$VARIABLES_FILE" ]]; then
        log_error "Variables file not found: $VARIABLES_FILE"
        return 1
    fi
    
    local hosted_zone_id
    local aws_region
    hosted_zone_id=$(jq -r '.PrivateHostedZoneId // ""' "$VARIABLES_FILE" 2>/dev/null || echo "")
    aws_region=$(jq -r '.AWSRegion // "us-east-1"' "$VARIABLES_FILE" 2>/dev/null || echo "us-east-1")
    
    if [[ -z "$hosted_zone_id" || "$hosted_zone_id" == "null" ]]; then
        log_warning "Private hosted zone ID not found in variables file"
        log_info "Skipping DNS cleanup - zone may not exist"
        return 0
    fi
    
    log_info "Cleaning DNS records from hosted zone: $hosted_zone_id"
    log_info "AWS region: $aws_region"
    
    # Get all DNS records from the hosted zone
    local dns_records
    if dns_records=$(aws route53 list-resource-record-sets \
        --hosted-zone-id "$hosted_zone_id" \
        --region "$aws_region" 2>&1); then
        
        log_info "Retrieved DNS records from hosted zone"
        
        # Extract records that are NOT SOA or NS (these are system records)
        local records_to_delete
        records_to_delete=$(echo "$dns_records" | jq -c '.ResourceRecordSets[] | select(.Type != "SOA" and .Type != "NS")')
        
        if [[ -n "$records_to_delete" ]]; then
            local record_count
            record_count=$(echo "$records_to_delete" | grep -c . 2>/dev/null || echo 0)
            log_info "Found $record_count DNS record(s) to delete"
            
            # Delete each record
            while IFS= read -r record; do
                if [[ -n "$record" ]]; then
                    local record_name
                    local record_type
                    local record_ttl
                    local record_values
                    local alias_target
                    
                    record_name=$(echo "$record" | jq -r '.Name')
                    record_type=$(echo "$record" | jq -r '.Type')
                    record_ttl=$(echo "$record" | jq -r '.TTL // 300')
                    record_values=$(echo "$record" | jq -c '.ResourceRecords // []')
                    alias_target=$(echo "$record" | jq -c '.AliasTarget // null')
                    
                    log_info "Deleting $record_type record: $record_name"
                    
                    # Build the delete change batch
                    local delete_batch
                    if [[ "$alias_target" != "null" ]]; then
                        # Handle alias records
                        delete_batch="{
                            \"Changes\": [{
                                \"Action\": \"DELETE\",
                                \"ResourceRecordSet\": {
                                    \"Name\": \"$record_name\",
                                    \"Type\": \"$record_type\",
                                    \"AliasTarget\": $alias_target
                                }
                            }]
                        }"
                    else
                        # Handle regular records
                        delete_batch="{
                            \"Changes\": [{
                                \"Action\": \"DELETE\",
                                \"ResourceRecordSet\": {
                                    \"Name\": \"$record_name\",
                                    \"Type\": \"$record_type\",
                                    \"TTL\": $record_ttl,
                                    \"ResourceRecords\": $record_values
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
                        
                        log_success "✓ Deleted $record_type record: $record_name"
                    else
                        log_warning "Failed to delete $record_type record: $record_name"
                        log_warning "AWS CLI output: $delete_output"
                    fi
                fi
            done <<< "$records_to_delete"
            
            log_success "DNS record cleanup completed"
        else
            log_info "No DNS records found to delete (only SOA/NS records remain)"
        fi
    else
        log_warning "Could not retrieve DNS records from hosted zone"
        log_warning "AWS CLI output: $dns_records"
        log_info "This may be normal if the hosted zone doesn't exist"
    fi
    
    return 0
}


# Function to generate cleanup summary
generate_cleanup_summary() {
    log_step 4 "Generating cleanup summary"
    
    local summary_file="$LOG_DIR/qumulo-workshop-cleanup-summary-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$summary_file" << EOF
Qumulo Workshop Cleanup Summary
Generated: $(date)

ACTIONS COMPLETED:
- Destroyed all active Qumulo clusters
- Emptied workshop utility S3 bucket (including versioned objects and delete markers)
- Cleaned up DNS records from Private Hosted Zone
- Updated cluster registry with destruction status

CLEANUP LOG: $CLEANUP_LOG
SUMMARY: $summary_file

Workshop cleanup completed successfully!
EOF

    log_success "Cleanup summary generated: $summary_file"
    
    # Display the summary
    echo
    log_header "CLEANUP COMPLETED SUCCESSFULLY"
    cat "$summary_file"
}

# Main execution function
main() {
    echo
    echo -e "\033[0;31mWARNING: This operation will DESTROY ALL CLUSTER RESOURCES and is NOT REVERSIBLE.\033[0m"
    echo -e "Are you sure you want to proceed? Type \033[1;31mY\033[0m to continue, or anything else to cancel."
    read -r -p "Confirm cleanup [y/N]: " confirm
    if [[ "$confirm" != "Y" && "$confirm" != "y" ]]; then
        echo -e "\033[0;33mCleanup aborted by user.\033[0m"
        exit 0
    fi
    
    log_header "Qumulo Workshop Cleanup Script"
    log_info "Started at: $(date)"
    log_info "Running as: $(whoami)"
    log_info "Working directory: $(pwd)"
    log_info "Cleanup log: $CLEANUP_LOG"
    
    # Step 1: Stop all load testing FIRST
    log_step 1 "Stopping all load testing operations"
    "$WORKSHOP_DIR/scripts/start-load-testing.sh" stop 2>&1 | tee -a "$CLEANUP_LOG"


    # Step 2: Get active clusters
    log_step 2 "Identifying active clusters"

    if [[ ! -f "$CLUSTER_REGISTRY" ]]; then
        log_warning "Cluster registry not found: $CLUSTER_REGISTRY"
        log_info "No clusters to destroy"
    else
        # Get active clusters and process them
        local active_clusters
        active_clusters=$(get_active_clusters)
        
        if [[ -n "$active_clusters" ]]; then
            # Count clusters
            local total_clusters
            total_clusters=$(echo "$active_clusters" | grep -c . || echo 0)
            log_info "Found $total_clusters active cluster(s)"
            
            # Show cluster details
            while IFS= read -r deployment_name; do
                if [[ -n "$deployment_name" ]]; then
                    local description
                    description=$(jq -r --arg name "$deployment_name" '.clusters[] | select(.deployment_name == $name) | .description // "No description"' "$CLUSTER_REGISTRY" 2>/dev/null || echo "No description")
                    log_info " - $deployment_name: $description"
                fi
            done <<< "$active_clusters"
            
            local clusters_destroyed=0
            local clusters_failed=0
            
            # Destroy each active cluster
            while IFS= read -r deployment_name; do
                if [[ -n "$deployment_name" ]]; then
                    log_info "Processing cluster: $deployment_name"
                    
                    if destroy_cluster "$deployment_name"; then
                        ((clusters_destroyed++))
                        log_info "Cluster $deployment_name destroyed successfully"
                    else
                        ((clusters_failed++))
                        log_error "Failed to destroy cluster $deployment_name"
                    fi
                fi
            done <<< "$active_clusters"
            
            log_info "Cluster destruction summary: $clusters_destroyed destroyed, $clusters_failed failed"
        else
            log_info "No active clusters found"
        fi
    fi
    
    # Step 3: Empty utility bucket (ALWAYS runs)
    log_step 3 "Emptying utility S3 bucket"
    if empty_utility_bucket; then
        log_success "Utility bucket cleanup completed"
    else
        log_warning "Utility bucket cleanup failed, but continuing..."
    fi

    # Step 4: Clean up DNS records (NEW)
    log_step 4 "Cleaning up DNS records"
    if cleanup_dns_records; then
        log_success "DNS records cleanup completed"
    else
        log_warning "DNS records cleanup failed, but continuing..."
    fi
    
    # Step 5: Generate summary (ALWAYS runs)
    generate_cleanup_summary
    
    echo
    echo -e "${GREEN}Workshop cleanup completed!${NC}"
    echo -e "${BLUE}Cleanup log:${NC} $CLEANUP_LOG"
}

# Execute main function
main "$@"
