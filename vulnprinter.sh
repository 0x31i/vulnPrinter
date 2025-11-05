#!/bin/bash
################################################################################
# HP Printer CTF Flag Deployment - Complete Version
# Includes: Flag Placement + Realistic print job simulation
################################################################################

PRINTER_IP="192.168.1.131"
PRINTER_URI="ipp://${PRINTER_IP}:631/ipp/print"
TMP_DIR="/tmp/ctf_printer_$$"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     HP Printer CTF Flag Deployment                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Create workspace
mkdir -p "$TMP_DIR"

################################################################################
# SNMP FLAGS
################################################################################

echo -e "${BLUE}[1/3]${NC} Deploying SNMP flags..."
echo ""

# LUKE flag - visible in both SNMP and IPP
echo "  → Deploying FLAG{LUKE47239581} via SNMP sysLocation..."
snmpset -v2c -c public ${PRINTER_IP} 1.3.6.1.2.1.1.6.0 s "OC-Server-Room-B | FLAG{LUKE47239581}"

# LEIA flag - visible ONLY in SNMP (not IPP)
echo "  → Deploying FLAG{LEIA83920174} via SNMP sysContact..."
snmpset -v2c -c public ${PRINTER_IP} 1.3.6.1.2.1.1.4.0 s "OVERCLOCK@OC.local | FLAG{LEIA83920174}"

echo ""

################################################################################
# PRINT JOB FLAGS (PostScript Method - Creates "Guest: Print" Jobs)
################################################################################

echo -e "${BLUE}[2/3]${NC} Creating realistic print jobs with flags..."
echo ""

# Create PostScript document with PADME and MACE flags
cat > "$TMP_DIR/ctf_job_1.ps" << 'EOF'
%!PS-Adobe-3.0
%%Title: OVERCLOCK Report - Security Assessment
%%Author: FLAG{PADME91562837}
%%CreationDate: 2025-11-04
%%Pages: 1
%%BoundingBox: 0 0 612 792
%%EndComments

/Courier findfont 12 scalefont setfont

% Header
newpath
72 750 moveto
(╔═══════════════════════════════════════════════════════════╗) show
72 735 moveto
(║    OVERCLOCK REPORT- SECURITY ASSESSMENT                  ║) show
72 720 moveto
(╚═══════════════════════════════════════════════════════════╝) show

% Document info
72 690 moveto
(Document Classification: CONFIDENTIAL) show

72 660 moveto
(Job ID: OVERCLOCK-Job-FLAG{MACE41927365}) show

72 630 moveto
(Submitted By: FLAG{PADME91562837}) show

72 600 moveto
(Date: November 4, 2025) show

72 570 moveto
(Subject: Network Printer Security Assessment) show

72 540 moveto
(SUMMARY:) show
72 525 moveto
(Multiple flags hidden in printer protocols and job metadata.) show

72 495 moveto
(Students must enumerate:) show
72 480 moveto
(  - SNMP protocol for configuration flags) show
72 465 moveto
(  - IPP protocol for printer and job attributes) show
72 450 moveto
(  - Print job history and metadata) show

72 420 moveto
(This document demonstrates job submission via PostScript.) show

72 390 moveto
(Check %%Author and job-name fields for flags!) show

showpage
%%EOF
EOF

# Create second document for variety
cat > "$TMP_DIR/ctf_job_2.ps" << 'EOF'
%!PS-Adobe-3.0
%%Title: Network Configuration Report
%%Author: Security-Audit-Team
%%Pages: 1
%%EndComments

/Courier findfont 11 scalefont setfont

72 750 moveto
(NETWORK CONFIGURATION REPORT) show

72 720 moveto
(This document was generated as part of the OC challenge.) show

72 690 moveto
(Print jobs contain metadata that can be queried via IPP.) show

72 660 moveto
(Use ipptool with Get-Jobs operation to find flags.) show

showpage
%%EOF
EOF

# Create third document
cat > "$TMP_DIR/ctf_job_3.ps" << 'EOF'
%!PS-Adobe-3.0
%%Title: Security Assessment Results
%%Pages: 1
%%EndComments

/Courier findfont 10 scalefont setfont

72 750 moveto
(SECURITY ASSESSMENT - Q4 2025) show

72 720 moveto
(Multiple vulnerabilities identified in printer infrastructure.) show

showpage
%%EOF
EOF

# Send jobs using multiple methods for reliability
echo "  → Sending print job 1 (with PADME & MACE flags)..."

# Method 1: Try lpr if available
if command -v lpr &>/dev/null; then
    lpr -H "${PRINTER_IP}:9100" -o raw "$TMP_DIR/ctf_job_1.ps" 2>/dev/null && \
        echo -e "    ${GREEN}${NC} Job 1 sent via lpr" || \
        echo -e "    ${YELLOW}${NC} lpr failed, trying netcat..."
fi

# Method 2: Netcat with timeout (fallback)
(timeout 3 cat "$TMP_DIR/ctf_job_1.ps" | nc -w 2 ${PRINTER_IP} 9100 2>/dev/null) && \
    echo -e "    ${GREEN}${NC} Job 1 sent via netcat" || \
    echo -e "    ${RED}${NC} Job 1 failed"

sleep 1

# Send additional jobs to simulate realistic activity
echo "  → Sending additional print jobs..."

for i in 2 3; do
    if [ -f "$TMP_DIR/ctf_job_${i}.ps" ]; then
        (timeout 3 cat "$TMP_DIR/ctf_job_${i}.ps" | nc -w 2 ${PRINTER_IP} 9100 2>/dev/null) && \
            echo -e "    ${GREEN}${NC} Job ${i} sent" || \
            echo -e "    ${YELLOW}${NC} Job ${i} may have failed"
        sleep 1
    fi
done

echo ""
echo "  → Waiting for jobs to appear in queue..."
sleep 3

################################################################################
# MANUAL CONFIGURATION
################################################################################

echo -e "${BLUE}[3/3]${NC} Manual web configuration required for HAN flag:"
echo ""
echo "  URL: https://${PRINTER_IP}"
echo "  Path: General → About The Printer → Configure Information → Nickname"
echo "  Value: HP-MFP-FLAG{HAN62947103}"
echo ""
read -p "Press ENTER when HAN flag is configured..." 
echo ""

################################################################################
# VERIFICATION
################################################################################

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    VERIFICATION                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Verify SNMP flags
echo -e "${BLUE}[SNMP]${NC} Checking sysLocation and sysContact..."
snmpget -v2c -c public ${PRINTER_IP} 1.3.6.1.2.1.1.6.0 2>/dev/null | grep -o "FLAG{[^}]*}"
snmpget -v2c -c public ${PRINTER_IP} 1.3.6.1.2.1.1.4.0 2>/dev/null | grep -o "FLAG{[^}]*}"
echo ""

# Verify print jobs - check UPCOMING queue
echo -e "${BLUE}[IPP]${NC} Checking print jobs in queue..."

cat > "$TMP_DIR/check-all-jobs.test" << 'EOF'
{
    NAME "Check All Jobs"
    OPERATION Get-Jobs
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR keyword which-jobs not-completed
    ATTR keyword requested-attributes all
    STATUS successful-ok
}
EOF

echo "  Checking not-completed (upcoming) jobs:"
if ipptool -tv ${PRINTER_URI} "$TMP_DIR/check-all-jobs.test" 2>/dev/null | grep -E "job-originating-user-name|job-name" | grep -q FLAG; then
    ipptool -tv ${PRINTER_URI} "$TMP_DIR/check-all-jobs.test" 2>/dev/null | grep -E "job-originating-user-name|job-name" | grep FLAG
    echo -e "  ${GREEN}${NC} Flags found in upcoming jobs!"
else
    echo "  Checking completed jobs (history):"
    
    cat > "$TMP_DIR/check-completed-jobs.test" << 'EOF'
{
    NAME "Check Completed Jobs"
    OPERATION Get-Jobs
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR keyword which-jobs completed
    ATTR keyword requested-attributes all
    STATUS successful-ok
}
EOF
    
    ipptool -tv ${PRINTER_URI} "$TMP_DIR/check-completed-jobs.test" 2>/dev/null | grep -E "job-originating-user-name|job-name" | grep FLAG
fi

rm -f "$TMP_DIR/check-*.test"
echo ""

# Verify IPP printer attributes
echo -e "${BLUE}[IPP]${NC} Checking printer attributes..."

cat > "$TMP_DIR/check-attrs.test" << 'EOF'
{
    NAME "Check Attributes"
    OPERATION Get-Printer-Attributes
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR keyword requested-attributes all
    STATUS successful-ok
}
EOF

ipptool -tv ${PRINTER_URI} "$TMP_DIR/check-attrs.test" 2>/dev/null | grep -E "printer-info|printer-name|printer-location" | grep FLAG

rm -f "$TMP_DIR/check-attrs.test"
echo ""

# Cleanup
rm -rf "$TMP_DIR"

################################################################################
# DEPLOYMENT SUMMARY
################################################################################

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                  DEPLOYMENT COMPLETE                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Deployed Flags:"
echo "  • FLAG{LUKE47239581}  - SNMP sysLocation + IPP printer-location"
echo "  • FLAG{LEIA83920174}  - SNMP sysContact (SNMP ONLY)"
echo "  • FLAG{HAN62947103}   - Web Interface → IPP printer-info"
echo "  • FLAG{PADME91562837} - Print job %%Author attribute"
echo "  • FLAG{MACE41927365}  - Print job %%Title / job-name"
echo ""
echo "Print Jobs Created:"
echo "  • 3 PostScript documents submitted"
echo "  • Jobs should appear as 'Guest: Print' in queue"
echo "  • Check web interface Job Queue for visual confirmation"
echo ""
echo "Student Discovery Commands:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "# SNMP Enumeration (finds LUKE + LEIA)"
echo "snmpwalk -v2c -c public ${PRINTER_IP} 1.3.6.1.2.1.1"
echo ""
echo "# IPP Printer Attributes (finds LUKE + HAN)"
echo "ipptool -tv ipp://${PRINTER_IP}:631/ipp/print get-printer-attributes.test | grep FLAG"
echo ""
echo "# IPP Print Jobs - Try not-completed first (finds PADME + MACE)"
echo "ipptool -tv ipp://${PRINTER_IP}:631/ipp/print get-jobs.test | grep FLAG"
echo ""
echo "# If not in upcoming queue, check completed:"
echo "ipptool -tv ipp://${PRINTER_IP}:631/ipp/print get-completed-jobs.test | grep FLAG"
echo ""
echo "Teaching Points:"
echo "  • LEIA flag demonstrates SNMP-only information"
echo "  • Print jobs may be in 'upcoming' or 'completed' state"
echo "  • Students must query both job states for thorough enumeration"
echo "  • PostScript documents contain metadata with flags"
echo ""

exit 0
