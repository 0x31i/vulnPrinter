#!/bin/bash
################################################################################
# HP Printer CTF Flag Deployment - Using Original Working Methods
################################################################################

PRINTER_IP="192.168.1.131"
PRINTER_URI="ipp://${PRINTER_IP}:631/ipp/print"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     HP Printer CTF Flag Deployment                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# SNMP Flags (Working)
echo "[1/4] Deploying LUKE flag via SNMP..."
snmpset -v2c -c public ${PRINTER_IP} 1.3.6.1.2.1.1.6.0 s "Server-Room-B | FLAG{LUKE47239581}"
echo ""

echo "[2/4] Deploying LEIA flag via SNMP..."
snmpset -v2c -c public ${PRINTER_IP} 1.3.6.1.2.1.1.4.0 s "SecTeam@lab.local | FLAG{LEIA83920174}"
echo ""

# Print Job Flags (Using original ipptool EOF method)
echo "[3/4] Deploying PADME and MACE flags via print job..."

# Create document
cat > /tmp/ctf_document.txt << 'DOCEOF'
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║               CTF CHALLENGE DOCUMENT                           ║
║               TOP SECRET - AUTHORIZED PERSONNEL ONLY           ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

Document Classification: CONFIDENTIAL
Security Level: RESTRICTED
Access Control: NEED-TO-KNOW BASIS

This print job was submitted by a security audit team conducting
vulnerability assessments of network printing infrastructure.

The job metadata contains additional information that may be of
interest to penetration testers conducting IoT device enumeration.
DOCEOF

# Create IPP test file with EOF
cat > /tmp/submit-job.test << 'EOF'
{
    NAME "Submit CTF Challenge Job"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "FLAG{PADME91562837}"
    ATTR name job-name "CTF-Challenge-Job-FLAG{MACE41927365}"
    ATTR keyword job-hold-until indefinite
    
    FILE /tmp/ctf_document.txt
    
    STATUS successful-ok
}
EOF

# Submit job using ipptool
ipptool -tv ${PRINTER_URI} /tmp/submit-job.test

# Cleanup
rm /tmp/ctf_document.txt /tmp/submit-job.test

echo ""

# HAN Flag - Manual Configuration
echo "[4/4] HAN flag - Manual web configuration required:"
echo ""
echo "  1. Open web browser: https://${PRINTER_IP}"
echo "  2. Navigate to: General → About The Printer → Configure Information → Nickname"
echo "  3. Set Nickname to: HP-MFP-CTF-FLAG{HAN62947103}"
echo "  4. Click Apply"
echo ""
read -p "Press ENTER when HAN flag is configured..." 
echo ""

# Verification
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    VERIFICATION                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "SNMP Flags:"
snmpget -v2c -c public ${PRINTER_IP} 1.3.6.1.2.1.1.6.0 | grep FLAG
snmpget -v2c -c public ${PRINTER_IP} 1.3.6.1.2.1.1.4.0 | grep FLAG
echo ""

echo "IPP Print Jobs:"
cat > /tmp/check-jobs.test << 'EOF'
{
    NAME "Get All Jobs"
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

ipptool -tv ${PRINTER_URI} /tmp/check-jobs.test | grep -E "job-originating-user-name|job-name" | grep FLAG
rm /tmp/check-jobs.test
echo ""

echo "IPP Printer Attributes:"
cat > /tmp/check-attrs.test << 'EOF'
{
    NAME "Get Printer Attributes"
    OPERATION Get-Printer-Attributes
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR keyword requested-attributes all
    STATUS successful-ok
}
EOF

ipptool -tv ${PRINTER_URI} /tmp/check-attrs.test | grep -i "printer-info\|printer-name\|printer-location\|printer-contact" | grep FLAG
rm /tmp/check-attrs.test
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                  DEPLOYMENT COMPLETE                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Deployed Flags:"
echo "  ✓ FLAG{LUKE47239581}  - SNMP sysLocation + IPP printer-location"
echo "  ✓ FLAG{LEIA83920174}  - SNMP sysContact (SNMP ONLY)"
echo "  ✓ FLAG{HAN62947103}   - Web config → IPP printer-info/name"
echo "  ✓ FLAG{PADME91562837} - IPP job-originating-user-name"
echo "  ✓ FLAG{MACE41927365}  - IPP job-name"
echo ""

exit 0
