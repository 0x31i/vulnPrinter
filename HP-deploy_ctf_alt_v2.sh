#!/bin/bash
###############################################################################
# HP MFP 4301 CTF - Alternative Deployment Script V7
# Description: Debug version - show actual errors for MACE flag
# Platform: Kali Linux (or any Debian-based system)
# Usage: sudo ./deploy_ctf_alternative_V7.sh <PRINTER_IP> <ADMIN_PIN>
###############################################################################

set -e

# Configuration
PRINTER_IP="${1:-192.168.1.131}"
ADMIN_PIN="${2}"
TMP_DIR="/tmp/ctf_printer_v7_$$"
LOG_FILE="/tmp/ctf_deployment_v7_$(date +%Y%m%d_%H%M%S).log"

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
║          HP MFP 4301 CTF - Deployment Script V7 (DEBUG)                  ║
║          Strategy: Show real errors, test different job names            ║
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

log "Starting CTF deployment V7 (DEBUG MODE) for printer: $PRINTER_IP"
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

# Deploy PADME flag (we know this works)
deploy_padme_flag() {
    header "Deploying FLAG{PADME91562837} (Known Working Method)"
    
    local doc_file="$TMP_DIR/padme_job.txt"
    cat > "$doc_file" << 'EOF'
NETWORK CONFIGURATION BACKUP

This job contains FLAG{PADME91562837} in the job-originating-user-name attribute.
EOF
    
    local test_file="$TMP_DIR/padme_job.test"
    cat > "$test_file" <<TESTEOF
{
    NAME "PADME Job"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri \$uri
    ATTR name requesting-user-name "FLAG{PADME91562837}"
    ATTR name job-name "Network-Config-Backup"
    
    FILE $doc_file
    
    STATUS successful-ok
}
TESTEOF
    
    info "Submitting PADME job..."
    timeout 10 ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$test_file" &>>"$LOG_FILE" || true
    success "PADME job submitted"
    sleep 3
}

# Test MACE flag with different job name formats
deploy_mace_flag_tests() {
    header "Testing MACE Flag with Different Job Name Formats"
    
    local doc_file="$TMP_DIR/mace_job.txt"
    cat > "$doc_file" << 'EOF'
CTF CHALLENGE JOB

This job should contain FLAG{MACE41927365} in the job-name attribute.
EOF
    
    # TEST 1: Try original format
    info "TEST 1: Original format with flag in job-name"
    local test1="$TMP_DIR/mace_test1.test"
    cat > "$test1" <<TESTEOF
{
    NAME "MACE Test 1"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri \$uri
    ATTR name requesting-user-name "security-audit"
    ATTR name job-name "CTF-Challenge-Job-FLAG{MACE41927365}"
    
    FILE $doc_file
    
    STATUS successful-ok
}
TESTEOF
    
    info "Submitting with full flag in job-name..."
    local output1="$TMP_DIR/mace_test1_output.txt"
    if timeout 10 ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$test1" > "$output1" 2>&1; then
        if grep -q "successful-ok" "$output1"; then
            success "✓ TEST 1 SUCCESS - Original format works!"
        else
            warning "✗ TEST 1 FAILED - Error:"
            grep "status-code\|EXPECTED" "$output1" | head -5
        fi
    else
        warning "✗ TEST 1 TIMED OUT"
    fi
    sleep 3
    
    # TEST 2: Try putting flag in username instead
    info "TEST 2: Flag in username field (like PADME)"
    local test2="$TMP_DIR/mace_test2.test"
    cat > "$test2" <<TESTEOF
{
    NAME "MACE Test 2"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri \$uri
    ATTR name requesting-user-name "FLAG{MACE41927365}"
    ATTR name job-name "CTF-Challenge-Job"
    
    FILE $doc_file
    
    STATUS successful-ok
}
TESTEOF
    
    info "Submitting with flag in username (job-originating-user-name)..."
    local output2="$TMP_DIR/mace_test2_output.txt"
    if timeout 10 ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$test2" > "$output2" 2>&1; then
        if grep -q "successful-ok" "$output2"; then
            success "✓ TEST 2 SUCCESS - Flag in username works!"
        else
            warning "✗ TEST 2 FAILED - Error:"
            grep "status-code\|EXPECTED" "$output2" | head -5
        fi
    else
        warning "✗ TEST 2 TIMED OUT"
    fi
    sleep 3
    
    # TEST 3: Try simpler job name
    info "TEST 3: Shorter job name without special characters"
    local test3="$TMP_DIR/mace_test3.test"
    cat > "$test3" <<TESTEOF
{
    NAME "MACE Test 3"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri \$uri
    ATTR name requesting-user-name "security-audit"
    ATTR name job-name "CTF-Job-MACE41927365"
    
    FILE $doc_file
    
    STATUS successful-ok
}
TESTEOF
    
    info "Submitting with simplified job-name (no curly braces)..."
    local output3="$TMP_DIR/mace_test3_output.txt"
    if timeout 10 ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$test3" > "$output3" 2>&1; then
        if grep -q "successful-ok" "$output3"; then
            success "✓ TEST 3 SUCCESS - Simplified name works!"
        else
            warning "✗ TEST 3 FAILED - Error:"
            grep "status-code\|EXPECTED" "$output3" | head -5
        fi
    else
        warning "✗ TEST 3 TIMED OUT"
    fi
}

# Verify what's actually in the queue
verify_flags() {
    header "Verifying What's Actually in Queue"
    
    info "Waiting 10 seconds for jobs to settle..."
    sleep 10
    
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
    
    if timeout 15 ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/verify.test" > "$verify_output" 2>&1; then
        
        echo ""
        header "Jobs Found in Queue"
        
        # Check for PADME
        echo ""
        info "Checking for PADME flag..."
        if grep -q "FLAG{PADME91562837}" "$verify_output"; then
            success "✓ FLAG{PADME91562837} FOUND"
        else
            error "✗ FLAG{PADME91562837} NOT FOUND"
        fi
        
        # Check for MACE
        echo ""
        info "Checking for MACE flag..."
        if grep -q "MACE41927365" "$verify_output"; then
            success "✓ MACE flag FOUND!"
            info "Looking for where it appears..."
            grep -A 2 -B 2 "MACE41927365" "$verify_output" | head -20
        else
            error "✗ MACE flag NOT FOUND"
        fi
        
        echo ""
        info "All job names in queue:"
        grep "job-name" "$verify_output" | head -20
        
        echo ""
        info "All usernames in queue:"
        grep "job-originating-user-name" "$verify_output" | head -20
        
    else
        warning "Verification timed out"
    fi
}

# Main execution
main() {
    deploy_web_api_flags
    echo ""
    deploy_padme_flag
    echo ""
    deploy_mace_flag_tests
    echo ""
    verify_flags
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                     DEBUG DEPLOYMENT COMPLETE                             ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}Test Results Summary:${NC}"
    echo "  Check the output above to see which MACE test succeeded"
    echo "  Whichever test worked is the format we'll use in final script"
    echo ""
    
    echo -e "${CYAN}Files Created:${NC}"
    echo "  Log: $LOG_FILE"
    echo "  Workspace: $TMP_DIR"
    echo "  Test Outputs: $TMP_DIR/mace_test*_output.txt"
    echo "  Verification: $TMP_DIR/verification.txt"
    echo ""
}

main
exit 0
