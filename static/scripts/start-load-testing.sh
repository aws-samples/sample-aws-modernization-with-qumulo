#!/bin/bash
# qumulo-load-testing.sh - Simple load testing control using JSON variables

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

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1" >&2
}

# Configuration
WORKSHOP_DIR="/home/ssm-user/qumulo-workshop"
VARIABLES_FILE="$WORKSHOP_DIR/cloudformation-variables.json"

# Function to load variables from JSON file
load_workshop_variables() {
    log_step "Loading workshop variables from JSON file"

    if [[ ! -f "$VARIABLES_FILE" ]]; then
        log_error "Variables file not found: $VARIABLES_FILE"
        return 1
    fi

    # Extract variables from JSON file
    AWS_REGION=$(jq -r '.AWSRegion // empty' "$VARIABLES_FILE")
    LOAD_INSTANCE_1_ID=$(jq -r '.LoadTestInstance1ID // empty' "$VARIABLES_FILE")
    LOAD_INSTANCE_2_ID=$(jq -r '.LoadTestInstance2ID // empty' "$VARIABLES_FILE")
    LOAD_INSTANCE_3_ID=$(jq -r '.LoadTestInstance3ID // empty' "$VARIABLES_FILE")
    LOAD_INSTANCE_4_ID=$(jq -r '.LoadTestInstance4ID // empty' "$VARIABLES_FILE")
    LOAD_INSTANCE_5_ID=$(jq -r '.LoadTestInstance5ID // empty' "$VARIABLES_FILE")

    # Validate required variables
    if [[ -z "$AWS_REGION" ]]; then
        log_error "AWS Region not found in variables file"
        return 1
    fi

    if [[ -z "$LOAD_INSTANCE_1_ID" || -z "$LOAD_INSTANCE_2_ID" || -z "$LOAD_INSTANCE_3_ID" || -z "$LOAD_INSTANCE_4_ID" || -z "$LOAD_INSTANCE_5_ID" ]]; then
        log_error "Load testing instance IDs not found in variables file"
        return 1
    fi

    # Create array of instance IDs
    LOAD_INSTANCES=("$LOAD_INSTANCE_1_ID" "$LOAD_INSTANCE_2_ID" "$LOAD_INSTANCE_3_ID" "$LOAD_INSTANCE_4_ID" "$LOAD_INSTANCE_5_ID")

    log_info "Loaded ${#LOAD_INSTANCES[@]} load testing instances:"
    for i in "${!LOAD_INSTANCES[@]}"; do
        log_info "  Instance $((i+1)): ${LOAD_INSTANCES[$i]}"
    done

    return 0
}

# Function to extract cluster DNS from registry
extract_cluster_dns_from_registry() {
    local registry_file="$WORKSHOP_DIR/cluster-access-info.json"

    if [[ ! -f "$registry_file" ]]; then
        log_error "Cluster registry file not found: $registry_file"
        return 1
    fi

    # Try to get dns_name from active cluster
    local dns_name=$(jq -r '.clusters[] | select(.status == "active") | .dns_name // empty' "$registry_file" | head -n1)

    if [[ -n "$dns_name" && "$dns_name" != "null" && "$dns_name" != "Not registered" ]]; then
        echo "$dns_name"
        return 0
    fi

    # Fallback to extracting hostname from webui_url
    local web_url=$(jq -r '.clusters[] | select(.status == "active") | .webui_url // empty' "$registry_file" | head -n1)
    if [[ -n "$web_url" && "$web_url" != "null" ]]; then
        # Extract hostname from URL (remove https:// and any path)
        local hostname=$(echo "$web_url" | sed 's|https\?://||' | cut -d'/' -f1)
        if [[ -n "$hostname" ]]; then
            echo "$hostname"
            return 0
        fi
    fi

    return 1
}

# Function to start load testing
start_load_testing() {
    log_step "Starting load testing on all instances"

    # Get cluster DNS name
    local cluster_dns=""
    if [[ -f "$WORKSHOP_DIR/cluster-access-info.json" ]]; then
        cluster_dns=$(extract_cluster_dns_from_registry)
    fi

    if [[ -z "$cluster_dns" ]]; then
        log_error "Could not determine cluster DNS name from registry"
        return 1
    fi

    log_info "Using cluster DNS: $cluster_dns"

    # Start load testing on all instances
    for instance_id in "${LOAD_INSTANCES[@]}"; do
        log_info "Starting load testing on instance: $instance_id"

        # Create and execute load testing script via SSM
        aws ssm send-command \
            --instance-ids "$instance_id" \
            --document-name "AWS-RunShellScript" \
            --parameters "commands=[
                '# Set permissive umask for all created files/directories',
                'umask 000',
                '# Mount Qumulo cluster',
                'sudo mkdir -p /mnt/qumulo',
                '# Flushing DNS cache before Mounting testing...',
                'sudo resolvectl flush-caches',
                'sudo systemctl restart systemd-resolved',
                '# Add random delay before mounting (0-5 seconds)',
                'sleep $((RANDOM % 6))',
                'sudo mount -t nfs -o vers=3,nconnect=16,rsize=1048576,wsize=1048576,hard,intr,timeo=600,retrans=2 ${cluster_dns}:/ /mnt/qumulo',
                'sudo mkdir -p /mnt/qumulo/load-test/performance-\$(hostname)',
                'sudo mkdir -p /mnt/qumulo/userdata',
                'sudo chmod 777 /mnt/qumulo/load-test/performance-\$(hostname)',
                'sudo chmod 777 /mnt/qumulo/load-test',
                'sudo chmod 777 /mnt/qumulo/userdata',
                '# Start performance testing with umask set',
                'nohup bash -c \"umask 000; fio --name=qumulo-mixed-workload --directory=/mnt/qumulo/load-test/performance-\$(hostname) --rw=randrw --rwmixread=70 --bs=64k --iodepth=2 --numjobs=1 --size=500M --runtime=3h --time_based=1 --group_reporting\" > /var/log/load-testing/performance.log 2>&1 &',
                'echo \$! > /var/run/performance-load.pid',
                '',
                '# Start enhanced metadata testing with 10 top-level directories',
                'nohup bash -c \"umask 000; WORKER_DIR=/mnt/qumulo/userdata/worker-\$(hostname); mkdir -p \\\$WORKER_DIR; chmod 777 \\\$WORKER_DIR; for i in {1..10}; do mkdir -p \\\$WORKER_DIR/project-\\\$i; chmod 777 \\\$WORKER_DIR/project-\\\$i; done; END_TIME=\\\$(($(date +%s) + 10800)); while [[ \\\$(date +%s) -lt \\\$END_TIME ]]; do TARGET_DIR=\\\$WORKER_DIR/project-\\\$((RANDOM % 10 + 1)); ACTION=\\\$((RANDOM % 3)); if [[ \\\$ACTION -eq 0 ]]; then SUB_DIR=\\\$TARGET_DIR/sub-\\\$(date +%s%N | cut -b1-8); mkdir -p \\\$SUB_DIR; chmod 777 \\\$SUB_DIR; for j in {1..2}; do FILE_SIZE=\\\$((RANDOM % 500 + 50)); dd if=/dev/urandom of=\\\$SUB_DIR/file-\\\$j.dat bs=1024 count=\\\$FILE_SIZE 2>/dev/null; chmod 666 \\\$SUB_DIR/file-\\\$j.dat; done; elif [[ \\\$ACTION -eq 1 ]]; then for k in {1..5}; do FILE_SIZE=\\\$((RANDOM % 200 + 10)); dd if=/dev/urandom of=\\\$TARGET_DIR/doc-\\\$(date +%s%N | cut -b1-8)-\\\$k.dat bs=1024 count=\\\$FILE_SIZE 2>/dev/null; chmod 666 \\\$TARGET_DIR/doc-\\\$(date +%s%N | cut -b1-8)-\\\$k.dat; done; else BURST_COUNT=\\\$((RANDOM % 8 + 3)); for l in seq 1 \\\$BURST_COUNT; do FILE_SIZE=\\\$((RANDOM % 100 + 5)); dd if=/dev/urandom of=\\\$TARGET_DIR/burst-\\\$(date +%s%N | cut -b1-8)-\\\$l.dat bs=1024 count=\\\$FILE_SIZE 2>/dev/null; chmod 666 \\\$TARGET_DIR/burst-\\\$(date +%s%N | cut -b1-8)-\\\$l.dat; done; fi; sleep \\\$((RANDOM % 3 + 1)); done\" > /var/log/load-testing/metadata.log 2>&1 &',
                'echo \$! > /var/run/metadata-load.pid',
                '',
                'echo \"Load testing started successfully\"',
                'echo \"Performance PID: \$(cat /var/run/performance-load.pid)\"',
                'echo \"Metadata PID: \$(cat /var/run/metadata-load.pid)\"'
            ]" \
            --region "$AWS_REGION" \
            --output text > /dev/null
    done

    log_info "Load testing started on all instances for 3 hours!"
    return 0
}

# Function to stop load testing
stop_load_testing() {
    log_step "Stopping load testing on all instances"

    for instance_id in "${LOAD_INSTANCES[@]}"; do
        log_info "Stopping load testing on instance: $instance_id"

        aws ssm send-command \
            --instance-ids "$instance_id" \
            --document-name "AWS-RunShellScript" \
            --parameters "commands=[
                'echo \"Stopping load testing...\"',
                '# Force kill FIO and metadata processes by PID if present',
                'if [[ -f /var/run/performance-load.pid ]]; then sudo kill -9 \$(cat /var/run/performance-load.pid) 2>/dev/null; rm -f /var/run/performance-load.pid; fi',
                'if [[ -f /var/run/metadata-load.pid ]]; then sudo kill -9 \$(cat /var/run/metadata-load.pid) 2>/dev/null; rm -f /var/run/metadata-load.pid; fi',
                '# Force kill any remaining fio or metadata processes just in case',
                'sudo pkill -9 -f fio 2>/dev/null || true',
                'sudo pkill -9 -f metadata 2>/dev/null || true',
                '# Always attempt a lazy unmount to avoid hangs',
                'sudo umount -l /mnt/qumulo 2>/dev/null || true',
                'echo \"Load testing stopped\"'
            ]" \
            --region "$AWS_REGION" \
            --output text > /dev/null
    done

    log_info "Load testing stopped on all instances!"
    return 0
}


# Function to check load testing status
status_load_testing() {
    log_step "Checking load testing status"

    for i in "${!LOAD_INSTANCES[@]}"; do
        local instance_id="${LOAD_INSTANCES[$i]}"
        log_info "Instance $((i+1)): $instance_id"

        aws ssm send-command \
            --instance-ids "$instance_id" \
            --document-name "AWS-RunShellScript" \
            --parameters "commands=[
                'echo \"=== Load Testing Status ===\"',
                'if [[ -f /var/run/performance-load.pid ]] && kill -0 \$(cat /var/run/performance-load.pid) 2>/dev/null; then echo \"Performance testing: RUNNING\"; else echo \"Performance testing: STOPPED\"; fi',
                'if [[ -f /var/run/metadata-load.pid ]] && kill -0 \$(cat /var/run/metadata-load.pid) 2>/dev/null; then echo \"Metadata testing: RUNNING\"; else echo \"Metadata testing: STOPPED\"; fi',
                'if mountpoint -q /mnt/qumulo; then echo \"Qumulo mounted: YES\"; df -h /mnt/qumulo; else echo \"Qumulo mounted: NO\"; fi'
            ]" \
            --region "$AWS_REGION" \
            --output text
    done

    return 0
}

# Function to display usage
show_usage() {
    echo "Qumulo Workshop Load Testing"
    echo ""
    echo "Usage: $0 {start|stop|status}"
    echo ""
    echo "Commands:"
    echo "  start  - Mount Qumulo and start 3-hour load testing"
    echo "  stop   - Stop all load testing"
    echo "  status - Check load testing status"
    echo ""
    echo "The start command will:"
    echo "  1. Mount Qumulo cluster to /mnt/qumulo on each instance"
    echo "  2. Start performance testing (FIO mixed 70/30 read/write, 64k blocks)"
    echo "  3. Start metadata testing (directory/file creation and operations)"
    echo "  4. Run tests for 3 hours or until stopped"
    echo ""
    echo "Load testing instances:"
    if [[ ${#LOAD_INSTANCES[@]} -gt 0 ]]; then
        for i in "${!LOAD_INSTANCES[@]}"; do
            echo "  Instance $((i+1)): ${LOAD_INSTANCES[$i]}"
        done
    else
        echo "  (Load variables first to see instance IDs)"
    fi
}

# Main execution function
main() {
    local action=${1:-""}

    # Load variables first
    if ! load_workshop_variables; then
        log_error "Failed to load workshop variables"
        exit 1
    fi

    case "$action" in
        start)
            echo
            echo "=================================================="
            echo "Qumulo Workshop - Starting Load Testing"
            echo "=================================================="
            echo

            if ! start_load_testing; then
                log_error "Failed to start load testing"
                exit 1
            fi

            echo
            echo "=================================================="
            echo "Load Testing Started Successfully!"
            echo "=================================================="
            echo
            echo "Load testing is now running for 3 hours"
            echo "Performance test: FIO mixed workload (70/30 read/write, 64k blocks)"
            echo "Metadata test: Directory and file operations across cluster"
            echo ""
            echo "To stop load testing:"
            echo "  $0 stop"
            echo
            ;;
        stop)
            echo
            echo "=================================================="
            echo "Qumulo Workshop - Stopping Load Testing"
            echo "=================================================="
            echo

            if ! stop_load_testing; then
                log_error "Failed to stop load testing"
                exit 1
            fi

            echo
            echo "=================================================="
            echo "Load Testing Stopped Successfully!"
            echo "=================================================="
            echo
            ;;
        status)
            echo
            echo "=================================================="
            echo "Qumulo Workshop - Load Testing Status"
            echo "=================================================="
            echo

            status_load_testing
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"