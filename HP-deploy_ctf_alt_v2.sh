#!/bin/bash
################################################################################
# Simple HP Printer CTF Flag Deployment
# Uses only the commands we confirmed work
################################################################################

PRINTER_IP="192.168.1.131"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     HP Printer CTF Flag Deployment - Simple Version           ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Deploy LUKE flag via SNMP sysLocation
echo "[1/4] Deploying LUKE flag via SNMP..."
snmpset -v2c -c public ${PRINTER_IP} 1.3.6.1.2.1.1.6.0 s "Server-Room-B | FLAG{LUKE47239581}"
echo ""

# Deploy LEIA flag via SNMP sysContact  
echo "[2/4] Deploying LEIA flag via SNMP..."
snmpset -v2c -c public ${PRINTER_IP} 1.3.6.1.2.1.1.4.0 s "SecTeam@lab.local | FLAG{LEIA83920174}"
echo ""

# Deploy PADME and MACE flags via print job
echo "[3/4] Deploying PADME and MACE flags via print job..."

# Create simple document
echo "CTF Challenge Document - Top Secret" > /tmp/ctf_doc.txt

# Submit using lp command (simpler than ipptool)
echo "FLAG{PADME91562837}" | lp -d ipp://${PRINTER_IP}:631/ipp/print -U "FLAG{PADME91562837}" -t "CTF-Challenge-Job-FLAG{MACE41927365}" -o job-hold-until=indefinite -

# Clean up
rm -f /tmp/ctf_doc.txt
echo ""

# Reminder for HAN flag
echo "[4/4] Manual setup required for HAN flag:"
echo "    https://${PRINTER_IP}"
echo "    Settings → Network → General"  
echo "    Device Name: HP-MFP-CTF-FLAG{HAN62947103}"
echo ""
read -p "Press ENTER when HAN flag is configured..."
echo ""

# Verify SNMP flags
echo "Verifying SNMP flags..."
snmpget -v2c -c public ${PRINTER_IP} 1.3.6.1.2.1.1.6.0
snmpget -v2c -c public ${PRINTER_IP} 1.3.6.1.2.1.1.4.0
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    DEPLOYMENT COMPLETE                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Student Discovery Commands:"
echo ""
echo "# SNMP (LUKE + LEIA)"
echo "snmpwalk -v2c -c public ${PRINTER_IP} 1.3.6.1.2.1.1"
echo ""
echo "# IPP printer attributes (LUKE + HAN)"  
echo "ipptool -tv ipp://${PRINTER_IP}:631/ipp/print get-printer-attributes.test | grep FLAG"
echo ""
echo "# IPP print jobs (PADME + MACE)"
echo "ipptool -tv ipp://${PRINTER_IP}:631/ipp/print get-jobs.test | grep FLAG"
echo ""

exit 0
