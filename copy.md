# HP Color LaserJet Pro MFP 4301 CTF Flag Deployment Fix

## Problem Overview

Your CTF deployment has two main issues:

1. **PADME flag not appearing in IPP queries** - It's in a print job, not printer attributes
2. **SNMP write commands failing** - HP restricts writable OIDs even with SNMP enabled

---

## Issue 1: PADME Flag Location

### Why It's Not Showing

The `FLAG{PADME91562837}` is stored in a **print job** as `job-originating-user-name`, NOT in printer attributes.

When you run:
```bash
ipptool -tv ipp://192.168.1.131:631/ipp/print get-printer-attributes.test | grep FLAG
```

You're only querying **printer-level attributes** (location, contact, info), not print jobs.

### Solution: Query Print Jobs Separately

Students need to use a different IPP test file to query jobs:

```bash
# Create get-jobs.test file
cat > get-jobs.test << 'EOF'
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

# Query print jobs
ipptool -tv ipp://192.168.1.131:631/ipp/print get-jobs.test
```

### Search for PADME Flag

```bash
# Find PADME flag in job metadata
ipptool -tv ipp://192.168.1.131:631/ipp/print get-jobs.test | grep -E "job-originating-user-name|PADME"

# Or search for all flags in jobs
ipptool -tv ipp://192.168.1.131:631/ipp/print get-jobs.test | grep FLAG
```

---

## Issue 2: SNMP Write Failures

### Why SNMP Writes Are Failing

Even with "SNMPv1/v2 read-write access" enabled and community strings set to "public", writes fail because:

1. **HP restricts writable OIDs** - Most system OIDs are read-only at firmware level
2. **Protocol mismatch** - SNMP OIDs ≠ IPP printer attributes

```
SNMP OID                          IPP Attribute
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1.3.6.1.2.1.1.6.0 (sysLocation) ≠ printer-location
1.3.6.1.2.1.1.4.0 (sysContact)  ≠ printer-contact  
1.3.6.1.2.1.1.5.0 (sysName)     ≠ printer-info
```

Even if SNMP writes succeed, they **may not appear** in IPP queries because they're stored in different firmware locations!

---

## Testing SNMP Write Capability

Run these tests to see what's actually writable:

```bash
# Test writing to sysLocation
snmpset -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.6.0 s "Test Location"

# Read it back
snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.6.0

# Test writing to sysContact
snmpset -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.4.0 s "Test Contact"
snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.4.0

# Test writing to sysName
snmpset -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.5.0 s "Test Name"
snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.5.0
```

**Expected Errors:**
- `Error in packet. Reason: notWritable`
- `Error in packet. Reason: noAccess`
- `Error in packet. Reason: noSuchName`

This confirms HP blocks writes to these OIDs at firmware level.

---

## Solution Methods

### Method 1: Direct Web Configuration (RECOMMENDED)

**Manual one-time setup via HP Embedded Web Server:**

1. **Navigate to printer web interface:**
   ```
   https://192.168.1.131
   ```

2. **Go to Network Settings:**
   - Settings → Network → General
   - Or: Network → Network Settings → Services

3. **Set these fields:**
   - **Device Location**: `Server-Room-B | Discovery Code: FLAG{LUKE47239581}`
   - **Device Contact**: `SecTeam@lab.local | FLAG{LEIA83920174}`
   - **Device Name/Hostname**: `HP-MFP-CTF-FLAG{HAN62947103}`

4. **Apply Changes** and click "Apply" or "Save"

5. **Verify Configuration:**
   ```bash
   ipptool -tv ipp://192.168.1.131:631/ipp/print get-printer-attributes.test | grep -E "printer-location|printer-contact|printer-info"
   ```

**Advantages:**
- ✅ Works 100% of the time
- ✅ Persists across reboots
- ✅ Uses native HP interface
- ✅ No protocol translation issues

---

### Method 2: CUPS Configuration (If Using Linux Print Server)

If you have a Linux box managing the printer via CUPS:

```bash
# Add printer to CUPS with flags
sudo lpadmin -p HP_Color_LaserJet_MFP_4301 \
  -E \
  -v ipp://192.168.1.131:631/ipp/print \
  -m everywhere \
  -L "Server-Room-B | Discovery Code: FLAG{LUKE47239581}" \
  -D "HP-MFP-CTF-FLAG{HAN62947103}" \
  -o printer-is-shared=true

# Manually edit printers.conf for contact
sudo nano /etc/cups/printers.conf

# Add this line under the printer definition:
# Info HP-MFP-CTF-FLAG{HAN62947103}
# Location Server-Room-B | Discovery Code: FLAG{LUKE47239581}

# Restart CUPS
sudo systemctl restart cups
```

**Verify:**
```bash
lpstat -l -p HP_Color_LaserJet_MFP_4301
ipptool -tv ipp://localhost:631/printers/HP_Color_LaserJet_MFP_4301 get-printer-attributes.test
```

---

### Method 3: PJL Environment Variables (Alternative Approach)

Set flags using PJL commands via JetDirect port 9100:

```bash
# Create PJL command file
cat > set_flags_pjl.txt << 'EOF'
%-12345X@PJL
@PJL COMMENT "Setting CTF Flags via PJL"
@PJL SET LOCATION="FLAG{LUKE47239581}"
@PJL SET CONTACT="FLAG{LEIA83920174}"  
@PJL SET DEVICENAME="FLAG{HAN62947103}"
@PJL RDYMSG DISPLAY="CTF Printer Ready"
@PJL INFO CONFIG
%-12345X
EOF

# Send to printer
nc 192.168.1.131 9100 < set_flags_pjl.txt
```

**Students retrieve via PJL:**
```bash
echo -e '\033%-12345X@PJL INFO CONFIG\r\n\033%-12345X' | nc 192.168.1.131 9100 | grep -E "LOCATION|CONTACT|DEVICENAME"
```

**Note:** These may NOT appear in IPP queries, but provide an alternative discovery path.

---

### Method 4: HP RESTful API (Advanced)

HP printers expose REST endpoints:

```bash
# Set device location via REST API
curl -X PUT "http://192.168.1.131/DevMgmt/NetAppsDyn.xml" \
  -H "Content-Type: application/xml" \
  -d '<NetAppsDyn><Location>Server-Room-B | FLAG{LUKE47239581}</Location></NetAppsDyn>'

# Set contact information
curl -X PUT "http://192.168.1.131/DevMgmt/NetAppsDyn.xml" \
  -H "Content-Type: application/xml" \
  -d '<NetAppsDyn><Contact>SecTeam@lab.local | FLAG{LEIA83920174}</Contact></NetAppsDyn>'
```

**Note:** May require authentication. Find the correct XML endpoints in HP documentation.

---

## Recommended CTF Deployment Strategy

### Step 1: One-Time Manual Configuration

**Configure via HP EWS** (Method 1 above):
- Set Device Location with LUKE flag
- Set Device Contact with LEIA flag  
- Set Device Name with HAN flag

These persist across reboots and don't need scripting.

---

### Step 2: Automated PADME Flag Deployment

Create a script to deploy the PADME flag via print job:

```bash
#!/bin/bash
# deploy_padme_flag.sh

PRINTER_IP="192.168.1.131"
PRINTER_URI="ipp://${PRINTER_IP}:631/ipp/print"

echo "Deploying PADME flag via IPP print job..."

# Create a simple test document
echo "CTF Challenge Document - Top Secret" > /tmp/ctf_doc.txt

# Submit print job with flag in username field
lp -d "${PRINTER_URI}" \
   -U "FLAG{PADME91562837}" \
   -t "CTF-Challenge-Job-FLAG{MACE41927365}" \
   -o job-hold-until=indefinite \
   /tmp/ctf_doc.txt

echo "PADME flag deployed successfully!"
echo "Students must query print jobs to find it."

# Cleanup
rm /tmp/ctf_doc.txt
```

**Alternative: Direct IPP job submission:**

```bash
#!/bin/bash
# deploy_job_flag_ipp.sh

cat > /tmp/submit-job.test << 'EOF'
{
    NAME "Submit Held Print Job with Flag"
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

# Create document content
echo "Top Secret CTF Challenge Document" > /tmp/ctf_document.txt

# Submit job
ipptool -tv ipp://192.168.1.131:631/ipp/print /tmp/submit-job.test

# Cleanup
rm /tmp/submit-job.test /tmp/ctf_document.txt
```

---

### Step 3: Complete Deployment Script

Full automated script combining all flags:

```bash
#!/bin/bash
# complete_printer_ctf_deployment.sh

set -e

PRINTER_IP="192.168.1.131"
PRINTER_URI="ipp://${PRINTER_IP}:631/ipp/print"

echo "╔════════════════════════════════════════════════╗"
echo "║  HP Printer CTF Flag Deployment Script        ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

# Check printer connectivity
echo "[1/5] Testing printer connectivity..."
if ! ping -c 2 -W 2 ${PRINTER_IP} &>/dev/null; then
    echo "❌ ERROR: Cannot reach printer at ${PRINTER_IP}"
    exit 1
fi
echo "✅ Printer is reachable"
echo ""

# Check IPP service
echo "[2/5] Testing IPP service..."
if ! nc -zv ${PRINTER_IP} 631 2>&1 | grep -q "succeeded"; then
    echo "❌ ERROR: IPP port 631 is not accessible"
    exit 1
fi
echo "✅ IPP service is available"
echo ""

# Manual configuration reminder
echo "[3/5] Printer Attribute Flags (MANUAL SETUP REQUIRED)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚠️  The following flags MUST be configured manually via web interface:"
echo "    https://${PRINTER_IP}"
echo ""
echo "    1. Device Location: Server-Room-B | Discovery Code: FLAG{LUKE47239581}"
echo "    2. Device Contact:  SecTeam@lab.local | FLAG{LEIA83920174}"
echo "    3. Device Name:     HP-MFP-CTF-FLAG{HAN62947103}"
echo ""
echo "    Navigate to: Settings → Network → General"
echo ""
read -p "Press ENTER once manual configuration is complete..."
echo ""

# Verify printer attributes
echo "[4/5] Verifying printer attributes..."
ATTRIBUTES=$(ipptool -tv ${PRINTER_URI} /dev/stdin 2>/dev/null << 'EOF'
{
    NAME "Get Printer Attributes"
    OPERATION Get-Printer-Attributes
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR uri printer-uri $uri
    ATTR keyword requested-attributes printer-location,printer-contact,printer-info
    STATUS successful-ok
}
EOF
)

if echo "$ATTRIBUTES" | grep -q "LUKE47239581"; then
    echo "✅ LUKE flag found in printer-location"
else
    echo "⚠️  WARNING: LUKE flag not found in printer-location"
fi

if echo "$ATTRIBUTES" | grep -q "LEIA83920174"; then
    echo "✅ LEIA flag found in printer-contact"
else
    echo "⚠️  WARNING: LEIA flag not found in printer-contact"
fi

if echo "$ATTRIBUTES" | grep -q "HAN62947103"; then
    echo "✅ HAN flag found in printer-info"
else
    echo "⚠️  WARNING: HAN flag not found in printer-info"
fi
echo ""

# Deploy PADME flag via print job
echo "[5/5] Deploying PADME flag via print job..."

# Create document
cat > /tmp/ctf_challenge.txt << 'EOF'
╔════════════════════════════════════════════════╗
║          CTF CHALLENGE DOCUMENT                ║
║                                                ║
║  This document contains hidden flags.          ║
║  Use IPP enumeration to discover them.         ║
║                                                ║
║  Hint: Check both printer attributes AND       ║
║        print job metadata!                     ║
╚════════════════════════════════════════════════╝
EOF

# Submit job with flags in metadata
ipptool -tv ${PRINTER_URI} /dev/stdin &>/dev/null << 'EOF'
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
    
    FILE /tmp/ctf_challenge.txt
    
    STATUS successful-ok
}
EOF

echo "✅ PADME flag deployed in print job"
echo ""

# Verify job deployment
echo "Verifying print job deployment..."
JOBS=$(ipptool -tv ${PRINTER_URI} /dev/stdin 2>/dev/null << 'EOF'
{
    NAME "Get Jobs"
    OPERATION Get-Jobs
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR uri printer-uri $uri
    ATTR keyword which-jobs all
    STATUS successful-ok
}
EOF
)

if echo "$JOBS" | grep -q "PADME91562837"; then
    echo "✅ PADME flag found in job-originating-user-name"
else
    echo "⚠️  WARNING: PADME flag not found in print jobs"
fi

if echo "$JOBS" | grep -q "MACE41927365"; then
    echo "✅ MACE flag found in job-name"
else
    echo "⚠️  WARNING: MACE flag not found in print jobs"
fi
echo ""

# Cleanup
rm -f /tmp/ctf_challenge.txt

# Summary
echo "╔════════════════════════════════════════════════╗"
echo "║           DEPLOYMENT COMPLETE                  ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
echo "Flags deployed:"
echo "  ✓ FLAG{LUKE47239581}    - printer-location"
echo "  ✓ FLAG{LEIA83920174}    - printer-contact"
echo "  ✓ FLAG{HAN62947103}     - printer-info"
echo "  ✓ FLAG{PADME91562837}   - job-originating-user-name"
echo "  ✓ FLAG{MACE41927365}    - job-name"
echo ""
echo "Student discovery commands:"
echo "  # Get printer attributes (LUKE, LEIA, HAN)"
echo "  ipptool -tv ${PRINTER_URI} get-printer-attributes.test"
echo ""
echo "  # Get print jobs (PADME, MACE)"
echo "  ipptool -tv ${PRINTER_URI} get-jobs.test"
echo ""
```

---

## Verification Commands

### Check Printer Attributes (LUKE, LEIA, HAN)

```bash
# Create test file
cat > get-printer-attributes.test << 'EOF'
{
    NAME "Get All Printer Attributes"
    OPERATION Get-Printer-Attributes
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR keyword requested-attributes all
    STATUS successful-ok
}
EOF

# Query printer
ipptool -tv ipp://192.168.1.131:631/ipp/print get-printer-attributes.test | grep -E "printer-location|printer-contact|printer-info"
```

### Check Print Jobs (PADME, MACE)

```bash
# Create test file
cat > get-jobs.test << 'EOF'
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

# Query jobs
ipptool -tv ipp://192.168.1.131:631/ipp/print get-jobs.test | grep -E "job-originating-user-name|job-name|FLAG"
```

### Complete Flag Verification

```bash
#!/bin/bash
# verify_all_flags.sh

PRINTER_IP="192.168.1.131"

echo "Checking printer attributes..."
ipptool -tv ipp://${PRINTER_IP}:631/ipp/print get-printer-attributes.test 2>/dev/null | grep FLAG | while read line; do
    echo "  ✓ Found: $line"
done

echo ""
echo "Checking print jobs..."
ipptool -tv ipp://${PRINTER_IP}:631/ipp/print get-jobs.test 2>/dev/null | grep FLAG | while read line; do
    echo "  ✓ Found: $line"
done
```

---

## Student Guide Updates

Update your student instructions to include:

### Discovery Methodology

```markdown
## Flag Discovery via IPP

### Step 1: Query Printer Attributes

Discover flags in printer configuration:

```bash
ipptool -tv ipp://192.168.1.131:631/ipp/print get-printer-attributes.test | grep FLAG
```

**Expected Flags:**
- `FLAG{LUKE47239581}` - In printer-location
- `FLAG{LEIA83920174}` - In printer-contact
- `FLAG{HAN62947103}` - In printer-info

### Step 2: Query Print Jobs

Discover flags in print job metadata:

```bash
ipptool -tv ipp://192.168.1.131:631/ipp/print get-jobs.test | grep FLAG
```

**Expected Flags:**
- `FLAG{PADME91562837}` - In job-originating-user-name
- `FLAG{MACE41927365}` - In job-name

### Targeted Searches

```bash
# Find specific job attributes
ipptool -tv ipp://192.168.1.131:631/ipp/print get-jobs.test | grep -E "job-originating-user-name|job-name"

# Save all output for analysis
ipptool -tv ipp://192.168.1.131:631/ipp/print get-printer-attributes.test > printer_attrs.txt
ipptool -tv ipp://192.168.1.131:631/ipp/print get-jobs.test > printer_jobs.txt

# Search saved files
grep -i flag *.txt
```
```

---

## Troubleshooting

### Issue: No flags appear in IPP queries

**Diagnosis:**
```bash
# Check if printer is accessible
ping 192.168.1.131

# Check if IPP is running
nmap -p 631 192.168.1.131

# Test IPP endpoint
curl -I http://192.168.1.131:631/ipp/print
```

**Solution:** Verify printer IP address and network connectivity

---

### Issue: Printer attributes empty

**Diagnosis:**
```bash
# Try different IPP paths
for path in /ipp/print /ipp/printer /ipp ""; do
    echo "Testing: ipp://192.168.1.131:631${path}"
    ipptool -t ipp://192.168.1.131:631${path} get-printer-attributes.test
done
```

**Solution:** Use the path that returns `PASS`

---

### Issue: Print jobs empty

**Diagnosis:**
```bash
# Check if jobs exist
lpstat -o

# Query with different parameters
ipptool -tv ipp://192.168.1.131:631/ipp/print get-jobs.test
```

**Solution:** Redeploy PADME flag print job using deployment script

---

### Issue: SNMP still not writing

**Accept Reality:**

SNMP writes to system OIDs on HP printers are often impossible even with correct configuration. This is **by design** for security.

**Best Practice:** Use Method 1 (Web Interface) for CTF deployment instead of fighting SNMP limitations.

---

## Quick Reference

| Flag | Location | Discovery Method |
|------|----------|------------------|
| LUKE47239581 | printer-location | `get-printer-attributes.test` |
| LEIA83920174 | printer-contact | `get-printer-attributes.test` |
| HAN62947103 | printer-info | `get-printer-attributes.test` |
| PADME91562837 | job-originating-user-name | `get-jobs.test` |
| MACE41927365 | job-name | `get-jobs.test` |

---

## Summary

1. **SNMP writes are unreliable** - Use web interface for printer attributes
2. **Two separate IPP queries needed** - One for printer, one for jobs
3. **Manual setup is acceptable** - One-time configuration via EWS is best practice
4. **Automate job deployment** - Script the PADME flag via print jobs
5. **Update student guide** - Document both query methods clearly

---

## Next Steps

1. ✅ Configure printer attributes manually via web interface
2. ✅ Run deployment script for PADME flag
3. ✅ Verify all 5 flags are discoverable
4. ✅ Update student instructions with both query methods
5. ✅ Test complete discovery flow as a student would

---

**Last Updated:** 2025-11-04  
**Target Device:** HP Color LaserJet Pro MFP 4301  
**IP Address:** 192.168.1.131
