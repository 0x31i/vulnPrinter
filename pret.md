# PRET.py Enumeration Guide for HP Printer CTF

## What PRET Can Discover (Read-Only Mode)

Even without write access, PRET has powerful enumeration capabilities that can discover some of our deployed flags.

---

## Testing Current Flags with PRET

### Can PRET See Our SNMP Flags?

The SNMP flags (LUKE and LEIA) might be visible through PJL INFO commands.

**Test with PRET:**

```bash
python2 pret.py 192.168.1.131 pjl

# Once connected:
pret> info config
pret> info variables  
pret> env
```

**Expected behavior:**
- `info config` - May show printer configuration including location/contact
- `info variables` - Shows PJL environment variables
- `env` - Lists all environment variables

**If LUKE/LEIA flags appear here, students can find them via PRET!**

---

## Adding a PRET-Specific Flag

Since PRET can't write but CAN read, we can deploy a flag via PJL INFO STATUS message.

### Method 1: Set PJL RDYMSG (Ready Message)

```bash
# Set a ready message that PRET can read
cat > /tmp/set_rdymsg.pjl << 'EOF'
%-12345X@PJL
@PJL RDYMSG DISPLAY="FLAG{YODA62847193}"
%-12345X
EOF

nc 192.168.1.131 9100 < /tmp/set_rdymsg.pjl
rm /tmp/set_rdymsg.pjl
```

**Discovery via PRET:**
```bash
python2 pret.py 192.168.1.131 pjl
pret> info status
```

The flag should appear in the ready/status message!

---

### Method 2: Set PJL Environment Variable

```bash
# Set an environment variable that PRET can enumerate
cat > /tmp/set_env.pjl << 'EOF'
%-12345X@PJL
@PJL SET CTF_SECRET="FLAG{YODA62847193}"
%-12345X
EOF

nc 192.168.1.131 9100 < /tmp/set_env.pjl
rm /tmp/set_env.pjl
```

**Discovery via PRET:**
```bash
python2 pret.py 192.168.1.131 pjl
pret> env
pret> printenv CTF_SECRET
```

---

### Method 3: Query What PRET INFO Commands Show

Let's see what information PRET's built-in enumeration reveals:

```bash
python2 pret.py 192.168.1.131 pjl

# Try all info commands
pret> info id          # Printer ID
pret> info config      # Configuration
pret> info filesys     # Filesystem info
pret> info memory      # Memory info  
pret> info status      # Status messages
pret> info ustatus     # Unsolicited status
pret> info variables   # PJL variables
pret> info pagecount   # Page count

# Environment enumeration
pret> env              # List all env vars
pret> printenv         # Print all env vars

# System info
pret> version          # Get firmware version
```

**Any of these commands might reveal our SNMP-set location/contact!**

---

## Recommended: Add YODA Flag via PJL INFO STATUS

This is the most reliable PRET-discoverable flag:

### Deployment Command

```bash
#!/bin/bash
# Deploy YODA flag for PRET discovery

PRINTER_IP="192.168.1.131"

echo "Deploying YODA flag for PRET enumeration..."

# Method 1: Try RDYMSG (Ready Message)
cat > /tmp/yoda_rdymsg.pjl << 'EOF'
%-12345X@PJL
@PJL RDYMSG DISPLAY="System Ready | FLAG{YODA62847193}"
%-12345X
EOF

nc ${PRINTER_IP} 9100 < /tmp/yoda_rdymsg.pjl
echo "✓ RDYMSG set"

# Method 2: Set environment variable as backup
cat > /tmp/yoda_env.pjl << 'EOF'
%-12345X@PJL
@PJL SET LOCATION="FLAG{YODA62847193}"
%-12345X
EOF

nc ${PRINTER_IP} 9100 < /tmp/yoda_env.pjl
echo "✓ Environment variable set"

# Verify via PJL
echo ""
echo "Verifying YODA flag deployment..."
echo -e '\033%-12345X@PJL INFO STATUS\r\n\033%-12345X' | nc ${PRINTER_IP} 9100 -w 2

rm /tmp/yoda_*.pjl

echo ""
echo "Students discover via PRET:"
echo "  python2 pret.py ${PRINTER_IP} pjl"
echo "  pret> info status"
echo "  pret> env"
```

---

## Student Discovery Workflow with PRET

### Step 1: Connect to Printer

```bash
# Clone PRET if not installed
git clone https://github.com/RUB-NDS/PRET
cd PRET

# Install dependencies
pip2 install colorama pysnmp

# Connect via PJL
python2 pret.py 192.168.1.131 pjl
```

### Step 2: Enumerate with Built-in Commands

```bash
# Once connected, try these commands:
pret> info config       # Check configuration
pret> info status       # Check status messages  
pret> info variables    # Check PJL variables
pret> env               # List environment vars
pret> printenv          # Print all env vars
```

### Step 3: Look for Flags

```bash
# Search command output for FLAG patterns
pret> info status | grep FLAG
pret> env | grep FLAG
```

---

## What Students Learn

Using PRET teaches:

1. **PJL Protocol** - Understanding printer job language
2. **Enumeration Techniques** - Using built-in PRET commands
3. **Information Disclosure** - What printers reveal without authentication
4. **Tool Proficiency** - Real pentest tool (PRET is industry standard)

---

## Complete Flag Distribution (With PRET)

| Flag | Protocol | Discovery Tool |
|------|----------|----------------|
| LUKE47239581 | SNMP + IPP | snmpwalk, ipptool, possibly PRET |
| LEIA83920174 | SNMP only | snmpwalk |
| HAN62947103 | IPP | ipptool |
| PADME91562837 | IPP jobs | ipptool (completed) |
| MACE41927365 | IPP jobs | ipptool (completed) |
| YODA62847193 | PJL | PRET.py |

This ensures students must use **4 different tools/protocols**:
- SNMP (snmpwalk)
- IPP (ipptool)
- PJL (PRET.py)
- Web Interface (for setup verification)

---

## Testing PRET Discovery Now

Before adding a new flag, let's test what PRET can already see:

```bash
python2 pret.py 192.168.1.131 pjl

# Test these commands and look for our existing flags:
pret> info config
# Look for: Server-Room-B, FLAG{LUKE47239581}

pret> info status  
# Look for any flags in status messages

pret> env
# Look for LOCATION or CONTACT variables

pret> exit
```

**If any existing flags appear, document which PRET command reveals them!**

---

## Next Steps

1. **Test PRET enumeration** on current deployment
2. **Document** which existing flags PRET can find (if any)
3. **Deploy YODA flag** if you want a guaranteed PRET-specific flag
4. **Update student guide** with PRET discovery commands
