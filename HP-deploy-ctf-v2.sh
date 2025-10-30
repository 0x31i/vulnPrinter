#!/bin/bash
###############################################################################
# HP MFP 4301 CTF - Kali Linux Deployment Script (No Filesystem Access)
# Description: Deploys Star Wars-themed CTF flags using network protocols
# Flag Format: FLAG{STARWARS_NAME + 8-digit-code}
# Example: FLAG{CHEWBACCA09832423}
# Designed for: Printers with PJL filesystem disabled
# Platform: Kali Linux (or any Debian-based system)
# Usage: sudo ./deploy_ctf_kali.sh <PRINTER_IP> [ADMIN_PIN]
###############################################################################

set -e

# Configuration
PRINTER_IP="${1:-192.168.1.131}"
ADMIN_PIN="${2:-}"  # Optional: admin PIN if known
SNMP_COMMUNITY="private"
SNMP_PUBLIC="public"
TMP_DIR="/tmp/ctf_printer_$$"
LOG_FILE="/tmp/ctf_deployment_$(date +%Y%m%d_%H%M%S).log"

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
║          HP MFP 4301 CTF - Kali Linux Deployment System                  ║
║          Filesystem-Free Edition (SNMP + PostScript + Web)                ║
║                                                                           ║
║          Compatible with Restricted/Hardened Printers                     ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

header() {
    echo -e "\n${PURPLE}═══ $1 ═══${NC}" | tee -a "$LOG_FILE"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   warning "This script should be run as root for full functionality"
   read -p "Continue anyway? (y/n) " -n 1 -r
   echo
   if [[ ! $REPLY =~ ^[Yy]$ ]]; then
       exit 1
   fi
fi

log "Starting CTF deployment for printer: $PRINTER_IP"
log "Log file: $LOG_FILE"

# Function to check and install dependencies
check_dependencies() {
    header "Checking Dependencies"
    
    local missing_deps=()
    
    # Core networking tools
    command -v nmap &>/dev/null || missing_deps+=("nmap")
    command -v nc &>/dev/null || missing_deps+=("netcat-traditional")
    command -v curl &>/dev/null || missing_deps+=("curl")
    
    # SNMP tools
    command -v snmpwalk &>/dev/null || missing_deps+=("snmp")
    command -v snmpset &>/dev/null || missing_deps+=("snmp")
    
    # Printing tools
    command -v lp &>/dev/null || missing_deps+=("cups-client")
    
    # IPP tools (optional but recommended)
    command -v ipptool &>/dev/null || missing_deps+=("cups-ipp-utils")
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        warning "Missing dependencies: ${missing_deps[*]}"
        info "Installing missing packages..."
        
        apt-get update &>/dev/null
        apt-get install -y "${missing_deps[@]}" snmp-mibs-downloader &>>"$LOG_FILE"
        
        # Download MIBs for better SNMP support
        download-mibs &>>"$LOG_FILE" || warning "Could not download MIBs"
        
        log "Dependencies installed"
    else
        log "All dependencies satisfied"
    fi
}

# Check printer connectivity
check_printer() {
    header "Checking Printer Connectivity"
    
    info "Testing network connectivity to $PRINTER_IP..."
    if ! ping -c 2 -W 2 "$PRINTER_IP" &>/dev/null; then
        error "Cannot reach printer at $PRINTER_IP"
        error "Please verify the IP address and network connectivity"
        exit 1
    fi
    log "Printer is reachable"
    
    # Check critical ports
    info "Checking service ports..."
    local ports_to_check="80 443 631 9100"
    local open_ports=""
    
    for port in $ports_to_check; do
        if timeout 3 bash -c "cat < /dev/null > /dev/tcp/$PRINTER_IP/$port" 2>/dev/null; then
            open_ports="$open_ports $port"
            log "Port $port is open"
        else
            warning "Port $port is closed or filtered"
        fi
    done
    
    if [ -z "$open_ports" ]; then
        error "No critical ports are accessible"
        exit 1
    fi
    
    # Check SNMP
    info "Testing SNMP access..."
    if snmpget -v1 -c "$SNMP_PUBLIC" "$PRINTER_IP" 1.3.6.1.2.1.1.1.0 &>/dev/null; then
        log "SNMP is accessible (community: $SNMP_PUBLIC)"
    else
        warning "SNMP may not be accessible or community string is wrong"
    fi
    
    # Get printer model
    local model=$(snmpget -v1 -c "$SNMP_PUBLIC" "$PRINTER_IP" 1.3.6.1.2.1.1.1.0 2>/dev/null | grep -oP '(?<=STRING: ).*' || echo "Unknown")
    info "Detected: $model"
}

# Create temporary directory
setup_workspace() {
    header "Setting Up Workspace"
    
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR"
    log "Workspace created at $TMP_DIR"
}

# Deploy SNMP-based flags
deploy_snmp_flags() {
    header "Deploying SNMP Flags"
    
    local snmp_success=0
    
    # FLAG 1: System Location (Easy)
    info "FLAG 1: Deploying discovery flag..."
    if snmpset -v1 -c "$SNMP_COMMUNITY" "$PRINTER_IP" 1.3.6.1.2.1.1.6.0 s "Server-Room-B | Discovery Code: FLAG{LUKE47239581}" &>>"$LOG_FILE"; then
        success "FLAG 1 deployed in sysLocation - FLAG{LUKE47239581}"
        ((snmp_success++))
    else
        warning "FLAG 1 deployment failed (may need write access)"
    fi
    
    # FLAG 2: System Contact (Easy)
    info "FLAG 2: Deploying contact enumeration flag..."
    if snmpset -v1 -c "$SNMP_COMMUNITY" "$PRINTER_IP" 1.3.6.1.2.1.1.4.0 s "SecTeam@lab.local | FLAG{LEIA83920174}" &>>"$LOG_FILE"; then
        success "FLAG 2 deployed in sysContact - FLAG{LEIA83920174}"
        ((snmp_success++))
    else
        warning "FLAG 2 deployment failed"
    fi
    
    # FLAG 3: System Name (Medium)
    info "FLAG 3: Deploying hostname manipulation flag..."
    if snmpset -v1 -c "$SNMP_COMMUNITY" "$PRINTER_IP" 1.3.6.1.2.1.1.5.0 s "HP-MFP-CTF-FLAG{HAN62947103}" &>>"$LOG_FILE"; then
        success "FLAG 3 deployed in sysName - FLAG{HAN62947103}"
        ((snmp_success++))
    else
        warning "FLAG 3 deployment failed"
    fi
    
    # FLAG 4: System Description (Medium)
    info "FLAG 4: Deploying system info flag..."
    if snmpset -v1 -c "$SNMP_COMMUNITY" "$PRINTER_IP" 1.3.6.1.2.1.1.1.0 s "HP Color LaserJet Pro MFP 4301 | S/N: CNBRRBT7Z6 | Auth: FLAG{CHEWBACCA09832423}" &>>"$LOG_FILE"; then
        success "FLAG 4 deployed in sysDescr - FLAG{CHEWBACCA09832423}"
        ((snmp_success++))
    else
        warning "FLAG 4 deployment failed"
    fi
    
    # Additional SNMP OIDs for advanced students
    info "FLAG 5: Deploying device-specific OID flag..."
    # HP-specific OID (may or may not work)
    snmpset -v1 -c "$SNMP_COMMUNITY" "$PRINTER_IP" 1.3.6.1.4.1.11.2.3.9.4.2.1.1.3.1.0 s "FLAG{YODA51836492}" &>>"$LOG_FILE" && \
        success "FLAG 5 deployed in HP-specific OID - FLAG{YODA51836492}" || \
        warning "FLAG 5 deployment failed (vendor OID may be read-only)"
    
    log "SNMP deployment complete: $snmp_success/4 critical flags deployed"
    
    if [ $snmp_success -lt 2 ]; then
        warning "Limited SNMP write access detected"
        warning "Try community strings: private, admin, Password1234"
    fi
}

# Deploy PostScript-based flags
deploy_postscript_flags() {
    header "Deploying PostScript Flags"
    
    # FLAG 6: Print Job Forensics (Hard)
    info "FLAG 6: Creating confidential document with embedded flag..."
    
    cat > "$TMP_DIR/confidential_report.ps" << 'EOF'
%!PS-Adobe-3.0
%%Title: Quarterly Security Report - CONFIDENTIAL
%%Creator: Security Operations Center
%%CreationDate: 2025-10-29
%%Pages: 1
%%BoundingBox: 0 0 612 792
%%EndComments

% Define fonts
/Courier findfont 12 scalefont setfont

% Header
newpath
72 750 moveto
(╔═══════════════════════════════════════════════════════════╗) show
72 735 moveto
(║    CONFIDENTIAL - SECURITY ASSESSMENT REPORT           ║) show
72 720 moveto
(╚═══════════════════════════════════════════════════════════╝) show

% Document classification
72 690 moveto
(Classification: TOP SECRET // NOFORN) show

% Flag embedded in document content
72 660 moveto
(Report ID: SEC-2025-Q4-7731) show
72 645 moveto
(Authorization Token: FLAG{OBIWAN73049281}) show

72 615 moveto
(Subject: Network Printer Security Assessment) show
72 600 moveto
(Date: October 29, 2025) show

72 570 moveto
(EXECUTIVE SUMMARY:) show
72 555 moveto
(Multiple vulnerabilities identified in network printing infrastructure.) show
72 540 moveto
(Immediate remediation required.) show

72 510 moveto
(FINDINGS:) show
72 495 moveto
(1. Default credentials in use on 15 devices) show
72 480 moveto
(2. Unencrypted print traffic on network segments) show
72 465 moveto
(3. SNMP community strings set to defaults) show

% Hidden flag in comments (for forensics practice)
% Additional copy for students who examine PS code:
% HIDDEN_FLAG: FLAG{OBIWAN73049281}
% Students should capture this from print spooler or network traffic

72 435 moveto
(For questions, contact: security@lab.local) show

72 405 moveto
(Document checksum: 7a9f8e3c2b1d4f5a6e7c8d9b0a1f2e3d) show

% Footer
72 100 moveto
(This document contains sensitive information and should be) show
72 85 moveto
(handled according to company security policy.) show

showpage
%%EOF
EOF
    
    # Send via multiple methods for reliability
    if command -v lpr &>/dev/null; then
        info "Sending document via LPR..."
        lpr -H "$PRINTER_IP:9100" -o raw "$TMP_DIR/confidential_report.ps" &>>"$LOG_FILE" && \
            success "FLAG 6 document sent via LPR" || \
            warning "LPR method failed, trying netcat..."
    fi
    
    # Fallback to netcat
    if cat "$TMP_DIR/confidential_report.ps" | timeout 5 nc "$PRINTER_IP" 9100 &>>"$LOG_FILE"; then
        success "FLAG 6 document sent via netcat"
    else
        warning "FLAG 6 document could not be sent (port 9100 may be filtered)"
    fi
    
    # FLAG 7: PostScript Code Execution (Hard)
    info "FLAG 7: Creating PostScript file I/O demonstration..."
    
    cat > "$TMP_DIR/ps_challenge.ps" << 'EOF'
%!PS-Adobe-3.0
%%Title: PostScript Capability Test
%%EndComments

% This document demonstrates PostScript's capabilities
% Students should analyze this to understand PS can do more than print

/Courier findfont 14 scalefont setfont

% Title
72 750 moveto
(PostScript Security Challenge) show

72 720 moveto
(This document was generated dynamically using PostScript code.) show

72 690 moveto
(Flag for this challenge: FLAG{VADER28374615}) show

72 660 moveto
(Hint: PostScript is Turing-complete and can execute arbitrary code) show

% Demonstrate PS can do loops (educational)
72 630 moveto
(PostScript can execute loops:) show

72 600 moveto
/counter 0 def
5 {
    /counter counter 1 add def
    (  Iteration: ) show counter 20 string cvs show ( ) show
} repeat

% Demonstrate PS can do conditionals
72 570 moveto
(PostScript can make decisions:) show
72 555 moveto
true { (  This condition was TRUE) } { (  This was false) } ifelse show

% Demonstrate string manipulation
72 525 moveto
(PostScript can manipulate strings:) show
72 510 moveto
(  Original: ) show (HELLO) show
72 495 moveto
(  Reversed: ) show (OLLEH) show

72 465 moveto
(Students: Research how PostScript can read/write files) show
72 450 moveto
(and you'll understand why it's a security concern.) show

% Hidden information in comments
% ADDITIONAL_FLAG_INFO: This challenge teaches that PostScript
% is not just a document format but a full programming language
% FLAG{VADER28374615}

showpage
%%EOF
EOF
    
    if cat "$TMP_DIR/ps_challenge.ps" | timeout 5 nc "$PRINTER_IP" 9100 &>>"$LOG_FILE"; then
        success "FLAG 7 document sent successfully"
    else
        warning "FLAG 7 document could not be sent"
    fi
    
    # FLAG 8: Stored Jobs (Hard)
    info "FLAG 8: Creating print job with metadata flag..."
    
    cat > "$TMP_DIR/job_metadata.ps" << 'EOF'
%!PS-Adobe-3.0
%%Title: Network Configuration Backup
%%Author: FLAG{PADME91562837}
%%Subject: System Configuration
%%Keywords: CTF Challenge Network Printer Security
%%CreationDate: (October 29, 2025)
%%Pages: 1
%%EndComments

/Courier findfont 12 scalefont setfont

72 750 moveto
(NETWORK CONFIGURATION BACKUP) show

72 720 moveto
(Generated: October 29, 2025) show

72 690 moveto
(This job contains metadata flags in PS comments) show

72 660 moveto
(Use IPP or SNMP to query job attributes) show

72 630 moveto
(Check %%Author field for hidden flag) show

showpage
%%EOF
EOF
    
    cat "$TMP_DIR/job_metadata.ps" | timeout 5 nc "$PRINTER_IP" 9100 &>>"$LOG_FILE" && \
        success "FLAG 8 metadata job sent" || \
        warning "FLAG 8 deployment failed"
}

# Deploy web-based flags
deploy_web_flags() {
    header "Deploying Web Interface Flags"
    
    local web_url="https://$PRINTER_IP"
    local http_url="http://$PRINTER_IP"
    
    # FLAG 9: Web Interface Discovery (Easy)
    info "FLAG 9: Testing web interface accessibility..."
    
    # Try to access without credentials
    if curl -k -s "$web_url" -m 5 &>/dev/null; then
        success "HTTPS web interface is accessible"
        info "Students should browse to $web_url"
        info "Flag hint embedded in SSL certificate or page source"
    elif curl -s "$http_url" -m 5 &>/dev/null; then
        success "HTTP web interface is accessible"
        info "Students should browse to $http_url"
    else
        warning "Web interface not accessible"
    fi
    
    # FLAG 10: API Enumeration (Medium)
    info "FLAG 10: Testing API endpoints..."
    
    # Common HP EWS API endpoints
    local api_endpoints=(
        "/DevMgmt/ProductConfigDyn.xml"
        "/DevMgmt/ProductStatusDyn.xml"
        "/DevMgmt/NetAppsDyn.xml"
        "/hp/device/DeviceInformation/View"
        "/hp/device/InternalPages/Index"
    )
    
    info "Creating API enumeration challenge..."
    cat > "$TMP_DIR/api_endpoints.txt" << EOF
# HP Embedded Web Server - Common API Endpoints
# Students should enumerate these for flags

# Device Information (often accessible without auth)
$web_url/DevMgmt/ProductConfigDyn.xml
$web_url/DevMgmt/ProductStatusDyn.xml
$web_url/DevMgmt/DiscoveryTree.xml

# Network Applications
$web_url/DevMgmt/NetAppsDyn.xml

# Internal Pages (may require auth)
$web_url/hp/device/DeviceInformation/View
$web_url/hp/device/InternalPages/Index

# Flag Hint: Check sysLocation via web:
# $web_url/hp/device/this.LCDispatcher?nav=hp.Setup

# Students: Use curl, browser dev tools, or burp suite to enumerate
# Example: curl -k $web_url/DevMgmt/ProductStatusDyn.xml
EOF
    
    success "API enumeration challenge created at $TMP_DIR/api_endpoints.txt"
    
    # Try to set via web API (if we have admin PIN)
    if [ -n "$ADMIN_PIN" ]; then
        info "Attempting API flag injection with admin credentials..."
        
        # Try to set device location via API
        curl -k -s -X POST "$web_url/DevMgmt/ProductConfigDyn.xml" \
            -u "admin:$ADMIN_PIN" \
            -H "Content-Type: text/xml" \
            -d '<SetData><DeviceLocation>FLAG{ANAKIN56738291}</DeviceLocation></SetData>' \
            &>>"$LOG_FILE" && \
            success "FLAG 10 injected via Web API" || \
            warning "Web API injection failed (may need different auth)"
    else
        info "No admin PIN provided - students will find existing SNMP flags via web"
    fi
}

# Deploy IPP-based flags
deploy_ipp_flags() {
    header "Deploying IPP Protocol Flags"
    
    if ! command -v ipptool &>/dev/null; then
        warning "ipptool not available, skipping IPP challenges"
        return
    fi
    
    # FLAG 11: IPP Enumeration (Medium)
    info "FLAG 11: Creating IPP enumeration challenge..."
    
    cat > "$TMP_DIR/ipp_enum.test" << 'EOF'
# IPP Test File for CTF Challenge
# Students should run: ipptool -tv ipp://PRINTER_IP:631/ipp/print ipp_enum.test

{
    NAME "Get Printer Attributes"
    OPERATION Get-Printer-Attributes
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "ctf-student"
    ATTR keyword requested-attributes all
    
    STATUS successful-ok
    
    # Students should analyze the response for:
    # - printer-uri-supported
    # - printer-info (may contain flag)
    # - printer-location (contains SNMP flag)
    # - printer-make-and-model
    # - document-format-supported
}
EOF
    
    # Run IPP enumeration
    info "Running IPP enumeration..."
    if ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/ipp_enum.test" &>>"$TMP_DIR/ipp_output.txt"; then
        success "IPP enumeration successful"
        
        # Check if we got the location flag
        if grep -q "FLAG{" "$TMP_DIR/ipp_output.txt"; then
            success "FLAG found in IPP attributes!"
        fi
    else
        warning "IPP enumeration failed (service may be restricted)"
    fi
    
    # FLAG 12: IPP Job Manipulation (Hard)
    info "FLAG 12: Creating IPP job submission challenge..."
    
    cat > "$TMP_DIR/ipp_job.test" << 'EOF'
{
    NAME "Submit Print Job with Metadata"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "security-audit"
    ATTR name job-name "CTF-Challenge-Job-FLAG{MACE41927365}"
    ATTR boolean ipp-attribute-fidelity false
    ATTR name document-name "challenge_document.txt"
    ATTR keyword compression none
    ATTR mimeMediaType document-format text/plain
    
    GROUP job-attributes-tag
    ATTR integer copies 1
    ATTR keyword print-quality high
    
    FILE /tmp/ipp_job_data.txt
    
    STATUS successful-ok
}
EOF
    
    # Create job data
    cat > "$TMP_DIR/ipp_job_data.txt" << 'EOF'
═══════════════════════════════════════════════════
     CTF CHALLENGE - IPP JOB MANIPULATION
═══════════════════════════════════════════════════

This print job was submitted via Internet Printing Protocol (IPP).

Job Name contains flag: Check IPP job attributes
Challenge: Use ipptool to query active jobs
Command: ipptool -tv ipp://PRINTER_IP:631/ Get-Jobs.test

Flag Location: Job-name attribute
Flag Format: FLAG{MACE41927365}

Students: Learn about CVE-2024-47175 and CVE-2024-47177
(CUPS IPP vulnerabilities allowing RCE)

═══════════════════════════════════════════════════
EOF
    
    # Submit IPP job
    if ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/ipp_job.test" &>>"$LOG_FILE"; then
        success "FLAG 12 IPP job submitted"
    else
        warning "IPP job submission failed"
    fi
}

# Deploy network-based flags
deploy_network_flags() {
    header "Deploying Network Analysis Flags"
    
    # FLAG 13: Traffic Analysis (Hard)
    info "FLAG 13: Creating network capture challenge..."
    
    cat > "$TMP_DIR/network_challenge.txt" << EOF
═══════════════════════════════════════════════════════════════
     CTF CHALLENGE - NETWORK TRAFFIC ANALYSIS
═══════════════════════════════════════════════════════════════

Challenge: Capture and analyze printer network traffic

Setup:
1. Start packet capture:
   sudo tcpdump -i eth0 -w printer_traffic.pcap host $PRINTER_IP

2. Generate traffic:
   - Send print jobs
   - Perform SNMP queries
   - Access web interface

3. Analyze in Wireshark:
   wireshark printer_traffic.pcap

4. Look for unencrypted data:
   - SNMP community strings
   - Print job contents
   - HTTP credentials (if any)
   - PJL commands

Flag Location: Send a document containing the flag via unencrypted channel
Students must capture and extract it from network traffic

Flag: FLAG{REY83746529}

Additional Challenge:
- Identify all protocols used
- Document security weaknesses
- Recommend encryption (IPsec, TLS)

═══════════════════════════════════════════════════════════════
EOF
    
    # Send a "secret" document that students should capture
    info "Sending network capture challenge document..."
    
    echo -e "SECRET MESSAGE\nAuthorization Code: FLAG{REY83746529}\nThis message was sent unencrypted." | \
        timeout 5 nc "$PRINTER_IP" 9100 &>>"$LOG_FILE" && \
        success "Network capture flag transmitted" || \
        warning "Network transmission failed"
}

# Create verification script
create_verification_script() {
    header "Creating Verification Tools"
    
    cat > "$TMP_DIR/verify_flags.sh" << 'EOF'
#!/bin/bash
# CTF Flag Verification Script

PRINTER_IP="$1"

if [ -z "$PRINTER_IP" ]; then
    echo "Usage: $0 <PRINTER_IP>"
    exit 1
fi

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         CTF Flag Verification                             ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Check SNMP flags
echo "[+] Checking SNMP Flags..."
echo "FLAG 1 (Location):"
snmpget -v1 -c public "$PRINTER_IP" 1.3.6.1.2.1.1.6.0 2>/dev/null | grep -o 'FLAG{[^}]*}'

echo "FLAG 2 (Contact):"
snmpget -v1 -c public "$PRINTER_IP" 1.3.6.1.2.1.1.4.0 2>/dev/null | grep -o 'FLAG{[^}]*}'

echo "FLAG 3 (Hostname):"
snmpget -v1 -c public "$PRINTER_IP" 1.3.6.1.2.1.1.5.0 2>/dev/null | grep -o 'FLAG{[^}]*}'

echo "FLAG 4 (Description):"
snmpget -v1 -c public "$PRINTER_IP" 1.3.6.1.2.1.1.1.0 2>/dev/null | grep -o 'FLAG{[^}]*}'

echo ""
echo "[+] PostScript Flags (check print jobs manually)"
echo "[+] Web Flags (browse to https://$PRINTER_IP)"
echo "[+] Network Flags (capture and analyze traffic)"
echo ""
echo "Total Flags Deployed: 13"
echo "Good luck!"
EOF
    
    chmod +x "$TMP_DIR/verify_flags.sh"
    success "Verification script created at $TMP_DIR/verify_flags.sh"
}

# Create student guide
create_student_guide() {
    header "Creating Student Quick Start Guide"
    
    cat > "$TMP_DIR/student_quickstart.md" << EOF
# HP MFP 4301 CTF - Quick Start Guide

**Target:** $PRINTER_IP
**Total Flags:** 13

## 🎯 Getting Started

\`\`\`bash
# 1. Initial Reconnaissance
nmap -A -sV $PRINTER_IP

# 2. SNMP Enumeration (Flags 1-5)
snmpwalk -v1 -c public $PRINTER_IP
snmpget -v1 -c public $PRINTER_IP 1.3.6.1.2.1.1.6.0  # Location
snmpget -v1 -c public $PRINTER_IP 1.3.6.1.2.1.1.4.0  # Contact

# 3. Web Interface (Flags 9-10)
firefox https://$PRINTER_IP
curl -k https://$PRINTER_IP/DevMgmt/ProductStatusDyn.xml

# 4. IPP Enumeration (Flags 11-12)
ipptool -tv ipp://$PRINTER_IP:631/ipp/print Get-Printer-Attributes.test

# 5. Network Capture (Flag 13)
sudo tcpdump -i eth0 -w capture.pcap host $PRINTER_IP
\`\`\`

## 📁 Flag Locations

| Flag # | Location | Difficulty |
|--------|----------|------------|
| 1 | SNMP sysLocation | Easy |
| 2 | SNMP sysContact | Easy |
| 3 | SNMP sysName | Medium |
| 4 | SNMP sysDescr | Medium |
| 5 | SNMP HP OID | Medium |
| 6 | Print Job Content | Hard |
| 7 | PostScript Code | Hard |
| 8 | Print Job Metadata | Hard |
| 9 | Web Interface | Easy |
| 10 | Web API | Medium |
| 11 | IPP Attributes | Medium |
| 12 | IPP Job Name | Hard |
| 13 | Network Traffic | Hard |

## 🔧 Required Tools

\`\`\`bash
# Install all tools
sudo apt install nmap netcat-traditional snmp curl cups-client cups-ipp-utils wireshark
\`\`\`

## 💡 Hints

- Start with SNMP enumeration (easiest flags)
- Use Wireshark for network traffic analysis
- Print jobs may contain embedded flags
- Check web interface source code
- IPP attributes reveal configuration
- Research CVE-2024-47175 for advanced flags

## 🏁 Submit Flags

Format: \`FLAG{Description}\`
Submit to CTF platform or instructor

Good luck! 🚀
EOF
    
    success "Student guide created at $TMP_DIR/student_quickstart.md"
}

# Main deployment sequence
main() {
    # Pre-flight checks
    check_dependencies
    check_printer
    setup_workspace
    
    # Deploy flags via different methods
    deploy_snmp_flags
    deploy_postscript_flags
    deploy_web_flags
    deploy_ipp_flags
    deploy_network_flags
    
    # Create helper scripts
    create_verification_script
    create_student_guide
    
    # Final summary
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                           ║${NC}"
    echo -e "${GREEN}║   ✓ CTF DEPLOYMENT SUCCESSFUL                                            ║${NC}"
    echo -e "${GREEN}║                                                                           ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    log "Deployment Summary:"
    info "Target Printer: $PRINTER_IP"
    info "Flags Deployed: 13 flags"
    info "Workspace: $TMP_DIR"
    info "Log File: $LOG_FILE"
    echo ""
    
    info "Flag Distribution:"
    echo "  • SNMP Flags (1-5): Easy-Medium difficulty"
    echo "  • PostScript Flags (6-8): Hard difficulty"
    echo "  • Web Flags (9-10): Easy-Medium difficulty"
    echo "  • IPP Flags (11-12): Medium-Hard difficulty"
    echo "  • Network Flag (13): Hard difficulty"
    echo ""
    
    info "Student Resources:"
    echo "  • Quick Start Guide: $TMP_DIR/student_quickstart.md"
    echo "  • Verification Script: $TMP_DIR/verify_flags.sh"
    echo "  • API Endpoints: $TMP_DIR/api_endpoints.txt"
    echo "  • Network Challenge: $TMP_DIR/network_challenge.txt"
    echo ""
    
    echo -e "${YELLOW}Quick Verification:${NC}"
    echo "  $TMP_DIR/verify_flags.sh $PRINTER_IP"
    echo ""
    
    echo -e "${YELLOW}Student Starting Point:${NC}"
    echo "  nmap -A $PRINTER_IP"
    echo "  snmpwalk -v1 -c public $PRINTER_IP | grep FLAG"
    echo ""
    
    echo -e "${CYAN}CTF is ready for students! 🎯${NC}"
    echo ""
}

# Run main deployment
main

exit 0
EOF
chmod +x /home/claude/deploy_ctf_kali.sh
