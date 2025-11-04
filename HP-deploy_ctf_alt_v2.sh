#!/bin/bash
###############################################################################
# HP MFP 4301 CTF - Alternative Deployment Script V2
# Description: Creates multiple copies of jobs to ensure visibility
# Workaround for: job-hold-until not working, jobs processing immediately
# Platform: Kali Linux (or any Debian-based system)
# Usage: sudo ./deploy_ctf_alternative_V2.sh <PRINTER_IP> <ADMIN_PIN>
###############################################################################

set -e

# Configuration
PRINTER_IP="${1:-192.168.1.131}"
ADMIN_PIN="${2}"
TMP_DIR="/tmp/ctf_printer_v2_$$"
LOG_FILE="/tmp/ctf_deployment_v2_$(date +%Y%m%d_%H%M%S).log"
NUM_JOB_COPIES=3  # Create 3 copies of each job for persistence

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
║          HP MFP 4301 CTF - Deployment Script V2                          ║
║          Strategy: Multiple job copies for persistent queue              ║
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

# Check if admin PIN is provided
if [ -z "$ADMIN_PIN" ]; then
    warning "Admin PIN not provided - some flags may not deploy"
    warning "Usage: $0 <PRINTER_IP> <ADMIN_PIN>"
    read -p "Continue without admin PIN? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

log "Starting CTF deployment V2 for printer: $PRINTER_IP"
log "Creating $NUM_JOB_COPIES copies of each job for persistence"
log "Log file: $LOG_FILE"

# Create workspace
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

# Check for ipptool
if ! command -v ipptool &>/dev/null; then
    error "ipptool not installed. Install with: sudo apt install cups-ipp-utils"
    exit 1
fi

# Deploy flags via Web API
deploy_web_api_flags() {
    header "Deploying Flags via Web API"
    
    if [ -z "$ADMIN_PIN" ]; then
        warning "Skipping web API deployment (no admin PIN)"
        return
    fi
    
    info "FLAG 1: Deploying System Location..."
    curl -k -s -X POST "https://$PRINTER_IP/hp/device/set_config" \
        -u "admin:$ADMIN_PIN" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "sysLocation=Server-Room-B | Discovery Code: FLAG{LUKE47239581}" \
        &>>"$LOG_FILE" && success "FLAG 1 deployed - FLAG{LUKE47239581}" || warning "FLAG 1 failed"
    
    info "FLAG 2: Deploying System Contact..."
    curl -k -s -X POST "https://$PRINTER_IP/hp/device/set_config" \
        -u "admin:$ADMIN_PIN" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "sysContact=SecTeam@lab.local | FLAG{LEIA83920174}" \
        &>>"$LOG_FILE" && success "FLAG 2 deployed - FLAG{LEIA83920174}" || warning "FLAG 2 failed"
    
    info "FLAG 3: Deploying System Name..."
    curl -k -s -X POST "https://$PRINTER_IP/hp/device/set_config" \
        -u "admin:$ADMIN_PIN" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "sysName=HP-MFP-CTF-FLAG{HAN62947103}" \
        &>>"$LOG_FILE" && success "FLAG 3 deployed - FLAG{HAN62947103}" || warning "FLAG 3 failed"
}

# Deploy IPP job flags - PADME flag (in job-originating-user-name)
deploy_padme_flag() {
    header "Deploying FLAG{PADME91562837} - Job Metadata Challenge"
    
    # Create document
    cat > "$TMP_DIR/padme_job.txt" << 'EOF'
═══════════════════════════════════════════════
NETWORK CONFIGURATION BACKUP - METADATA CHALLENGE
═══════════════════════════════════════════════

This print job contains a hidden flag in its metadata.

Discovery Method:
1. Use ipptool with Get-Jobs operation
2. Look for the "job-originating-user-name" attribute
3. The flag is embedded in the username field

Command:
ipptool -tv ipp://PRINTER_IP:631/ipp/print get-jobs.test

Look for: job-originating-user-name containing FLAG
EOF
    
    # Create test file
    cat > "$TMP_DIR/padme_job.test" << 'EOF'
{
    NAME "PADME Metadata Challenge"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "FLAG{PADME91562837}"
    ATTR name job-name "Network-Config-Backup"
    ATTR mimeMediaType document-format text/plain
    
    FILE padme_job.txt
    
    STATUS successful-ok
}
EOF
    
    # Submit multiple copies
    local success_count=0
    for i in $(seq 1 $NUM_JOB_COPIES); do
        info "Submitting PADME job copy $i/$NUM_JOB_COPIES..."
        if ipptool -tf "$TMP_DIR/padme_job.txt" "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/padme_job.test" &>>"$LOG_FILE"; then
            ((success_count++))
        fi
        sleep 0.5
    done
    
    if [ $success_count -gt 0 ]; then
        success "FLAG{PADME91562837} deployed - $success_count/$NUM_JOB_COPIES jobs submitted"
    else
        error "FLAG{PADME91562837} deployment failed"
    fi
}

# Deploy IPP job flags - MACE flag (in job-name)
deploy_mace_flag() {
    header "Deploying FLAG{MACE41927365} - Job Name Challenge"
    
    # Create document
    cat > "$TMP_DIR/mace_job.txt" << 'EOF'
═══════════════════════════════════════════════
CTF CHALLENGE JOB - JOB NAME FLAG
═══════════════════════════════════════════════

This print job contains a flag embedded in its job name.

Discovery Method:
1. Use ipptool with Get-Jobs operation
2. Look for the "job-name" attribute
3. The flag is embedded directly in the job name

Command:
ipptool -tv ipp://PRINTER_IP:631/ipp/print get-jobs.test

Look for: job-name containing "CTF-Challenge-Job-FLAG"
EOF
    
    # Create test file - CRITICAL FIX: Proper FILE directive
    cat > "$TMP_DIR/mace_job.test" << 'EOF'
{
    NAME "MACE Job Name Challenge"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "security-audit"
    ATTR name job-name "CTF-Challenge-Job-FLAG{MACE41927365}"
    ATTR mimeMediaType document-format text/plain
    
    FILE mace_job.txt
    
    STATUS successful-ok
}
EOF
    
    # VERIFY FILE EXISTS before submission
    if [ ! -f "$TMP_DIR/mace_job.txt" ]; then
        error "MACE job file not found!"
        return 1
    fi
    
    info "MACE job file verified: $(wc -l < "$TMP_DIR/mace_job.txt") lines"
    
    # Submit multiple copies with explicit file path
    local success_count=0
    for i in $(seq 1 $NUM_JOB_COPIES); do
        info "Submitting MACE job copy $i/$NUM_JOB_COPIES..."
        
        # Use absolute path and verbose output
        if ipptool -tv -f "$TMP_DIR/mace_job.txt" "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/mace_job.test" 2>&1 | tee -a "$LOG_FILE" | grep -q "successful-ok"; then
            ((success_count++))
            success "  ✓ Copy $i submitted successfully"
        else
            warning "  ✗ Copy $i failed"
        fi
        sleep 0.5
    done
    
    if [ $success_count -gt 0 ]; then
        success "FLAG{MACE41927365} deployed - $success_count/$NUM_JOB_COPIES jobs submitted"
    else
        error "FLAG{MACE41927365} deployment FAILED - check log for details"
        warning "Attempting alternative method..."
        deploy_mace_flag_alternative
    fi
}

# Alternative method for MACE flag if primary fails
deploy_mace_flag_alternative() {
    info "Trying alternative MACE flag deployment method..."
    
    # Try with a simpler test file
    cat > "$TMP_DIR/mace_simple.test" << EOF
{
    NAME "MACE Alternative"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri \$uri
    ATTR name requesting-user-name "security-audit"
    ATTR name job-name "CTF-Challenge-Job-FLAG{MACE41927365}"
    ATTR mimeMediaType document-format text/plain
    
    FILE $TMP_DIR/mace_job.txt
    
    STATUS successful-ok
}
EOF
    
    if ipptool -tv -f "$TMP_DIR/mace_job.txt" "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/mace_simple.test" 2>&1 | tee -a "$LOG_FILE" | grep -q "successful-ok"; then
        success "MACE flag deployed via alternative method"
    else
        error "Alternative MACE deployment also failed"
    fi
}

# Deploy other print jobs
deploy_other_print_jobs() {
    header "Deploying Additional Print Jobs"
    
    # Confidential Report
    info "Creating Confidential Security Report job..."
    cat > "$TMP_DIR/confidential.txt" << 'EOF'
CONFIDENTIAL - SECURITY ASSESSMENT REPORT
Authorization Token: FLAG{OBIWAN73049281}
Subject: Network Printer Security Assessment
EOF
    
    cat > "$TMP_DIR/confidential.test" << 'EOF'
{
    NAME "Confidential Report"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "security-team"
    ATTR name job-name "Confidential-Security-Report"
    ATTR mimeMediaType document-format text/plain
    FILE confidential.txt
    STATUS successful-ok
}
EOF
    
    ipptool -tf "$TMP_DIR/confidential.txt" "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/confidential.test" &>>"$LOG_FILE" \
        && success "Confidential Report job submitted" || warning "Confidential Report failed"
    
    # PostScript Challenge
    info "Creating PostScript Challenge job..."
    cat > "$TMP_DIR/ps_challenge.txt" << 'EOF'
PostScript Security Challenge
Flag for this challenge: FLAG{VADER28374615}
Hint: PostScript is Turing-complete
EOF
    
    cat > "$TMP_DIR/ps_challenge.test" << 'EOF'
{
    NAME "PostScript Challenge"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "ctf-challenge"
    ATTR name job-name "PostScript-Challenge"
    ATTR mimeMediaType document-format text/plain
    FILE ps_challenge.txt
    STATUS successful-ok
}
EOF
    
    ipptool -tf "$TMP_DIR/ps_challenge.txt" "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/ps_challenge.test" &>>"$LOG_FILE" \
        && success "PostScript Challenge job submitted" || warning "PostScript Challenge failed"
}

# Verify deployment
verify_flags() {
    header "Verifying Flag Deployment"
    
    info "Waiting 3 seconds for jobs to register..."
    sleep 3
    
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
    ATTR keyword requested-attributes job-id,job-name,job-originating-user-name,job-state
    STATUS successful-ok
}
EOF
    
    info "Querying all jobs..."
    if ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/verify.test" > "$TMP_DIR/verification.txt" 2>&1; then
        
        echo ""
        info "═══ Verification Results ═══"
        
        # Check PADME flag
        if grep -q "FLAG{PADME91562837}" "$TMP_DIR/verification.txt"; then
            success "✓ FLAG{PADME91562837} FOUND in job-originating-user-name"
            PADME_COUNT=$(grep -c "FLAG{PADME91562837}" "$TMP_DIR/verification.txt" || echo 0)
            info "  Found in $PADME_COUNT job(s)"
        else
            error "✗ FLAG{PADME91562837} NOT FOUND"
        fi
        
        # Check MACE flag
        if grep -q "FLAG{MACE41927365}" "$TMP_DIR/verification.txt"; then
            success "✓ FLAG{MACE41927365} FOUND in job-name"
            MACE_COUNT=$(grep -c "FLAG{MACE41927365}" "$TMP_DIR/verification.txt" || echo 0)
            info "  Found in $MACE_COUNT job(s)"
        else
            error "✗ FLAG{MACE41927365} NOT FOUND"
            warning "  This is the main issue - MACE flag jobs not creating properly"
        fi
        
        echo ""
        info "Total jobs in queue:"
        grep -c "job-id (integer)" "$TMP_DIR/verification.txt" || echo "0"
        
        echo ""
        info "Job details:"
        grep -E "job-name|job-originating-user-name" "$TMP_DIR/verification.txt" | head -30
        
    else
        error "Job verification query failed"
    fi
}

# Create student instructions
create_student_guide() {
    header "Creating Student Discovery Guide"
    
    cat > "$TMP_DIR/STUDENT_GUIDE.txt" << EOF
═══════════════════════════════════════════════════════════════
    STUDENT DISCOVERY GUIDE
    HP MFP 4301 IoT Printer CTF Challenge
═══════════════════════════════════════════════════════════════

TARGET: $PRINTER_IP

IPP JOB ENUMERATION FLAGS:
--------------------------

Two flags are hidden in print job metadata. Use ipptool to discover them.

STEP 1: Create get-jobs.test file
----------------------------------
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

STEP 3: Look for flags in the output
-------------------------------------
Look for these attributes:
- job-originating-user-name (contains FLAG{PADME...})
- job-name (contains FLAG{MACE...})

HINT: Use grep to filter
------------------------
ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test | grep -E "job-name|job-originating-user-name"

Expected Flags:
- FLAG{PADME91562837} in job-originating-user-name
- FLAG{MACE41927365} in job-name

═══════════════════════════════════════════════════════════════
EOF
    
    success "Student guide created: $TMP_DIR/STUDENT_GUIDE.txt"
}

# Main execution
main() {
    deploy_web_api_flags
    deploy_padme_flag
    deploy_mace_flag
    deploy_other_print_jobs
    verify_flags
    create_student_guide
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                   DEPLOYMENT COMPLETE                                     ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}Files Created:${NC}"
    echo "  Logs: $LOG_FILE"
    echo "  Workspace: $TMP_DIR"
    echo "  Student Guide: $TMP_DIR/STUDENT_GUIDE.txt"
    echo "  Verification: $TMP_DIR/verification.txt"
    echo ""
    
    echo -e "${CYAN}Student Discovery Command:${NC}"
    echo "  ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test | grep FLAG"
    echo ""
    
    cat "$TMP_DIR/STUDENT_GUIDE.txt"
}

main
exit 0
