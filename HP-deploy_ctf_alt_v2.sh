#!/bin/bash
################################################################################
# HP Printer CTF Flag Deployment - Final Version
# Jobs are found in "completed" history, not active queue
################################################################################

PRINTER_IP="192.168.1.131"
PRINTER_URI="ipp://${PRINTER_IP}:631/ipp/print"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     HP Printer CTF Flag Deployment                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

################################################################################
# SNMP FLAGS
################################################################################

echo "[1/3] Deploying SNMP flags..."
echo ""

# LUKE flag - visible in both SNMP and IPP
echo "  → Deploying FLAG{LUKE47239581} via SNMP sysLocation..."
snmpset -v2c -c public ${PRINTER_IP} 1.3.6.1.2.1.1.6.0 s "Server-Room-B | FLAG{LUKE47239581}"

# LEIA flag - visible ONLY in SNMP (not IPP)
echo "  → Deploying FLAG{LEIA83920174} via SNMP sysContact..."
snmpset -v2c -c public ${PRINTER_IP} 1.3.6.1.2.1.1.4.0 s "SecTeam@lab.local | FLAG{LEIA83920174}"

echo ""

################################################################################
# PRINT JOB FLAGS
################################################################################

echo "[2/3] Deploying print job flags..."
echo ""

# Create document
cat > /tmp/ctf_document.txt << 'DOCEOF'
╔════════════════════════════════════════════════════════════════╗
║               CTF CHALLENGE DOCUMENT                           ║
║               TOP SECRET - AUTHORIZED PERSONNEL ONLY           ║
╚════════════════════════════════════════════════════════════════╝

Document Classification: CONFIDENTIAL
Security Level: RESTRICTED

This print job was submitted by a security audit team.
Job metadata contains flags for penetration testing assessment.
DOCEOF

# Create IPP test file for job submission
cat > /tmp/submit-job.test << 'EOF'
{
    NAME "Submit CTF Job"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "FLAG{PADME91562837}"
    ATTR name job-name "CTF-Challenge-Job-FLAG{MACE41927365}"
    
    FILE /tmp/ctf_document.txt
    
    STATUS successful-ok
}
EOF

# Submit job
echo "  → Submitting job with PADME and MACE flags..."
ipptool -tv ${PRINTER_URI} /tmp/submit-job.test | grep -E "successful|job-id"

# Wait for job to process
echo "  → Waiting for job to complete..."
sleep 3

# Cleanup
rm /tmp/ctf_document.txt /tmp/submit-job.test

echo ""

################################################################################
# MANUAL CONFIGURATION
################################################################################

echo "[3/3] Manual web configuration required for HAN flag:"
echo ""
echo "  URL: https://${PRINTER_IP}"
echo "  Path: General → About The Printer → Configure Information → Nickname"
echo "  Value: HP-MFP-CTF-FLAG{HAN62947103}"
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
echo "[SNMP] Checking sysLocation and sysContact..."
snmpget -v2c -c public ${PRINTER_IP} 1.3.6.1.2.1.1.6.0 2>/dev/null | grep -o "FLAG{[^}]*}"
snmpget -v2c -c public ${PRINTER_IP} 1.3.6.1.2.1.1.4.0 2>/dev/null | grep -o "FLAG{[^}]*}"
echo ""

# Verify print jobs in COMPLETED/HISTORY
echo "[IPP] Checking completed jobs (history)..."

# Create test file to query completed jobs
cat > /tmp/get-completed-jobs.test << 'EOF'
{
    NAME "Get Completed Jobs"
    OPERATION Get-Jobs
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR keyword which-jobs completed
    ATTR keyword requested-attributes job-id,job-name,job-originating-user-name,job-state
    STATUS successful-ok
}
EOF

ipptool -tv ${PRINTER_URI} /tmp/get-completed-jobs.test 2>/dev/null | grep -E "job-originating-user-name|job-name" | grep FLAG

rm /tmp/get-completed-jobs.test
echo ""

# Verify IPP printer attributes
echo "[IPP] Checking printer attributes..."

cat > /tmp/get-printer-attributes.test << 'EOF'
{
    NAME "Get Printer Attributes"
    OPERATION Get-Printer-Attributes
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR keyword requested-attributes printer-location,printer-contact,printer-info,printer-name
    STATUS successful-ok
}
EOF

ipptool -tv ${PRINTER_URI} /tmp/get-printer-attributes.test 2>/dev/null | grep FLAG

rm /tmp/get-printer-attributes.test
echo ""

################################################################################
# DEPLOYMENT SUMMARY
################################################################################

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                  DEPLOYMENT COMPLETE                           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Deployed Flags:"
echo "  ✓ FLAG{LUKE47239581}  - SNMP sysLocation (visible in IPP too)"
echo "  ✓ FLAG{LEIA83920174}  - SNMP sysContact (SNMP ONLY)"
echo "  ✓ FLAG{HAN62947103}   - Web Interface → IPP printer-info"
echo "  ✓ FLAG{PADME91562837} - Print job history (completed jobs)"
echo "  ✓ FLAG{MACE41927365}  - Print job history (completed jobs)"
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
echo "# IPP Completed Jobs (finds PADME + MACE) - USE THIS ONE!"
echo "ipptool -tv ipp://${PRINTER_IP}:631/ipp/print get-completed-jobs.test | grep FLAG"
echo ""
echo "Teaching Point:"
echo "  Students must query 'completed' jobs, not 'all' or 'not-completed'"
echo "  This teaches thorough enumeration of job history"
echo ""

exit 0
