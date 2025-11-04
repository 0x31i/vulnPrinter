Root Cause: Your deployment script is trying to use snmpset to write printer attributes, but:

Wrong protocol mapping: SNMP OIDs (sysLocation, sysContact, sysName) ≠ IPP printer attributes (printer-location, printer-contact, printer-info)
Permission issues: HP printers typically don't allow SNMP writes with the "public" community string
Unsupported operations: The printer may not allow SNMP writes for these specific OIDs

The SNMP attempts are failing because:

printer-location in IPP ≠ 1.3.6.1.2.1.1.6.0 (sysLocation) in SNMP
printer-contact in IPP ≠ 1.3.6.1.2.1.1.4.0 (sysContact) in SNMP
printer-info has no direct SNMP equivalent

Recommended Solutions
Option 1: Set Flags via IPP/CUPS (Proper Method)
Instead of SNMP, modify the printer configuration directly using the printer's web interface or CUPS configuration:
bash# If using CUPS on Linux
sudo lpadmin -p HP_Color_LaserJet_MFP_4301 \
    -L "Server-Room-B | Discovery Code: FLAG{LUKE47239581}" \
    -o printer-info="HP-MFP-CTF-FLAG{HAN62947103}" \
    -o printer-contact="SecTeam@lab.local | FLAG{LEIA83920174}"
Option 2: Use PJL Commands (Alternative)
Deploy flags using PJL filesystem access via port 9100:
bash# Set environment variables that can be retrieved via PJL
cat > deploy_flags.txt << 'EOF'
%-12345X@PJL
@PJL SET LOCATION="Server-Room-B | FLAG{LUKE47239581}"
@PJL SET CONTACT="SecTeam@lab.local | FLAG{LEIA83920174}"
%-12345X
EOF

nc 192.168.1.131 9100 < deploy_flags.txt
Option 3: Use Printer's Web Interface (EWS)
Access the HP Embedded Web Server and manually configure:

Navigate to http://192.168.1.131
Login with admin credentials
Go to Settings → Network → General
Set Location, Contact, and Device Name fields with the flag values

Option 4: Fix SNMP (If Required)
If you MUST use SNMP, you need to:

Enable SNMP write access on the printer:

Access printer web interface
Enable SNMP v1/v2 write access
Set write community string (e.g., "private")


Use correct SNMP OIDs:

bash# Set sysLocation (which MIGHT map to printer-location)
snmpset -v2c -c private 192.168.1.131 1.3.6.1.2.1.1.6.0 s "Server-Room-B | FLAG{LUKE47239581}"

# Set sysContact  
snmpset -v2c -c private 192.168.1.131 1.3.6.1.2.1.1.4.0 s "SecTeam@lab.local | FLAG{LEIA83920174}"

# Set sysName
snmpset -v2c -c private 192.168.1.131 1.3.6.1.2.1.1.5.0 s "HP-MFP-CTF-FLAG{HAN62947103}"
However, note that even if SNMP writes succeed, there's no guarantee they'll appear in IPP printer attributes since they're different protocol layers.
