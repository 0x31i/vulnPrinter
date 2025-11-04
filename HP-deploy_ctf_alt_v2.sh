#!/bin/bash
###############################################################################
# HP MFP 4301 CTF - Alternative Deployment Script (FIXED)
# Description: Deploys flags using methods that work (IPP, Web API)
# Workaround for: SNMP write restrictions and port 9100 filtering
# Platform: Kali Linux (or any Debian-based system)
# Usage: sudo ./deploy_ctf_alternative.sh <PRINTER_IP> <ADMIN_PIN>
###############################################################################

set -e

# Configuration
PRINTER_IP="${1:-192.168.1.131}"
ADMIN_PIN="${2}"
TMP_DIR="/tmp/ctf_printer_alt_$$"
LOG_FILE="/tmp/ctf_deployment_alt_$(date +%Y%m%d_%H%M%S).log"

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
║          HP MFP 4301 CTF - Alternative Deployment Script                 ║
║          Uses: Web API + IPP (workaround for SNMP/port 9100)             ║
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

log "Starting alternative CTF deployment for printer: $PRINTER_IP"
log "Log file: $LOG_FILE"

# Create workspace
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

# Deploy flags via Web API (instead of SNMP)
deploy_web_api_flags() {
    header "Deploying Flags via Web API"
    
    if [ -z "$ADMIN_PIN" ]; then
        error "Admin PIN required for web API deployment"
        info "Manual Configuration Required:"
        echo ""
        echo "Access web interface: https://$PRINTER_IP"
        echo "Navigate to: Network → Identification"
        echo ""
        echo "Set the following values:"
        echo "  System Name: HP-MFP-CTF-FLAG{HAN62947103}"
        echo "  System Location: Server-Room-B | Discovery Code: FLAG{LUKE47239581}"
        echo "  System Contact: SecTeam@lab.local | FLAG{LEIA83920174}"
        echo ""
        read -p "Press Enter after manual configuration is complete..."
        return
    fi
    
    # FLAG 1: System Location via Web API
    info "FLAG 1: Deploying via Web API..."
    if curl -k -s -X POST "https://$PRINTER_IP/hp/device/set_config" \
        -u "admin:$ADMIN_PIN" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "sysLocation=Server-Room-B | Discovery Code: FLAG{LUKE47239581}" \
        &>>"$LOG_FILE"; then
        success "FLAG 1 deployed via Web API - FLAG{LUKE47239581}"
    else
        warning "FLAG 1 Web API deployment failed - try manual configuration"
    fi
    
    # FLAG 2: System Contact via Web API
    info "FLAG 2: Deploying via Web API..."
    if curl -k -s -X POST "https://$PRINTER_IP/hp/device/set_config" \
        -u "admin:$ADMIN_PIN" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "sysContact=SecTeam@lab.local | FLAG{LEIA83920174}" \
        &>>"$LOG_FILE"; then
        success "FLAG 2 deployed via Web API - FLAG{LEIA83920174}"
    else
        warning "FLAG 2 Web API deployment failed - try manual configuration"
    fi
    
    # FLAG 3: System Name via Web API
    info "FLAG 3: Deploying via Web API..."
    if curl -k -s -X POST "https://$PRINTER_IP/hp/device/set_config" \
        -u "admin:$ADMIN_PIN" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "sysName=HP-MFP-CTF-FLAG{HAN62947103}" \
        &>>"$LOG_FILE"; then
        success "FLAG 3 deployed via Web API - FLAG{HAN62947103}"
    else
        warning "FLAG 3 Web API deployment failed - try manual configuration"
    fi
    
    info "FLAGS 4-5: SNMP-only flags - manual SNMP configuration required"
    echo "  FLAG 4: FLAG{CHEWBACCA09832423} (in sysDescr)"
    echo "  FLAG 5: FLAG{YODA51836492} (in HP OID)"
}

# Deploy print jobs via IPP (instead of port 9100)
deploy_ipp_print_jobs() {
    header "Deploying Print Job Flags via IPP"
    
    if ! command -v ipptool &>/dev/null; then
        error "ipptool not installed. Install with: apt install cups-ipp-utils"
        return
    fi
    
    # FLAG 6: Confidential Document
    info "FLAG 6: Creating confidential document..."
    cat > "$TMP_DIR/confidential_report.ps" << 'EOF'
%!PS-Adobe-3.0
%%Title: Quarterly Security Report - CONFIDENTIAL
%%CreationDate: 2025-10-29
%%Pages: 1

/Courier findfont 12 scalefont setfont

newpath
72 750 moveto
(CONFIDENTIAL - SECURITY ASSESSMENT REPORT) show

72 660 moveto
(Authorization Token: FLAG{OBIWAN73049281}) show

72 615 moveto
(Subject: Network Printer Security Assessment) show

showpage
%%EOF
EOF
    
    # Create IPP test file for printing with job-hold
    cat > "$TMP_DIR/print_flag6.test" << 'EOF'
{
    NAME "Print Confidential Document"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "security-team"
    ATTR name job-name "Confidential-Security-Report"
    ATTR mimeMediaType document-format application/postscript
    ATTR keyword job-hold-until indefinite
    
    FILE confidential_report.ps
    
    STATUS successful-ok
}
EOF
    
    if ipptool -tv -f "$TMP_DIR/confidential_report.ps" "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/print_flag6.test" &>>"$LOG_FILE"; then
        success "FLAG 6 deployed via IPP (HELD) - FLAG{OBIWAN73049281}"
    else
        warning "FLAG 6 IPP deployment failed"
    fi
    
    # FLAG 7: PostScript Challenge
    info "FLAG 7: Creating PostScript challenge..."
    cat > "$TMP_DIR/ps_challenge.ps" << 'EOF'
%!PS-Adobe-3.0
%%Title: PostScript Security Challenge

/Courier findfont 14 scalefont setfont

72 750 moveto
(PostScript Security Challenge) show

72 690 moveto
(Flag for this challenge: FLAG{VADER28374615}) show

72 660 moveto
(Hint: PostScript is Turing-complete) show

showpage
%%EOF
EOF
    
    cat > "$TMP_DIR/print_flag7.test" << 'EOF'
{
    NAME "Print PostScript Challenge"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "ctf-challenge"
    ATTR name job-name "PostScript-Challenge"
    ATTR mimeMediaType document-format application/postscript
    ATTR keyword job-hold-until indefinite
    
    FILE ps_challenge.ps
    
    STATUS successful-ok
}
EOF
    
    if ipptool -tv -f "$TMP_DIR/ps_challenge.ps" "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/print_flag7.test" &>>"$LOG_FILE"; then
        success "FLAG 7 deployed via IPP (HELD) - FLAG{VADER28374615}"
    else
        warning "FLAG 7 IPP deployment failed"
    fi
    
    # FLAG 8: Job Metadata with FLAG in requesting-user-name
    info "FLAG 8: Creating job with metadata flag in username..."
    cat > "$TMP_DIR/job_metadata.txt" << 'EOF'
NETWORK CONFIGURATION BACKUP

This job contains metadata flags.
Check job attributes for hidden flag in the requesting-user-name field.

Discovery Method: Use ipptool Get-Jobs operation
Look for: job-originating-user-name attribute
EOF
    
    cat > "$TMP_DIR/print_flag8.test" << 'EOF'
{
    NAME "Print Job Metadata Challenge"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "FLAG{PADME91562837}"
    ATTR name job-name "Network-Config-Backup"
    ATTR mimeMediaType document-format text/plain
    ATTR keyword job-hold-until indefinite
    
    FILE job_metadata.txt
    
    STATUS successful-ok
}
EOF
    
    if ipptool -tv -f "$TMP_DIR/job_metadata.txt" "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/print_flag8.test" &>>"$LOG_FILE"; then
        success "FLAG 8 deployed via IPP (HELD) - FLAG{PADME91562837} in job-originating-user-name"
    else
        warning "FLAG 8 IPP deployment failed"
    fi
}

# Web and IPP flags (these should work)
deploy_working_flags() {
    header "Deploying Web and IPP Flags"
    
    # FLAG 9: Web Interface (already accessible)
    info "FLAG 9: Web interface should be accessible at https://$PRINTER_IP"
    success "FLAG 9: Students should browse web interface"
    
    # FLAG 10: Web API
    if [ -n "$ADMIN_PIN" ]; then
        info "FLAG 10: Deploying via Web API..."
        if curl -k -s -X POST "https://$PRINTER_IP/DevMgmt/ProductConfigDyn.xml" \
            -u "admin:$ADMIN_PIN" \
            -H "Content-Type: text/xml" \
            -d '<SetData><DeviceLocation>FLAG{ANAKIN56738291}</DeviceLocation></SetData>' \
            &>>"$LOG_FILE"; then
            success "FLAG 10 deployed via Web API - FLAG{ANAKIN56738291}"
        fi
    fi
    
    # FLAG 11: IPP Enumeration
    if command -v ipptool &>/dev/null; then
        info "FLAG 11: IPP enumeration accessible"
        success "FLAG 11: Students can use: ipptool -tv ipp://$PRINTER_IP:631/ipp/print Get-Printer-Attributes.test"
    fi
    
    # FLAG 12: IPP Job Submission with FLAG in job-name
    info "FLAG 12: Creating IPP job with flag in job name (HELD)..."
    cat > "$TMP_DIR/ipp_job_flag12.txt" << 'EOF'
IPP CHALLENGE JOB

This job demonstrates IPP metadata enumeration.
The flag is embedded in the job-name attribute.

Discovery Method: Use ipptool Get-Jobs operation
Look for: job-name attribute containing the flag
EOF
    
    cat > "$TMP_DIR/ipp_job_flag12.test" << 'EOF'
{
    NAME "Submit Job with Flag in Name"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "security-audit"
    ATTR name job-name "CTF-Challenge-Job-FLAG{MACE41927365}"
    ATTR mimeMediaType document-format text/plain
    ATTR keyword job-hold-until indefinite
    
    FILE ipp_job_flag12.txt
    
    STATUS successful-ok
}
EOF
    
    if ipptool -tv -f "$TMP_DIR/ipp_job_flag12.txt" "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/ipp_job_flag12.test" &>>"$LOG_FILE"; then
        success "FLAG 12 deployed via IPP (HELD) - FLAG{MACE41927365} in job-name"
    else
        warning "FLAG 12 IPP deployment failed"
    fi
}

# Network flag (alternative method)
deploy_network_flag() {
    header "Deploying Network Analysis Flag"
    
    # FLAG 13: Try IPP instead of raw netcat
    info "FLAG 13: Creating network capture challenge via IPP..."
    echo -e "SECRET MESSAGE\nAuthorization Code: FLAG{REY83746529}\nThis message was sent for network analysis." > "$TMP_DIR/network_flag.txt"
    
    cat > "$TMP_DIR/network_flag.test" << 'EOF'
{
    NAME "Network Capture Challenge"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "network-challenge"
    ATTR name job-name "Network-Traffic-Analysis"
    ATTR mimeMediaType document-format text/plain
    ATTR keyword job-hold-until indefinite
    
    FILE network_flag.txt
    
    STATUS successful-ok
}
EOF
    
    if ipptool -tv -f "$TMP_DIR/network_flag.txt" "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/network_flag.test" &>>"$LOG_FILE"; then
        success "FLAG 13 deployed via IPP (HELD) - FLAG{REY83746529}"
    else
        warning "FLAG 13 deployment failed - manual configuration needed"
    fi
}

# Verify jobs are held in queue
verify_held_jobs() {
    header "Verifying Held Jobs in Queue"
    
    info "Creating verification test file..."
    cat > "$TMP_DIR/verify_jobs.test" << 'EOF'
{
    NAME "Verify Held Jobs"
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
    
    info "Querying held jobs..."
    if ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/verify_jobs.test" > "$TMP_DIR/job_verification.txt" 2>&1; then
        success "Job verification completed"
        
        # Check for our flags
        if grep -q "FLAG{PADME91562837}" "$TMP_DIR/job_verification.txt"; then
            success "✓ FLAG{PADME91562837} found in job-originating-user-name"
        else
            warning "✗ FLAG{PADME91562837} NOT found in jobs"
        fi
        
        if grep -q "FLAG{MACE41927365}" "$TMP_DIR/job_verification.txt"; then
            success "✓ FLAG{MACE41927365} found in job-name"
        else
            warning "✗ FLAG{MACE41927365} NOT found in jobs"
        fi
        
        # Display held jobs summary
        echo ""
        info "Held jobs summary:"
        grep -E "job-id|job-name|job-originating-user-name|job-state" "$TMP_DIR/job_verification.txt" | head -20
        
    else
        warning "Job verification failed - check log for details"
    fi
}

# Create manual configuration guide
create_manual_guide() {
    header "Creating Manual Configuration Guide"
    
    cat > "$TMP_DIR/MANUAL_CONFIG_GUIDE.txt" << EOF
═══════════════════════════════════════════════════════════════
    MANUAL CONFIGURATION GUIDE
    For flags that couldn't be deployed automatically
═══════════════════════════════════════════════════════════════

SNMP FLAGS (if Web API failed):
--------------------------------
Access: https://$PRINTER_IP
Login with admin credentials
Navigate to: Network → Identification

Set the following:
  System Name: HP-MFP-CTF-FLAG{HAN62947103}
  System Location: Server-Room-B | Discovery Code: FLAG{LUKE47239581}
  System Contact: SecTeam@lab.local | FLAG{LEIA83920174}
  System Description: HP Color LaserJet Pro MFP 4301 | Auth: FLAG{CHEWBACCA09832423}

ALTERNATIVE: Use SNMP if you have write community string:
  snmpset -v1 -c <community> $PRINTER_IP 1.3.6.1.2.1.1.5.0 s "HP-MFP-CTF-FLAG{HAN62947103}"
  snmpset -v1 -c <community> $PRINTER_IP 1.3.6.1.2.1.1.6.0 s "Server-Room-B | Discovery Code: FLAG{LUKE47239581}"
  snmpset -v1 -c <community> $PRINTER_IP 1.3.6.1.2.1.1.4.0 s "SecTeam@lab.local | FLAG{LEIA83920174}"

PRINT JOB FLAGS (if IPP failed):
---------------------------------
All jobs should be HELD in the queue (job-hold-until: indefinite)

To manually verify:
  ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test

Expected flags in job metadata:
  - job-originating-user-name: FLAG{PADME91562837}
  - job-name: CTF-Challenge-Job-FLAG{MACE41927365}

If jobs aren't held, manually recreate them:
  1. Use the test files in $TMP_DIR/print_flag*.test
  2. Ensure job-hold-until attribute is set to "indefinite"

VERIFICATION:
-------------
Check deployed flags:
  snmpget -v1 -c public $PRINTER_IP 1.3.6.1.2.1.1.6.0  # Location (FLAG 1)
  snmpget -v1 -c public $PRINTER_IP 1.3.6.1.2.1.1.4.0  # Contact (FLAG 2)
  snmpget -v1 -c public $PRINTER_IP 1.3.6.1.2.1.1.5.0  # Hostname (FLAG 3)
  
  curl -k https://$PRINTER_IP  # Web flags
  ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-printer-attributes.test
  ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test

STUDENT DISCOVERY COMMANDS:
---------------------------
For IPP job enumeration (FLAGS 8 & 12):
  
  # Create get-jobs.test:
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
  
  # Run it:
  ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test | grep -E "job-name|job-originating-user-name"

═══════════════════════════════════════════════════════════════
EOF
    
    success "Manual configuration guide created: $TMP_DIR/MANUAL_CONFIG_GUIDE.txt"
    cat "$TMP_DIR/MANUAL_CONFIG_GUIDE.txt"
}

# Main deployment
main() {
    deploy_web_api_flags
    deploy_ipp_print_jobs
    deploy_working_flags
    deploy_network_flag
    verify_held_jobs
    create_manual_guide
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ✓ ALTERNATIVE CTF DEPLOYMENT COMPLETE                                  ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    log "Deployment Summary:"
    info "Target Printer: $PRINTER_IP"
    info "Workspace: $TMP_DIR"
    info "Log File: $LOG_FILE"
    info "Manual Config Guide: $TMP_DIR/MANUAL_CONFIG_GUIDE.txt"
    info "Job Verification: $TMP_DIR/job_verification.txt"
    echo ""
    
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Review log file for any deployment failures"
    echo "2. Check job verification output above"
    echo "3. Follow manual configuration guide if needed"
    echo "4. Verify all flags are accessible"
    echo ""
    
    echo -e "${CYAN}Key IPP Job Flags:${NC}"
    echo "  FLAG{PADME91562837} - in job-originating-user-name"
    echo "  FLAG{MACE41927365} - in job-name"
    echo ""
    
    echo -e "${CYAN}CTF deployment complete! 🎯${NC}"
}

main
exit 0
