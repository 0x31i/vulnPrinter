#!/bin/bash
###############################################################################
# HP MFP 4301 CTF - Alternative Deployment Script V6
# Description: Simplified - submit and ignore timeouts (jobs work anyway)
# Platform: Kali Linux (or any Debian-based system)
# Usage: sudo ./deploy_ctf_alternative_V6.sh <PRINTER_IP> <ADMIN_PIN>
###############################################################################

set -e

# Configuration
PRINTER_IP="${1:-192.168.1.131}"
ADMIN_PIN="${2}"
TMP_DIR="/tmp/ctf_printer_v6_$$"
LOG_FILE="/tmp/ctf_deployment_v6_$(date +%Y%m%d_%H%M%S).log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Banner
clear
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║          HP MFP 4301 CTF - Deployment Script V6                          ║
║          Strategy: Simple submission, verify afterward                   ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Logging functions
log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
header() { echo -e "\n${PURPLE}═══ $1 ═══${NC}" | tee -a "$LOG_FILE"; }

# Check requirements
if [ -z "$ADMIN_PIN" ]; then
    warning "Admin PIN not provided - skipping web API flags"
fi

if ! command -v ipptool &>/dev/null; then
    error "ipptool not installed. Install with: sudo apt install cups-ipp-utils"
    exit 1
fi

log "Starting CTF deployment V6 for printer: $PRINTER_IP"
log "Strategy: Submit jobs, ignore timeouts, verify afterward"
log "Log file: $LOG_FILE"

# Create workspace
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

# Deploy Web API flags
deploy_web_api_flags() {
    header "Deploying Flags via Web API"
    
    if [ -z "$ADMIN_PIN" ]; then
        warning "Skipping web API deployment (no admin PIN)"
        return
    fi
    
    info "FLAG 1: System Location..."
    curl -k -s -X POST "https://$PRINTER_IP/hp/device/set_config" \
        -u "admin:$ADMIN_PIN" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "sysLocation=Server-Room-B | Discovery Code: FLAG{LUKE47239581}" \
        &>>"$LOG_FILE" && success "✓ FLAG{LUKE47239581}" || warning "✗ Failed"
    
    info "FLAG 2: System Contact..."
    curl -k -s -X POST "https://$PRINTER_IP/hp/device/set_config" \
        -u "admin:$ADMIN_PIN" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "sysContact=SecTeam@lab.local | FLAG{LEIA83920174}" \
        &>>"$LOG_FILE" && success "✓ FLAG{LEIA83920174}" || warning "✗ Failed"
    
    info "FLAG 3: System Name..."
    curl -k -s -X POST "https://$PRINTER_IP/hp/device/set_config" \
        -u "admin:$ADMIN_PIN" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "sysName=HP-MFP-CTF-FLAG{HAN62947103}" \
        &>>"$LOG_FILE" && success "✓ FLAG{HAN62947103}" || warning "✗ Failed"
}

# Simple job submission function
submit_simple_job() {
    local job_name="$1"
    local user_name="$2"
    local doc_content="$3"
    local display_name="$4"
    
    info "Submitting: $display_name"
    
    # Create document file
    local doc_file="$TMP_DIR/${display_name}.txt"
    echo "$doc_content" > "$doc_file"
    
    # Create test file - EXACTLY like what worked before
    local test_file="$TMP_DIR/${display_name}.test"
    cat > "$test_file" <<TESTEOF
{
    NAME "$display_name"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri \$uri
    ATTR name requesting-user-name "$user_name"
    ATTR name job-name "$job_name"
    
    FILE $doc_file
    
    STATUS successful-ok
}
TESTEOF
    
    # Submit job in background with timeout, don't wait for response
    info "Sending job to printer (may timeout but job will be queued)..."
    timeout 10 ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$test_file" &>>"$LOG_FILE" || true
    
    success "Job submitted: $display_name"
}

# Deploy both flag jobs
deploy_flag_jobs() {
    header "Deploying IPP Job Flags"
    
    # FLAG: PADME (job-originating-user-name)
    info "Creating PADME flag job..."
    submit_simple_job \
        "Network-Config-Backup" \
        "FLAG{PADME91562837}" \
        "NETWORK CONFIGURATION BACKUP
        
This job contains a flag in the job-originating-user-name attribute.
Use ipptool Get-Jobs operation to discover it." \
        "PADME_Flag"
    
    info "Waiting 3 seconds..."
    sleep 3
    
    # FLAG: MACE (job-name)
    info "Creating MACE flag job..."
    submit_simple_job \
        "CTF-Challenge-Job-FLAG{MACE41927365}" \
        "security-audit" \
        "CTF CHALLENGE JOB

This job contains a flag in the job-name attribute.
Use ipptool Get-Jobs operation to discover it." \
        "MACE_Flag"
    
    info "Waiting 3 seconds..."
    sleep 3
    
    # Submit a few more copies for persistence
    info "Creating backup copies for persistence..."
    
    submit_simple_job \
        "Network-Config-Backup" \
        "FLAG{PADME91562837}" \
        "BACKUP COPY 1" \
        "PADME_Backup1"
    sleep 2
    
    submit_simple_job \
        "CTF-Challenge-Job-FLAG{MACE41927365}" \
        "security-audit" \
        "BACKUP COPY 1" \
        "MACE_Backup1"
    sleep 2
    
    success "All flag jobs submitted"
}

# Verify flags are in queue
verify_flags() {
    header "Verifying Flags in Queue"
    
    info "Waiting 10 seconds for jobs to settle..."
    sleep 10
    
    # Create verification test
    cat > "$TMP_DIR/verify.test" << 'EOF'
{
    NAME "Verify Jobs"
    OPERATION Get-Jobs
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR keyword which-jobs all
    ATTR keyword requested-attributes all
    STATUS successful-ok
}
EOF
    
    info "Querying printer job queue..."
    local verify_output="$TMP_DIR/verification.txt"
    
    # Run verification
    if timeout 15 ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/verify.test" > "$verify_output" 2>&1; then
        echo ""
        header "Verification Results"
        
        # Check PADME
        if grep -q "FLAG{PADME91562837}" "$verify_output"; then
            success "✓✓✓ FLAG{PADME91562837} FOUND ✓✓✓"
            local count=$(grep -c "FLAG{PADME91562837}" "$verify_output" || echo 0)
            info "  Found in $count job(s)"
        else
            error "✗ FLAG{PADME91562837} NOT FOUND"
        fi
        
        # Check MACE
        if grep -q "FLAG{MACE41927365}" "$verify_output"; then
            success "✓✓✓ FLAG{MACE41927365} FOUND ✓✓✓"
            local count=$(grep -c "FLAG{MACE41927365}" "$verify_output" || echo 0)
            info "  Found in $count job(s)"
        else
            error "✗ FLAG{MACE41927365} NOT FOUND"
            warning "  Checking what jobs ARE in queue..."
            grep "job-name" "$verify_output" | head -10
        fi
        
        echo ""
        info "All jobs in queue:"
        grep -E "job-id|job-name|job-originating-user" "$verify_output" | head -40
        
        # Save summary
        grep -E "job-id|job-name|job-originating-user" "$verify_output" > "$TMP_DIR/jobs_summary.txt"
        
    else
        warning "Verification query timed out, trying direct grep..."
        # Even if it times out, try to get the output
        grep -E "FLAG|job-name|job-originating" "$verify_output" 2>/dev/null || true
    fi
}

# Create student guide
create_student_guide() {
    cat > "$TMP_DIR/STUDENT_GUIDE.txt" << EOF
════════════════════════════════════════════════════════════════
    STUDENT DISCOVERY GUIDE
    HP MFP 4301 - IPP Job Enumeration Challenge
════════════════════════════════════════════════════════════════

TARGET: $PRINTER_IP
PORT: 631 (IPP)

OBJECTIVE: Discover 2 flags hidden in print job metadata

────────────────────────────────────────────────────────────────

STEP 1: Create get-jobs.test
-----------------------------
cat > get-jobs.test << 'TESTFILE'
{
    NAME "Get All Print Jobs"
    OPERATION Get-Jobs
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri \$uri
    ATTR keyword which-jobs all
    ATTR keyword requested-attributes all
    STATUS successful-ok
}
TESTFILE

STEP 2: Query the printer
--------------------------
ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test

STEP 3: Find the flags
----------------------
Look for these attributes in the output:

1. job-originating-user-name → FLAG{PADME91562837}
2. job-name → FLAG{MACE41927365}

Quick search:
ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test | grep -E "FLAG|job-name|job-originating"

════════════════════════════════════════════════════════════════
EOF
    
    success "Student guide created: $TMP_DIR/STUDENT_GUIDE.txt"
}

# Main execution
main() {
    deploy_web_api_flags
    echo ""
    deploy_flag_jobs
    echo ""
    verify_flags
    echo ""
    create_student_guide
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                     DEPLOYMENT COMPLETE                                   ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}Files Created:${NC}"
    echo "  Log: $LOG_FILE"
    echo "  Workspace: $TMP_DIR"
    echo "  Student Guide: $TMP_DIR/STUDENT_GUIDE.txt"
    echo "  Verification: $TMP_DIR/verification.txt"
    echo "  Jobs Summary: $TMP_DIR/jobs_summary.txt"
    echo ""
    
    echo -e "${PURPLE}Student Test Command:${NC}"
    echo "  ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test | grep FLAG"
    echo ""
    
    echo -e "${YELLOW}Important:${NC}"
    echo "  - Both flags should now be in the printer queue"
    echo "  - Students can query anytime with Get-Jobs operation"
    echo "  - Multiple copies submitted for persistence"
    echo ""
}

main
exit 0
