#!/bin/bash
###############################################################################
# HP MFP 4301 CTF - FINAL Clean Deployment
# Description: SNMP + IPP deployment with realistic cover traffic
# Platform: Kali Linux (or any Debian-based system)
# Usage: sudo ./deploy_ctf_CLEAN.sh <PRINTER_IP> [SNMP_COMMUNITY]
###############################################################################

set -e

PRINTER_IP="${1:-192.168.1.131}"
SNMP_COMMUNITY="${2:-private}"  # Default write community
TMP_DIR="/tmp/ctf_printer_clean_$$"
LOG_FILE="/tmp/ctf_deployment_clean_$(date +%Y%m%d_%H%M%S).log"

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
║          HP MFP 4301 CTF - Clean Final Deployment                        ║
║          SNMP Flags + IPP PADME Flag + Cover Jobs                        ║
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

log "Starting CTF deployment for printer: $PRINTER_IP"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

# Check for required tools
check_tools() {
    local missing_tools=()
    
    if ! command -v ipptool &>/dev/null; then
        missing_tools+=("ipptool (cups-ipp-utils)")
    fi
    
    if ! command -v snmpset &>/dev/null; then
        warning "snmpset not installed - will skip SNMP deployment"
        warning "Install with: sudo apt install snmp"
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
}

# Deploy printer attribute flags via SNMP
deploy_snmp_flags() {
    header "Deploying Printer Attribute Flags via SNMP"
    
    if ! command -v snmpset &>/dev/null; then
        warning "Skipping SNMP deployment - snmpset not available"
        echo ""
        warning "MANUAL CONFIGURATION REQUIRED:"
        echo "  1. Access: https://$PRINTER_IP"
        echo "  2. Navigate to: Network → Identification"
        echo "  3. Set:"
        echo "     System Location: Server-Room-B | Discovery Code: FLAG{LUKE47239581}"
        echo "     System Contact: SecTeam@lab.local | FLAG{LEIA83920174}"
        echo "     System Name: HP-MFP-CTF-FLAG{HAN62947103}"
        return
    fi
    
    # FLAG 1: System Location (LUKE)
    info "FLAG 1: Setting printer-location (sysLocation)..."
    if snmpset -v2c -c "$SNMP_COMMUNITY" "$PRINTER_IP" \
        1.3.6.1.2.1.1.6.0 s "Server-Room-B | Discovery Code: FLAG{LUKE47239581}" \
        &>>"$LOG_FILE"; then
        success "✓ FLAG{LUKE47239581} deployed in printer-location"
    else
        error "✗ SNMP write failed for location"
        warning "  Try: Community string may not have write access"
        warning "  Solution: Configure manually via web interface"
    fi
    
    # FLAG 2: System Contact (LEIA)
    info "FLAG 2: Setting printer-contact (sysContact)..."
    if snmpset -v2c -c "$SNMP_COMMUNITY" "$PRINTER_IP" \
        1.3.6.1.2.1.1.4.0 s "SecTeam@lab.local | FLAG{LEIA83920174}" \
        &>>"$LOG_FILE"; then
        success "✓ FLAG{LEIA83920174} deployed in printer-contact"
    else
        error "✗ SNMP write failed for contact"
    fi
    
    # FLAG 3: System Name (HAN)
    info "FLAG 3: Setting printer-info (sysName)..."
    if snmpset -v2c -c "$SNMP_COMMUNITY" "$PRINTER_IP" \
        1.3.6.1.2.1.1.5.0 s "HP-MFP-CTF-FLAG{HAN62947103}" \
        &>>"$LOG_FILE"; then
        success "✓ FLAG{HAN62947103} deployed in printer-info"
    else
        error "✗ SNMP write failed for name"
    fi
    
    echo ""
    info "Verifying SNMP flags..."
    sleep 2
    
    # Verify with snmpget
    local location=$(snmpget -v2c -c public "$PRINTER_IP" 1.3.6.1.2.1.1.6.0 2>/dev/null | grep -oP 'FLAG\{[^}]+\}' || echo "NOT_SET")
    local contact=$(snmpget -v2c -c public "$PRINTER_IP" 1.3.6.1.2.1.1.4.0 2>/dev/null | grep -oP 'FLAG\{[^}]+\}' || echo "NOT_SET")
    local name=$(snmpget -v2c -c public "$PRINTER_IP" 1.3.6.1.2.1.1.5.0 2>/dev/null | grep -oP 'FLAG\{[^}]+\}' || echo "NOT_SET")
    
    if [ "$location" != "NOT_SET" ]; then
        success "  ✓ Location flag verified: $location"
    else
        error "  ✗ Location flag NOT set"
    fi
    
    if [ "$contact" != "NOT_SET" ]; then
        success "  ✓ Contact flag verified: $contact"
    else
        error "  ✗ Contact flag NOT set"
    fi
    
    if [ "$name" != "NOT_SET" ]; then
        success "  ✓ Name flag verified: $name"
    else
        error "  ✗ Name flag NOT set"
    fi
}

# Deploy PADME flag in IPP job
deploy_ipp_flag() {
    header "Deploying IPP Job Flag (PADME)"
    
    local doc_file="$TMP_DIR/network_config.txt"
    cat > "$doc_file" << 'EOF'
════════════════════════════════════════════════════════════════
NETWORK CONFIGURATION BACKUP REPORT
════════════════════════════════════════════════════════════════

Generated: November 2025
Classification: Internal Use Only

This automated backup job contains network configuration data.
The job metadata includes the requesting user's authentication token.

To enumerate job metadata:
1. Use IPP Get-Jobs operation
2. Query job-originating-user-name attribute
3. Look for authentication tokens in the username field

════════════════════════════════════════════════════════════════
EOF
    
    local test_file="$TMP_DIR/padme_job.test"
    cat > "$test_file" <<TESTEOF
{
    NAME "PADME IPP Job"
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
    
    info "Submitting PADME flag job (FLAG{PADME91562837})..."
    
    # Submit 3 copies for persistence
    for i in 1 2 3; do
        info "  Copy $i/3..."
        timeout 10 ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$test_file" &>>"$LOG_FILE" || true
        sleep 2
    done
    
    success "PADME flag jobs submitted"
}

# Submit realistic cover jobs (no flags)
deploy_cover_jobs() {
    header "Deploying Realistic Cover Jobs"
    
    # Cover job 1: Confidential report
    info "Submitting cover job 1: Confidential Report..."
    cat > "$TMP_DIR/confidential.txt" << 'EOF'
CONFIDENTIAL - QUARTERLY SECURITY ASSESSMENT
Date: Q4 2025
For: Security Team

Executive Summary:
This report contains findings from the quarterly security assessment.
EOF
    
    cat > "$TMP_DIR/confidential.test" <<'TESTEOF'
{
    NAME "Cover Job 1"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "security-team"
    ATTR name job-name "Confidential-Security-Report"
    FILE DOCFILE
    STATUS successful-ok
}
TESTEOF
    sed -i "s|DOCFILE|$TMP_DIR/confidential.txt|g" "$TMP_DIR/confidential.test"
    timeout 10 ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/confidential.test" &>>"$LOG_FILE" || true
    success "  ✓ Confidential Report job submitted"
    sleep 2
    
    # Cover job 2: Technical documentation
    info "Submitting cover job 2: Technical Documentation..."
    cat > "$TMP_DIR/technical.txt" << 'EOF'
TECHNICAL DOCUMENTATION UPDATE
Version: 2.1
Author: Engineering Team

This document contains updated technical specifications
for the network infrastructure deployment.
EOF
    
    cat > "$TMP_DIR/technical.test" <<'TESTEOF'
{
    NAME "Cover Job 2"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "engineering"
    ATTR name job-name "Technical-Documentation"
    FILE DOCFILE
    STATUS successful-ok
}
TESTEOF
    sed -i "s|DOCFILE|$TMP_DIR/technical.txt|g" "$TMP_DIR/technical.test"
    timeout 10 ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/technical.test" &>>"$LOG_FILE" || true
    success "  ✓ Technical Documentation job submitted"
    sleep 2
    
    # Cover job 3: Meeting agenda
    info "Submitting cover job 3: Meeting Agenda..."
    cat > "$TMP_DIR/meeting.txt" << 'EOF'
WEEKLY OPERATIONS MEETING
Date: Monday, November 4, 2025
Time: 10:00 AM

Agenda:
1. Review action items from previous meeting
2. Discuss ongoing projects
3. Address any concerns or blockers
EOF
    
    cat > "$TMP_DIR/meeting.test" <<'TESTEOF'
{
    NAME "Cover Job 3"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "operations"
    ATTR name job-name "Meeting-Agenda"
    FILE DOCFILE
    STATUS successful-ok
}
TESTEOF
    sed -i "s|DOCFILE|$TMP_DIR/meeting.txt|g" "$TMP_DIR/meeting.test"
    timeout 10 ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/meeting.test" &>>"$LOG_FILE" || true
    success "  ✓ Meeting Agenda job submitted"
    
    success "All cover jobs submitted"
}

# Verify deployment
verify_deployment() {
    header "Verifying Deployment"
    
    info "Waiting 5 seconds for jobs to register..."
    sleep 5
    
    # Test IPP Get-Printer-Attributes
    cat > "$TMP_DIR/verify_printer.test" << 'EOF'
{
    NAME "Verify Printer Attributes"
    OPERATION Get-Printer-Attributes
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR keyword requested-attributes printer-location,printer-contact,printer-info
    STATUS successful-ok
}
EOF
    
    info "Checking printer attributes..."
    local printer_output="$TMP_DIR/printer_attrs.txt"
    timeout 15 ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/verify_printer.test" > "$printer_output" 2>&1 || true
    
    echo ""
    info "Printer Attribute Flags:"
    if grep -q "FLAG{LUKE47239581}" "$printer_output"; then
        success "  ✓ FLAG{LUKE47239581} (printer-location)"
    else
        error "  ✗ FLAG{LUKE47239581} NOT FOUND"
    fi
    
    if grep -q "FLAG{LEIA83920174}" "$printer_output"; then
        success "  ✓ FLAG{LEIA83920174} (printer-contact)"
    else
        error "  ✗ FLAG{LEIA83920174} NOT FOUND"
    fi
    
    if grep -q "FLAG{HAN62947103}" "$printer_output"; then
        success "  ✓ FLAG{HAN62947103} (printer-info)"
    else
        error "  ✗ FLAG{HAN62947103} NOT FOUND"
    fi
    
    # Test IPP Get-Jobs
    cat > "$TMP_DIR/verify_jobs.test" << 'EOF'
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
    
    info "Checking print jobs..."
    local jobs_output="$TMP_DIR/jobs.txt"
    timeout 15 ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/verify_jobs.test" > "$jobs_output" 2>&1 || true
    
    echo ""
    info "IPP Job Flag:"
    if grep -q "FLAG{PADME91562837}" "$jobs_output"; then
        success "  ✓ FLAG{PADME91562837} (job-originating-user-name)"
        local count=$(grep -c "FLAG{PADME91562837}" "$jobs_output" || echo 0)
        info "    Found in $count job(s)"
    else
        error "  ✗ FLAG{PADME91562837} NOT FOUND"
        warning "    Jobs may have processed already - re-run script if needed"
    fi
}

# Create student guide
create_student_guide() {
    cat > "$TMP_DIR/STUDENT_GUIDE.txt" << EOF
════════════════════════════════════════════════════════════════
    HP MFP 4301 CTF - Student Discovery Guide
════════════════════════════════════════════════════════════════

TARGET: $PRINTER_IP
PROTOCOLS: IPP (631), SNMP (161)

TOTAL FLAGS: 4

────────────────────────────────────────────────────────────────
FLAG 1-3: Printer Attributes (IPP/SNMP)
────────────────────────────────────────────────────────────────

Discovery Method 1: IPP Get-Printer-Attributes
-----------------------------------------------
1. Create get-printer-attributes.test:

{
    NAME "Get Printer Attributes"
    OPERATION Get-Printer-Attributes
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri \$uri
    ATTR keyword requested-attributes all
    STATUS successful-ok
}

2. Run: ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-printer-attributes.test

3. Search output for:
   - printer-location → FLAG{LUKE47239581}
   - printer-contact → FLAG{LEIA83920174}
   - printer-info → FLAG{HAN62947103}

Discovery Method 2: SNMP Enumeration
------------------------------------
snmpwalk -v2c -c public $PRINTER_IP 1.3.6.1.2.1.1

Or specific queries:
snmpget -v2c -c public $PRINTER_IP 1.3.6.1.2.1.1.6.0  # Location
snmpget -v2c -c public $PRINTER_IP 1.3.6.1.2.1.1.4.0  # Contact
snmpget -v2c -c public $PRINTER_IP 1.3.6.1.2.1.1.5.0  # Name

────────────────────────────────────────────────────────────────
FLAG 4: Print Job Metadata (IPP)
────────────────────────────────────────────────────────────────

1. Create get-jobs.test:

{
    NAME "Get Print Jobs"
    OPERATION Get-Jobs
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri \$uri
    ATTR keyword which-jobs all
    ATTR keyword requested-attributes all
    STATUS successful-ok
}

2. Run: ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test

3. Search for job-originating-user-name attribute:
   - Look for job: "Network-Config-Backup"
   - Find FLAG{PADME91562837}

Quick Search:
ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test | grep FLAG

════════════════════════════════════════════════════════════════
LEARNING OBJECTIVES:
────────────────────────────────────────────────────────────────
- IPP protocol enumeration
- SNMP device enumeration
- Print job metadata analysis
- Multi-protocol information gathering

════════════════════════════════════════════════════════════════
EOF
    
    success "Student guide created: $TMP_DIR/STUDENT_GUIDE.txt"
}

# Main execution
main() {
    check_tools
    echo ""
    deploy_snmp_flags
    echo ""
    deploy_ipp_flag
    echo ""
    deploy_cover_jobs
    echo ""
    verify_deployment
    echo ""
    create_student_guide
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                   DEPLOYMENT COMPLETE                                     ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}Deployed Flags:${NC}"
    echo "  FLAG{LUKE47239581}   - printer-location (SNMP sysLocation)"
    echo "  FLAG{LEIA83920174}   - printer-contact (SNMP sysContact)"
    echo "  FLAG{HAN62947103}    - printer-info (SNMP sysName)"
    echo "  FLAG{PADME91562837}  - job-originating-user-name (IPP job)"
    echo ""
    
    echo -e "${YELLOW}Files Created:${NC}"
    echo "  Student Guide: $TMP_DIR/STUDENT_GUIDE.txt"
    echo "  Verification: $TMP_DIR/printer_attrs.txt, $TMP_DIR/jobs.txt"
    echo "  Log: $LOG_FILE"
    echo ""
    
    echo -e "${PURPLE}Quick Student Test:${NC}"
    echo "  ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-printer-attributes.test | grep FLAG"
    echo "  ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test | grep FLAG"
    echo ""
    
    if grep -q "NOT FOUND" "$TMP_DIR/printer_attrs.txt" 2>/dev/null; then
        echo -e "${RED}⚠ Some flags failed to deploy - see verification output above${NC}"
        echo -e "${YELLOW}Manual Configuration:${NC} Access https://$PRINTER_IP → Network → Identification"
        echo ""
    fi
}

main
exit 0
