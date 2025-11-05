#!/bin/bash
################################################################################
# HP Color LaserJet Pro MFP 4301 CTF Flag Deployment Script
# 
# This script deploys multiple flags across different protocols to teach
# students that comprehensive enumeration requires multiple tools.
#
# Flag Distribution:
#   - FLAG{LUKE47239581}  : SNMP sysLocation → Shows in IPP printer-location
#   - FLAG{LEIA83920174}  : SNMP sysContact  → Shows in SNMP ONLY (not IPP)
#   - FLAG{HAN62947103}   : Manual web setup → Shows in IPP printer-info
#   - FLAG{PADME91562837} : IPP print job    → Shows in IPP job metadata
#   - FLAG{MACE41927365}  : IPP job name     → Shows in IPP job metadata
#
# Pedagogical Value:
#   Students learn that IPP alone is insufficient - they must use SNMP
#   enumeration tools (snmpwalk, snmp_enum, etc.) to find all flags.
#
################################################################################

set -e

# Configuration
PRINTER_IP="192.168.1.131"
PRINTER_URI="ipp://${PRINTER_IP}:631/ipp/print"
SNMP_COMMUNITY="public"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║     HP Printer CTF Flag Deployment Script                     ║
║     Multi-Protocol Enumeration Challenge                      ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

################################################################################
# PRE-FLIGHT CHECKS
################################################################################

echo -e "${YELLOW}[PREFLIGHT]${NC} Running pre-deployment checks...\n"

# Check if running as root (needed for some SNMP operations)
if [[ $EUID -eq 0 ]]; then
   echo -e "${YELLOW}⚠️  Running as root${NC}"
fi

# Check printer connectivity
echo -e "${BLUE}[1/6]${NC} Testing printer connectivity..."
if ! ping -c 2 -W 2 ${PRINTER_IP} &>/dev/null; then
    echo -e "${RED}❌ ERROR: Cannot reach printer at ${PRINTER_IP}${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Printer is reachable${NC}\n"

# Check required tools
echo -e "${BLUE}[2/6]${NC} Checking required tools..."
MISSING_TOOLS=()

if ! command -v snmpset &>/dev/null; then
    MISSING_TOOLS+=("snmp (install: apt install snmp)")
fi

if ! command -v ipptool &>/dev/null; then
    MISSING_TOOLS+=("ipptool (install: apt install cups-ipp-utils)")
fi

if ! command -v nc &>/dev/null; then
    MISSING_TOOLS+=("netcat (install: apt install netcat)")
fi

if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo -e "${RED}❌ Missing required tools:${NC}"
    for tool in "${MISSING_TOOLS[@]}"; do
        echo -e "   - $tool"
    done
    exit 1
fi
echo -e "${GREEN}✅ All required tools installed${NC}\n"

# Check SNMP access
echo -e "${BLUE}[3/6]${NC} Testing SNMP access..."
if ! snmpget -v2c -c ${SNMP_COMMUNITY} ${PRINTER_IP} 1.3.6.1.2.1.1.1.0 &>/dev/null; then
    echo -e "${RED}❌ ERROR: SNMP not accessible (check community string)${NC}"
    exit 1
fi
echo -e "${GREEN}✅ SNMP is accessible${NC}\n"

# Check IPP access
echo -e "${BLUE}[4/6]${NC} Testing IPP service..."
if ! nc -zv ${PRINTER_IP} 631 2>&1 | grep -q "succeeded"; then
    echo -e "${RED}❌ ERROR: IPP port 631 is not accessible${NC}"
    exit 1
fi
echo -e "${GREEN}✅ IPP service is available${NC}\n"

################################################################################
# FLAG DEPLOYMENT: SNMP FLAGS
################################################################################

echo -e "${YELLOW}[DEPLOYMENT]${NC} Deploying SNMP-based flags...\n"

# Deploy LUKE flag via SNMP sysLocation
echo -e "${BLUE}[5/6]${NC} Deploying FLAG{LUKE47239581} via SNMP sysLocation..."

LUKE_VALUE="Server-Room-B | Discovery Code: FLAG{LUKE47239581}"
if snmpset -v2c -c ${SNMP_COMMUNITY} ${PRINTER_IP} 1.3.6.1.2.1.1.6.0 s "${LUKE_VALUE}" &>/dev/null; then
    # Verify it was set
    LUKE_CHECK=$(snmpget -v2c -c ${SNMP_COMMUNITY} ${PRINTER_IP} 1.3.6.1.2.1.1.6.0 2>/dev/null | grep -o 'FLAG{LUKE47239581}')
    if [[ "$LUKE_CHECK" == "FLAG{LUKE47239581}" ]]; then
        echo -e "${GREEN}✅ LUKE flag deployed successfully${NC}"
        echo -e "   ${BLUE}→ Protocol:${NC} SNMP OID 1.3.6.1.2.1.1.6.0 (sysLocation)"
        echo -e "   ${BLUE}→ Visibility:${NC} Both SNMP AND IPP (printer-location)"
    else
        echo -e "${YELLOW}⚠️  LUKE flag set but verification failed${NC}"
    fi
else
    echo -e "${RED}❌ Failed to set LUKE flag via SNMP${NC}"
fi
echo ""

# Deploy LEIA flag via SNMP sysContact
echo -e "${BLUE}[6/6]${NC} Deploying FLAG{LEIA83920174} via SNMP sysContact..."

LEIA_VALUE="SecTeam@lab.local | FLAG{LEIA83920174}"
if snmpset -v2c -c ${SNMP_COMMUNITY} ${PRINTER_IP} 1.3.6.1.2.1.1.4.0 s "${LEIA_VALUE}" &>/dev/null; then
    # Verify it was set
    LEIA_CHECK=$(snmpget -v2c -c ${SNMP_COMMUNITY} ${PRINTER_IP} 1.3.6.1.2.1.1.4.0 2>/dev/null | grep -o 'FLAG{LEIA83920174}')
    if [[ "$LEIA_CHECK" == "FLAG{LEIA83920174}" ]]; then
        echo -e "${GREEN}✅ LEIA flag deployed successfully${NC}"
        echo -e "   ${BLUE}→ Protocol:${NC} SNMP OID 1.3.6.1.2.1.1.4.0 (sysContact)"
        echo -e "   ${BLUE}→ Visibility:${NC} SNMP ONLY (not visible in IPP!)"
        echo -e "   ${YELLOW}→ Teaching Point:${NC} Students must use SNMP enumeration"
    else
        echo -e "${YELLOW}⚠️  LEIA flag set but verification failed${NC}"
    fi
else
    echo -e "${RED}❌ Failed to set LEIA flag via SNMP${NC}"
fi
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

################################################################################
# FLAG DEPLOYMENT: IPP PRINT JOB FLAGS
################################################################################

echo -e "${YELLOW}[DEPLOYMENT]${NC} Deploying IPP print job flags...\n"

# Create the print job document
cat > /tmp/ctf_challenge_document.txt << 'EOF'
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║               CTF CHALLENGE DOCUMENT                           ║
║               TOP SECRET - AUTHORIZED PERSONNEL ONLY           ║
║                                                                ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║  This document is part of a multi-protocol enumeration         ║
║  challenge. Flags are hidden across multiple discovery         ║
║  methods:                                                      ║
║                                                                ║
║  • SNMP enumeration (snmpwalk, snmp_enum module)              ║
║  • IPP printer attributes (ipptool)                            ║
║  • IPP print job metadata (ipptool Get-Jobs)                   ║
║  • PJL filesystem access (PRET toolkit)                        ║
║                                                                ║
║  HINT: One protocol alone is insufficient. You must combine    ║
║        multiple enumeration techniques to find all flags.      ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

Document Classification: CONFIDENTIAL
Security Level: RESTRICTED
Access Control: NEED-TO-KNOW BASIS

This print job was submitted by a security audit team conducting
vulnerability assessments of network printing infrastructure.

The job metadata contains additional information that may be of
interest to penetration testers conducting IoT device enumeration.
EOF

echo -e "${BLUE}[1/2]${NC} Creating IPP test file for job submission..."

# Create IPP test file for job submission
cat > /tmp/submit-ctf-job.test << 'EOF'
{
    NAME "Submit CTF Challenge Print Job"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "FLAG{PADME91562837}"
    ATTR name job-name "CTF-Challenge-Job-FLAG{MACE41927365}"
    ATTR keyword job-hold-until indefinite
    
    FILE /tmp/ctf_challenge_document.txt
    
    STATUS successful-ok
}
EOF

echo -e "${BLUE}[2/2]${NC} Submitting print job with PADME and MACE flags..."

# Submit the job
if ipptool -tv ${PRINTER_URI} /tmp/submit-ctf-job.test &>/dev/null; then
    echo -e "${GREEN}✅ Print job submitted successfully${NC}"
    echo -e "   ${BLUE}→ Job User:${NC} FLAG{PADME91562837}"
    echo -e "   ${BLUE}→ Job Name:${NC} CTF-Challenge-Job-FLAG{MACE41927365}"
    echo -e "   ${BLUE}→ Job State:${NC} Held (indefinite)"
    echo -e "   ${BLUE}→ Discovery:${NC} ipptool Get-Jobs operation"
else
    echo -e "${RED}❌ Failed to submit print job${NC}"
fi

# Cleanup temporary files
rm -f /tmp/ctf_challenge_document.txt /tmp/submit-ctf-job.test

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

################################################################################
# MANUAL CONFIGURATION REMINDER
################################################################################

echo -e "${YELLOW}[MANUAL SETUP REQUIRED]${NC} Web Interface Configuration\n"

echo -e "${BLUE}FLAG{HAN62947103}${NC} must be configured manually:"
echo -e ""
echo -e "  ${YELLOW}1.${NC} Open web browser and navigate to:"
echo -e "     ${BLUE}https://${PRINTER_IP}${NC}"
echo -e ""
echo -e "  ${YELLOW}2.${NC} Login with administrator credentials"
echo -e ""
echo -e "  ${YELLOW}3.${NC} Navigate to: ${BLUE}Settings → Network → General${NC}"
echo -e ""
echo -e "  ${YELLOW}4.${NC} Set the following value:"
echo -e "     ${GREEN}Device Name:${NC} HP-MFP-CTF-FLAG{HAN62947103}"
echo -e ""
echo -e "  ${YELLOW}5.${NC} Click ${GREEN}Apply${NC} to save changes"
echo -e ""
echo -e "${YELLOW}⚠️  This flag appears ONLY in IPP printer-info attribute${NC}"
echo -e ""

read -p "Press ENTER once manual configuration is complete..." -r
echo ""

################################################################################
# VERIFICATION
################################################################################

echo -e "${YELLOW}[VERIFICATION]${NC} Checking deployed flags...\n"

# Verify SNMP flags
echo -e "${BLUE}SNMP Enumeration Results:${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SNMP_LOCATION=$(snmpget -v2c -c ${SNMP_COMMUNITY} ${PRINTER_IP} 1.3.6.1.2.1.1.6.0 2>/dev/null | cut -d '"' -f 2)
SNMP_CONTACT=$(snmpget -v2c -c ${SNMP_COMMUNITY} ${PRINTER_IP} 1.3.6.1.2.1.1.4.0 2>/dev/null | cut -d '"' -f 2)

if [[ "$SNMP_LOCATION" == *"LUKE47239581"* ]]; then
    echo -e "${GREEN}✅ sysLocation (1.3.6.1.2.1.1.6.0):${NC}"
    echo -e "   $SNMP_LOCATION"
else
    echo -e "${RED}❌ LUKE flag not found in SNMP sysLocation${NC}"
fi

if [[ "$SNMP_CONTACT" == *"LEIA83920174"* ]]; then
    echo -e "${GREEN}✅ sysContact (1.3.6.1.2.1.1.4.0):${NC}"
    echo -e "   $SNMP_CONTACT"
else
    echo -e "${RED}❌ LEIA flag not found in SNMP sysContact${NC}"
fi

echo -e "\n${BLUE}IPP Printer Attributes:${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create test file for printer attributes
cat > /tmp/get-printer-attributes.test << 'EOF'
{
    NAME "Get Printer Attributes"
    OPERATION Get-Printer-Attributes
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR keyword requested-attributes printer-location,printer-contact,printer-info
    STATUS successful-ok
}
EOF

IPP_ATTRS=$(ipptool -tv ${PRINTER_URI} /tmp/get-printer-attributes.test 2>/dev/null)

if echo "$IPP_ATTRS" | grep -q "LUKE47239581"; then
    echo -e "${GREEN}✅ printer-location:${NC}"
    echo "$IPP_ATTRS" | grep "printer-location" | sed 's/^/   /'
else
    echo -e "${RED}❌ LUKE flag not found in IPP printer-location${NC}"
fi

if echo "$IPP_ATTRS" | grep -q "LEIA83920174"; then
    echo -e "${GREEN}✅ printer-contact:${NC}"
    echo "$IPP_ATTRS" | grep "printer-contact" | sed 's/^/   /'
    echo -e "${YELLOW}   ⚠️  UNEXPECTED: LEIA should only be in SNMP!${NC}"
else
    echo -e "${YELLOW}⚠️  printer-contact:${NC} LEIA flag not visible (expected)"
    echo -e "   ${BLUE}→ Students must use SNMP enumeration${NC}"
fi

if echo "$IPP_ATTRS" | grep -q "HAN62947103"; then
    echo -e "${GREEN}✅ printer-info:${NC}"
    echo "$IPP_ATTRS" | grep "printer-info" | sed 's/^/   /'
else
    echo -e "${RED}❌ HAN flag not found in IPP printer-info${NC}"
    echo -e "   ${YELLOW}→ Complete manual configuration via web interface${NC}"
fi

rm -f /tmp/get-printer-attributes.test

echo -e "\n${BLUE}IPP Print Jobs:${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create test file for jobs
cat > /tmp/get-jobs.test << 'EOF'
{
    NAME "Get All Print Jobs"
    OPERATION Get-Jobs
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR keyword requested-attributes all
    ATTR keyword which-jobs all
    STATUS successful-ok
}
EOF

IPP_JOBS=$(ipptool -tv ${PRINTER_URI} /tmp/get-jobs.test 2>/dev/null)

if echo "$IPP_JOBS" | grep -q "PADME91562837"; then
    echo -e "${GREEN}✅ job-originating-user-name:${NC}"
    echo "$IPP_JOBS" | grep "job-originating-user-name" | grep "PADME" | sed 's/^/   /'
else
    echo -e "${RED}❌ PADME flag not found in print jobs${NC}"
fi

if echo "$IPP_JOBS" | grep -q "MACE41927365"; then
    echo -e "${GREEN}✅ job-name:${NC}"
    echo "$IPP_JOBS" | grep "job-name" | grep "MACE" | sed 's/^/   /'
else
    echo -e "${RED}❌ MACE flag not found in print jobs${NC}"
fi

rm -f /tmp/get-jobs.test

################################################################################
# DEPLOYMENT SUMMARY
################################################################################

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                   DEPLOYMENT COMPLETE                          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo -e ""

echo -e "${BLUE}Deployed Flags Summary:${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e ""
echo -e "  ${GREEN}✓${NC} FLAG{LUKE47239581}    ${BLUE}→${NC} SNMP sysLocation + IPP printer-location"
echo -e "  ${GREEN}✓${NC} FLAG{LEIA83920174}    ${BLUE}→${NC} SNMP sysContact (NOT in IPP)"
echo -e "  ${YELLOW}?${NC} FLAG{HAN62947103}     ${BLUE}→${NC} Manual web config → IPP printer-info"
echo -e "  ${GREEN}✓${NC} FLAG{PADME91562837}   ${BLUE}→${NC} IPP job-originating-user-name"
echo -e "  ${GREEN}✓${NC} FLAG{MACE41927365}    ${BLUE}→${NC} IPP job-name"
echo -e ""

echo -e "${BLUE}Student Discovery Commands:${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e ""
echo -e "${YELLOW}# SNMP Enumeration (LUKE + LEIA flags)${NC}"
echo -e "snmpwalk -v2c -c public ${PRINTER_IP} 1.3.6.1.2.1.1"
echo -e "msfconsole -q -x 'use auxiliary/scanner/snmp/snmp_enum; set RHOSTS ${PRINTER_IP}; run; exit'"
echo -e ""
echo -e "${YELLOW}# IPP Printer Attributes (LUKE + HAN flags)${NC}"
echo -e "ipptool -tv ipp://${PRINTER_IP}:631/ipp/print get-printer-attributes.test | grep FLAG"
echo -e ""
echo -e "${YELLOW}# IPP Print Jobs (PADME + MACE flags)${NC}"
echo -e "ipptool -tv ipp://${PRINTER_IP}:631/ipp/print get-jobs.test | grep FLAG"
echo -e ""

echo -e "${BLUE}Teaching Points:${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e ""
echo -e "  ${YELLOW}1.${NC} SNMP and IPP are different protocols with different visibility"
echo -e "  ${YELLOW}2.${NC} LEIA flag demonstrates SNMP-only information disclosure"
echo -e "  ${YELLOW}3.${NC} Students must use BOTH protocols for complete enumeration"
echo -e "  ${YELLOW}4.${NC} Print jobs require separate IPP operation (Get-Jobs)"
echo -e "  ${YELLOW}5.${NC} Comprehensive IoT assessment requires multi-protocol approach"
echo -e ""

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${BLUE}Next Steps:${NC}"
echo -e "  1. Complete manual HAN flag configuration if not done"
echo -e "  2. Test student discovery paths with provided commands"
echo -e "  3. Deploy PRET-based flags for filesystem enumeration"
echo -e "  4. Create student guide with progressive hints"
echo -e ""

exit 0
