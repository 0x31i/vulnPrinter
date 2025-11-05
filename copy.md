# 1. Set flags via SNMP (you already did sysLocation and sysContact)
snmpset -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.6.0 s "Server-Room-B | FLAG{LUKE47239581}"
snmpset -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.4.0 s "SecTeam@lab.local | FLAG{LEIA83920174}"

# 2. Verify via SNMP (read back)
snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.6.0
snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.4.0

# 3. Check if they appear in IPP attributes
ipptool -tv ipp://192.168.1.131:631/ipp/print get-printer-attributes.test | grep -A 1 "printer-location"
ipptool -tv ipp://192.168.1.131:631/ipp/print get-printer-attributes.test | grep -A 1 "printer-contact"

# 4. Alternative: check all printer attributes
ipptool -tv ipp://192.168.1.131:631/ipp/print get-printer-attributes.test > /tmp/printer_attrs.txt
cat /tmp/printer_attrs.txt | grep -E "location|contact|LUKE|LEIA"
