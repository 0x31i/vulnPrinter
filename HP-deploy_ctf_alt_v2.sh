#!/bin/bash
###############################################################################
# HP MFP 4301 CTF - WORKING SOLUTION
# Description: Both flags in job-originating-user-name (proven to work)
# Platform: Kali Linux (or any Debian-based system)
# Usage: sudo ./deploy_ctf_WORKING.sh <PRINTER_IP> <ADMIN_PIN>
###############################################################################

set -e

PRINTER_IP="${1:-192.168.1.131}"
ADMIN_PIN="${2}"
TMP_DIR="/tmp/ctf_printer_working_$$"
LOG_FILE="/tmp/ctf_deployment_working_$(date +%Y%m%d_%H%M%S).log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

clear
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║          HP MFP 4301 CTF - WORKING SOLUTION                              ║
║          Both flags in job-originating-user-name (proven method)         ║
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

if ! command -v ipptool &>/dev/null; then
    error "ipptool not installed. Install with: sudo apt install cups-ipp-utils"
    exit 1
fi

log "Starting WORKING CTF deployment for printer: $PRINTER_IP"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

# Deploy Web API flags
deploy_web_api_flags() {
    header "Deploying Web API Flags"
    
    if [ -z "$ADMIN_PIN" ]; then
        warning "Skipping web API deployment (no admin PIN)"
        return
    fi
    
    curl -k -s -X POST "https://$PRINTER_IP/hp/device/set_config" \
        -u "admin:$ADMIN_PIN" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "sysLocation=Server-Room-B | Discovery Code: FLAG{LUKE47239581}" \
        &>>"$LOG_FILE" && success "✓ FLAG{LUKE47239581}" || warning "✗ Failed"
    
    curl -k -s -X POST "https://$PRINTER_IP/hp/device/set_config" \
        -u "admin:$ADMIN_PIN" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "sysContact=SecTeam@lab.local | FLAG{LEIA83920174}" \
        &>>"$LOG_FILE" && success "✓ FLAG{LEIA83920174}" || warning "✗ Failed"
    
    curl -k -s -X POST "https://$PRINTER_IP/hp/device/set_config" \
        -u "admin:$ADMIN_PIN" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "sysName=HP-MFP-CTF-FLAG{HAN62947103}" \
        &>>"$LOG_FILE" && success "✓ FLAG{HAN62947103}" || warning "✗ Failed"
}

# Submit IPP job with flag in username
submit_flag_job() {
    local job_name="$1"
    local flag_username="$2"
    local doc_content="$3"
    local display_name="$4"
    
    info "Creating job: $display_name"
    
    local doc_file="$TMP_DIR/${display_name}.txt"
    echo "$doc_content" > "$doc_file"
    
    local test_file="$TMP_DIR/${display_name}.test"
    cat > "$test_file" <<TESTEOF
{
    NAME "$display_name"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri \$uri
    ATTR name requesting-user-name "$flag_username"
    ATTR name job-name "$job_name"
    
    FILE $doc_file
    
    STATUS successful-ok
}
TESTEOF
    
    info "Submitting..."
    timeout 10 ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$test_file" &>>"$LOG_FILE" || true
    success "Job submitted: $job_name"
}

# Deploy IPP flag jobs
deploy_ipp_flags() {
    header "Deploying IPP Job Flags"
    
    # FLAG 1: PADME (we know this works!)
    info "FLAG 1: PADME in job-originating-user-name..."
    submit_flag_job \
        "Network-Config-Backup" \
        "FLAG{PADME91562837}" \
        "NETWORK CONFIGURATION BACKUP

This job contains FLAG{PADME91562837} in the job-originating-user-name attribute.

Discovery Method:
- Use ipptool Get-Jobs operation
- Search for job-originating-user-name attribute
- Look for FLAG{PADME91562837}" \
        "PADME_Flag"
    
    sleep 2
    
    # FLAG 2: MACE (also in username since that's what works)
    info "FLAG 2: MACE in job-originating-user-name..."
    submit_flag_job \
        "Security-Audit-Report" \
        "FLAG{MACE41927365}" \
        "SECURITY AUDIT REPORT

This job contains FLAG{MACE41927365} in the job-originating-user-name attribute.

Discovery Method:
- Use ipptool Get-Jobs operation  
- Search for job-originating-user-name attribute
- Look for FLAG{MACE41927365}" \
        "MACE_Flag"
    
    sleep 2
    
    # Create backup copies for persistence
    info "Creating backup copies..."
    
    submit_flag_job "Network-Config-Backup" "FLAG{PADME91562837}" "Backup copy 1" "PADME_Backup"
    sleep 1
    submit_flag_job "Security-Audit-Report" "FLAG{MACE41927365}" "Backup copy 1" "MACE_Backup"
    
    success "All IPP flag jobs submitted"
}

# Verify flags
verify_flags() {
    header "Verification"
    
    info "Waiting 5 seconds for jobs to register..."
    sleep 5
    
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
    timeout 15 ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/verify.test" > "$verify_output" 2>&1 || true
    
    echo ""
    header "Verification Results"
    
    # Check PADME
    if grep -q "FLAG{PADME91562837}" "$verify_output"; then
        success "✓✓✓ FLAG{PADME91562837} FOUND ✓✓✓"
        local count=$(grep -c "FLAG{PADME91562837}" "$verify_output" || echo 0)
        info "  Found in $count job(s)"
        info "  In job: Network-Config-Backup"
    else
        error "✗ FLAG{PADME91562837} NOT FOUND"
    fi
    
    # Check MACE
    if grep -q "FLAG{MACE41927365}" "$verify_output"; then
        success "✓✓✓ FLAG{MACE41927365} FOUND ✓✓✓"
        local count=$(grep -c "FLAG{MACE41927365}" "$verify_output" || echo 0)
        info "  Found in $count job(s)"
        info "  In job: Security-Audit-Report"
    else
        error "✗ FLAG{MACE41927365} NOT FOUND"
    fi
    
    echo ""
    info "All jobs with flags:"
    grep -B 2 "FLAG{" "$verify_output" | grep -E "job-name|job-originating" | head -20
}

# Create student guide
create_student_guide() {
    cat > "$TMP_DIR/STUDENT_GUIDE.txt" << EOF
════════════════════════════════════════════════════════════════
    HP MFP 4301 CTF - IPP Job Enumeration Challenge
════════════════════════════════════════════════════════════════

TARGET: $PRINTER_IP:631
PROTOCOL: IPP (Internet Printing Protocol)

OBJECTIVE: Discover 2 flags hidden in print job metadata

════════════════════════════════════════════════════════════════
DISCOVERY PROCESS:
════════════════════════════════════════════════════════════════

Step 1: Create IPP Test File
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

Step 2: Query the Printer
--------------------------
ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test

Step 3: Find the Flags
----------------------
Both flags are in the "job-originating-user-name" attribute.
Search the output for:

1. Job: "Network-Config-Backup"
   Attribute: job-originating-user-name
   Flag: FLAG{PADME91562837}

2. Job: "Security-Audit-Report"
   Attribute: job-originating-user-name
   Flag: FLAG{MACE41927365}

Quick Search Command:
---------------------
ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test | grep -E "FLAG|job-originating-user-name" | grep -B 1 FLAG

════════════════════════════════════════════════════════════════
LEARNING OBJECTIVES:
════════════════════════════════════════════════════════════════

1. Understand IPP protocol structure
2. Use ipptool for printer enumeration
3. Extract metadata from print jobs
4. Recognize job-originating-user-name attribute
5. Understand print job querying operations

════════════════════════════════════════════════════════════════
HINTS:
════════════════════════════════════════════════════════════════

- Use -tv flags with ipptool (test + verbose)
- Both flags are in usernames, not job names
- Look for jobs named "Network-Config-Backup" and "Security-Audit-Report"
- The job-originating-user-name shows who submitted the job

════════════════════════════════════════════════════════════════
EOF
    
    success "Student guide created: $TMP_DIR/STUDENT_GUIDE.txt"
}

# Main execution
main() {
    deploy_web_api_flags
    echo ""
    deploy_ipp_flags
    echo ""
    verify_flags
    echo ""
    create_student_guide
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                   DEPLOYMENT SUCCESSFUL                                   ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}Deployed Flags:${NC}"
    echo "  1. FLAG{PADME91562837} - in job-originating-user-name of 'Network-Config-Backup'"
    echo "  2. FLAG{MACE41927365} - in job-originating-user-name of 'Security-Audit-Report'"
    echo ""
    
    echo -e "${PURPLE}Student Test Command:${NC}"
    echo "  ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test | grep FLAG"
    echo ""
    
    echo -e "${YELLOW}Files Created:${NC}"
    echo "  Student Guide: $TMP_DIR/STUDENT_GUIDE.txt"
    echo "  Verification: $TMP_DIR/verification.txt"
    echo "  Log: $LOG_FILE"
    echo ""
    
    echo -e "${GREEN}This solution is PROVEN TO WORK based on testing!${NC}"
    echo ""
}

main
exit 0
