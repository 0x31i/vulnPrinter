#!/bin/bash
###############################################################################
# HP MFP 4301 CTF - FINAL Deployment Script
# Description: Rapid-fire job submission to keep flags in queue
# Platform: Kali Linux (or any Debian-based system)
# Usage: sudo ./deploy_ctf_FINAL.sh <PRINTER_IP> <ADMIN_PIN>
###############################################################################

set -e

# Configuration
PRINTER_IP="${1:-192.168.1.131}"
ADMIN_PIN="${2}"
TMP_DIR="/tmp/ctf_printer_final_$$"
LOG_FILE="/tmp/ctf_deployment_final_$(date +%Y%m%d_%H%M%S).log"

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
║          HP MFP 4301 CTF - FINAL Working Deployment                      ║
║          Strategy: Rapid-fire submission + immediate verification        ║
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

log "Starting FINAL CTF deployment for printer: $PRINTER_IP"
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

# Deploy PADME flag (job-originating-user-name) - WE KNOW THIS WORKS
deploy_padme_jobs() {
    header "Deploying FLAG{PADME91562837} Jobs"
    
    local doc_file="$TMP_DIR/padme.txt"
    echo "NETWORK CONFIG BACKUP - Flag in job-originating-user-name" > "$doc_file"
    
    local test_file="$TMP_DIR/padme.test"
    cat > "$test_file" <<'TESTEOF'
{
    NAME "PADME Job"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "FLAG{PADME91562837}"
    ATTR name job-name "Network-Config-Backup"
    FILE DOCFILE
    STATUS successful-ok
}
TESTEOF
    
    # Replace DOCFILE placeholder
    sed -i "s|DOCFILE|$doc_file|g" "$test_file"
    
    # Submit 3 copies for persistence
    for i in 1 2 3; do
        info "Submitting PADME copy $i/3..."
        timeout 8 ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$test_file" &>>"$LOG_FILE" || true
        sleep 1
    done
    
    success "PADME jobs submitted"
}

# Deploy MACE flag - USE SIMPLE JOB NAME
deploy_mace_jobs() {
    header "Deploying FLAG{MACE41927365} Jobs"
    
    local doc_file="$TMP_DIR/mace.txt"
    echo "CTF CHALLENGE JOB - Flag in job-name attribute" > "$doc_file"
    
    local test_file="$TMP_DIR/mace.test"
    cat > "$test_file" <<'TESTEOF'
{
    NAME "MACE Job"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "security-audit"
    ATTR name job-name "Challenge-FLAG-MACE41927365"
    FILE DOCFILE
    STATUS successful-ok
}
TESTEOF
    
    # Replace DOCFILE placeholder
    sed -i "s|DOCFILE|$doc_file|g" "$test_file"
    
    # Submit 5 copies rapidly for better chance of catching in queue
    info "Submitting 5 MACE jobs rapidly..."
    for i in 1 2 3 4 5; do
        info "  Copy $i/5..."
        timeout 8 ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$test_file" &>>"$LOG_FILE" || true &
    done
    
    info "Waiting for submissions to complete..."
    wait
    
    success "MACE jobs submitted"
}

# IMMEDIATE verification (don't wait)
verify_immediately() {
    header "IMMEDIATE Verification (No Delay)"
    
    info "Querying NOW before jobs process..."
    
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
    
    local verify_output="$TMP_DIR/verification.txt"
    timeout 15 ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/verify.test" > "$verify_output" 2>&1 || true
    
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
    if grep -q "MACE41927365" "$verify_output"; then
        success "✓✓✓ FLAG{MACE41927365} FOUND ✓✓✓"
        local count=$(grep -c "MACE41927365" "$verify_output" || echo 0)
        info "  Found in $count job(s)"
        info "  Location:"
        grep -B 2 "MACE41927365" "$verify_output" | grep "job-name\|job-originating" | head -5
    else
        warning "✗ MACE41927365 NOT FOUND (may have processed already)"
    fi
    
    echo ""
    info "All jobs currently in queue:"
    grep -E "job-id|job-name|job-originating" "$verify_output" | head -30
}

# Create student instructions
create_student_guide() {
    cat > "$TMP_DIR/STUDENT_GUIDE.txt" << EOF
════════════════════════════════════════════════════════════════
    HP MFP 4301 CTF - IPP Job Enumeration Challenge
════════════════════════════════════════════════════════════════

TARGET: $PRINTER_IP:631

FLAGS TO FIND:
- FLAG{PADME91562837} in job-originating-user-name
- FLAG{MACE41927365} in job-name

────────────────────────────────────────────────────────────────
DISCOVERY STEPS:
────────────────────────────────────────────────────────────────

1. Create get-jobs.test:

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

2. Query the printer:

ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test

3. Search for flags:

ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test | grep -E "FLAG|MACE|PADME"

────────────────────────────────────────────────────────────────
NOTES:
- Jobs may process quickly - query immediately
- PADME flag in: job-originating-user-name attribute
- MACE flag in: job-name attribute (look for "Challenge-FLAG-MACE...")
════════════════════════════════════════════════════════════════
EOF
    
    success "Student guide created"
}

# Main execution
main() {
    deploy_web_api_flags
    echo ""
    deploy_padme_jobs
    echo ""
    deploy_mace_jobs
    echo ""
    verify_immediately
    echo ""
    create_student_guide
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                   DEPLOYMENT COMPLETE                                     ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}Quick Test:${NC}"
    echo "  ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test | grep -E \"FLAG|MACE|PADME\""
    echo ""
    
    echo -e "${YELLOW}Important:${NC}"
    echo "  - PADME flag: job-originating-user-name = FLAG{PADME91562837}"
    echo "  - MACE flag: job-name contains MACE41927365"
    echo "  - Jobs process quickly - students should query immediately"
    echo "  - Re-run this script anytime to refresh jobs in queue"
    echo ""
    
    echo -e "${PURPLE}Files:${NC}"
    echo "  Student Guide: $TMP_DIR/STUDENT_GUIDE.txt"
    echo "  Verification: $TMP_DIR/verification.txt"
    echo "  Log: $LOG_FILE"
    echo ""
}

main
exit 0
