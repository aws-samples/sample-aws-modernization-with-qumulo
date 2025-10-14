#!/bin/bash

# Qumulo Workshop Master Control Script
# This script orchestrates the complete workshop environment setup

set -e  # Exit on any error

# Configuration
WORKSHOP_DIR="/home/ssm-user/qumulo-workshop"
SCRIPTS_DIR="${WORKSHOP_DIR}/scripts"
LOG_DIR="/home/ssm-user/qumulo-workshop/logs"
MASTER_LOG="${LOG_DIR}/workshop-master.log"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    local message="$1"
    echo -e "${GREEN}[INFO]${NC} $message" | tee -a "$MASTER_LOG"
}

log_warning() {
    local message="$1"
    echo -e "${YELLOW}[WARN]${NC} $message" | tee -a "$MASTER_LOG"
}

log_error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} $message" | tee -a "$MASTER_LOG"
}

log_step() {
    local step="$1"
    local message="$2"
    echo -e "${BLUE}[STEP $step]${NC} $message" | tee -a "$MASTER_LOG"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}[SUCCESS]${NC} $message" | tee -a "$MASTER_LOG"
}

log_header() {
    local header="$1"
    echo "" | tee -a "$MASTER_LOG"
    echo -e "${PURPLE}================================${NC}" | tee -a "$MASTER_LOG"
    echo -e "${PURPLE}$header${NC}" | tee -a "$MASTER_LOG"
    echo -e "${PURPLE}================================${NC}" | tee -a "$MASTER_LOG"
}

# Function to execute a script with logging
execute_script() {
    local script_name="$1"
    local script_path="${SCRIPTS_DIR}/${script_name}"
    local log_file="${LOG_DIR}/${script_name%.*}_${TIMESTAMP}.log"
    local step_number="$2"
    local description="$3"
    
    log_step "$step_number" "$description"
    log_info "Executing: $script_name"
    log_info "Log file: $log_file"
    
    if [ ! -f "$script_path" ]; then
        log_error "Script not found: $script_path"
        return 1
    fi
    
    if [ ! -x "$script_path" ]; then
        log_info "Making script executable: $script_path"
        chmod +x "$script_path"
    fi
    
    # Execute script with comprehensive logging
    if bash -x "$script_path" 2>&1 | tee "$log_file"; then
        log_success "Completed: $script_name"
        echo "$(date): SUCCESS - $script_name completed" >> "$MASTER_LOG"
        return 0
    else
        local exit_code=$?
        log_error "Failed: $script_name (exit code: $exit_code)"
        echo "$(date): FAILED - $script_name failed with exit code $exit_code" >> "$MASTER_LOG"
        return $exit_code
    fi
}

# Function to check prerequisites
check_prerequisites() {
    log_step "0" "Checking prerequisites"
    
    # Check if running as root or with sudo
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root or with sudo"
        return 1
    fi
    
    # Check if workshop directory exists
    if [ ! -d "$WORKSHOP_DIR" ]; then
        log_info "Creating workshop directory: $WORKSHOP_DIR"
        mkdir -p "$WORKSHOP_DIR"
    fi
    
    # Check if scripts directory exists
    if [ ! -d "$SCRIPTS_DIR" ]; then
        log_info "Creating scripts directory: $SCRIPTS_DIR"
        mkdir -p "$SCRIPTS_DIR"
    fi
    
    # Check if log directory is writable
    if [ ! -w "$LOG_DIR" ]; then
        log_error "Cannot write to log directory: $LOG_DIR"
        return 1
    fi
    
    # Check essential commands
    local required_commands=("curl" "aws" "jq")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_warning "Required command not found: $cmd"
        else
            log_info "Found required command: $cmd"
        fi
    done
    
    log_success "Prerequisites check completed"
    return 0
}

# Function to create status tracking
create_status_file() {
    local status_file="${WORKSHOP_DIR}/.workshop-status"
    cat > "$status_file" << EOF
# Qumulo Workshop Status Tracking
# Generated: $(date)
WORKSHOP_START_TIME=$(date -Iseconds)
MASTER_LOG=$MASTER_LOG
TIMESTAMP=$TIMESTAMP
STATUS=RUNNING
EOF
    log_info "Status file created: $status_file"
}

# Function to update status
update_status() {
    local status="$1"
    local status_file="${WORKSHOP_DIR}/.workshop-status"
    echo "STATUS=$status" >> "$status_file"
    echo "LAST_UPDATE=$(date -Iseconds)" >> "$status_file"
}

# Function to handle script failures
handle_failure() {
    local failed_script="$1"
    local exit_code="$2"
    
    log_error "Workshop setup failed at script: $failed_script"
    log_error "Exit code: $exit_code"
    
    update_status "FAILED"
    
    # Create failure report
    local failure_report="${LOG_DIR}/workshop-failure-report_${TIMESTAMP}.txt"
    cat > "$failure_report" << EOF
Qumulo Workshop Setup Failure Report
Generated: $(date)

Failed Script: $failed_script
Exit Code: $exit_code
Master Log: $MASTER_LOG

Recent Log Entries:
$(tail -20 "$MASTER_LOG")

System Information:
$(uname -a)
$(cat /etc/os-release)

Available Scripts:
$(ls -la "$SCRIPTS_DIR" 2>/dev/null || echo "Scripts directory not accessible")

Workshop Directory Contents:
$(ls -la "$WORKSHOP_DIR" 2>/dev/null || echo "Workshop directory not accessible")
EOF
    
    log_error "Failure report created: $failure_report"
    return $exit_code
}

# Function to fix ownership of all workshop files
fix_workshop_ownership() {
    log_step "FINAL" "Setting proper ownership of workshop files"
    
    # Ensure ssm-user exists before changing ownership
    if id ssm-user >/dev/null 2>&1; then
        log_info "Setting ownership of all workshop files to ssm-user:ssm-user"
        chown -R ssm-user:ssm-user /home/ssm-user/qumulo-workshop
        chown ssm-user:ssm-user /home/ssm-user/.bashrc 2>/dev/null || true
        log_success "Workshop file ownership updated"
    else
        log_warning "ssm-user not found, ownership not changed"
    fi
}

# Main execution function
main() {
    log_header "Qumulo Workshop Master Control Script"
    log_info "Started at: $(date)"
    log_info "Running as: $(whoami)"
    log_info "Working directory: $(pwd)"
    log_info "Master log: $MASTER_LOG"
    
    # Initialize status tracking
    create_status_file
    
    # Step 0: Prerequisites
    if ! check_prerequisites; then
        handle_failure "prerequisites" 1
        exit 1
    fi
    
    # Step 1: Setup Workshop Environment
    if ! execute_script "setup-workshop-environment.sh" "1" "Setting up workshop environment and CloudFormation variables"; then
        handle_failure "setup-workshop-environment.sh" $?
        exit 1
    fi
    
    # Step 2: Execute terraform inintal cluster deployment
    
    if ! execute_script "initial-qumulo-cluster-tf-configuration.sh" "2" "Initializing Primary Qumulo Cluster Terraform and Deploying"; then
        handle_failure "initial-qumulo-cluster-tf-configuration.sh" $?
        exit 1
    fi
    
    # if ! execute_script "setup-terraform-configs.sh" "3" "Setting up Terraform configurations"; then
    #     handle_failure "setup-terraform-configs.sh" $?
    #     exit 1
    # fi
    
    # if ! execute_script "validate-workshop-environment.sh" "4" "Validating workshop environment"; then
    #     handle_failure "validate-workshop-environment.sh" $?
    #     exit 1
    # fi
    
    # Final success
    log_header "Workshop Setup Complete!"
    log_success "All scripts executed successfully"
    log_info "Total execution time: $(($(date +%s) - $(date -d "$(grep WORKSHOP_START_TIME ${WORKSHOP_DIR}/.workshop-status | cut -d= -f2)" +%s))) seconds"
    
    update_status "COMPLETED"
    
    # Step 4: Create completion summary
    local summary_file="${LOG_DIR}/workshop-setup-summary_${TIMESTAMP}.txt"
    cat > "$summary_file" << EOF
Qumulo Workshop Setup Summary
Completed: $(date)

Status: SUCCESS
Master Log: $MASTER_LOG
Timestamp: $TIMESTAMP

Executed Scripts:
1. setup-workshop-environment.sh - Setting up workshop environment and CloudFormation variables

Log Files Generated:
$(ls -la ${LOG_DIR}/*${TIMESTAMP}.log 2>/dev/null || echo "No timestamped logs found")

Workshop Environment:
$(ls -la "$WORKSHOP_DIR" 2>/dev/null || echo "Workshop directory not accessible")

Next Steps:
1. Connect to the instance via SSM Session Manager
2. The workshop environment should load automatically
3. Run 'source cloudformation-variables.env' if needed
4. Navigate to terraform/ directory to begin workshop
EOF

    # Step 5: Fix ownership of all workshop files
    fix_workshop_ownership

    log_info "Setup summary created: $summary_file"
    log_header "Workshop Ready for Use!"


}

# Trap to handle script interruption
trap 'log_error "Script interrupted"; update_status "INTERRUPTED"; exit 130' INT TERM

# Execute main function
main "$@"
