# Complete ipptool Guide - Discovering Printer Flags from Kali Linux
## Step-by-Step Tutorial with Detailed Explanations

## 🎯 Learning Objectives

By the end of this guide, you will understand:
- What IPP (Internet Printing Protocol) is and how it works
- How to install and configure ipptool on Kali Linux
- How to create IPP test files from scratch
- How to query printer attributes and discover information
- How to analyze IPP responses to find sensitive data
- How to troubleshoot common IPP issues

---

## Part 1: Understanding the Basics

### What is IPP?

**IPP (Internet Printing Protocol)** is a network protocol for communication between client computers and printers (or print servers). Think of it as a standardized way for your computer to talk to printers over the network.

**Key Concepts:**
- **Protocol:** A set of rules for communication (like HTTP for websites)
- **Port 631:** IPP's standard port (like port 80 for HTTP, 443 for HTTPS)
- **Request/Response:** You send a request, printer sends back a response
- **Attributes:** Properties of the printer (name, location, status, capabilities)

**Why IPP Matters for Security:**
- Printers expose configuration details via IPP
- Job history and metadata accessible
- Often no authentication required
- Same information as SNMP but different protocol
- Can be enabled even when other services are disabled

---

### What is ipptool?

**ipptool** is a command-line utility for testing IPP printers and servers. It's part of the CUPS (Common UNIX Printing System) package.

**Think of it as:**
- A browser for printers (instead of web pages)
- A way to "ask questions" to the printer
- A testing tool for IPP compliance
- An enumeration tool for pentesters

**What ipptool does:**
1. Connects to printer on port 631
2. Sends formatted IPP requests
3. Receives and parses IPP responses
4. Displays results in human-readable format

---

## Part 2: Setting Up Your Kali Environment

### Step 1: Check if ipptool is Installed

Open a terminal and type:

```bash
which ipptool
```

**Expected Output:**
```
/usr/bin/ipptool
```

**If you see output:** ipptool is installed, skip to Step 3.

**If you see nothing:** ipptool is not installed, continue to Step 2.

---

### Step 2: Install ipptool

```bash
# Update package lists
sudo apt update

# Install CUPS IPP utilities
sudo apt install cups-ipp-utils -y

# Also install CUPS client tools (optional but useful)
sudo apt install cups-client -y
```

**What each package does:**
- **cups-ipp-utils:** Contains ipptool and other IPP testing utilities
- **cups-client:** Contains lp, lpstat, cancel commands for printing

**Verify installation:**
```bash
ipptool --version
```

**Expected Output:**
```
ipptool/2.4.2 (CUPS v2.4.2)
```

---

### Step 3: Understand Your Network Setup

Before connecting to the printer, verify network connectivity.

#### Check Your IP Address
```bash
ip addr show
```

**Look for your IP on the same subnet as the printer.**

**Example output:**
```
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
    inet 192.168.1.100/24 brd 192.168.1.255 scope global eth0
```

**Your IP:** 192.168.1.100  
**Subnet:** 192.168.1.0/24  
**Printer IP (example):** 192.168.1.131

---

#### Test Network Connectivity to Printer

```bash
# Set your printer's IP
PRINTER_IP="192.168.1.131"

# Test basic connectivity
ping -c 4 $PRINTER_IP
```

**Expected Output:**
```
PING 192.168.1.131 (192.168.1.131) 56(84) bytes of data.
64 bytes from 192.168.1.131: icmp_seq=1 ttl=64 time=0.287 ms
64 bytes from 192.168.1.131: icmp_seq=2 ttl=64 time=0.245 ms
64 bytes from 192.168.1.131: icmp_seq=3 ttl=64 time=0.298 ms
64 bytes from 192.168.1.131: icmp_seq=4 ttl=64 time=0.312 ms

--- 192.168.1.131 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss
```

**What this means:**
- ✅ Printer is reachable on the network
- ✅ Network path exists between your Kali box and printer
- ✅ No firewall blocking ICMP
- Response time ~0.3ms indicates local network (good)

**If ping fails:**
```
From 192.168.1.100 icmp_seq=1 Destination Host Unreachable
```
**Troubleshoot:**
1. Verify printer IP is correct
2. Check if printer is powered on
3. Verify you're on the same network/VLAN
4. Check firewall rules

---

#### Test IPP Port Availability

```bash
# Check if port 631 is open
nc -zv $PRINTER_IP 631
```

**Expected Output:**
```
Connection to 192.168.1.131 631 port [tcp/ipp] succeeded!
```

**What this means:**
- ✅ IPP service is running on the printer
- ✅ Port 631 is open and accepting connections
- ✅ No firewall blocking port 631

**Alternative if nc fails:**
```bash
# Use nmap to check
nmap -p 631 $PRINTER_IP
```

**Expected Output:**
```
PORT    STATE SERVICE
631/tcp open  ipp
```

**If port is closed:**
```
PORT    STATE  SERVICE
631/tcp closed ipp
```

**What to do:**
1. IPP may be disabled on the printer
2. Enable it via web interface: `https://$PRINTER_IP`
3. Navigate to Network → Services → Enable IPP

---

## Part 3: Understanding IPP Structure

### IPP URL Format

Before making requests, understand the URL structure:

```
ipp://192.168.1.131:631/ipp/print
│   │              │   │
│   │              │   └─── Path (endpoint)
│   │              └─────── Port (standard IPP port)
│   └────────────────────── Printer IP address
└────────────────────────── Protocol (IPP)
```

**Common IPP Paths:**
- `/ipp/print` - Most common (HP, Canon, Epson)
- `/ipp/printer` - Some manufacturers
- `/ipp` - Minimal path
- `/printers` - Alternative
- `/` - Root (rarely used)

**How to find the right path:** We'll test them all later.

---

### IPP Request Structure

IPP requests are structured documents containing:

1. **Operation** - What you want to do (Get-Printer-Attributes, Get-Jobs, Print-Job)
2. **Attributes** - Parameters for the operation
3. **Groups** - Organization of attributes

**Think of it like filling out a form:**
- **Operation:** What form are you filling out? (Get information, Submit job, etc.)
- **Attributes:** Fields on the form (printer URI, what info you want, who's asking)
- **Groups:** Sections of the form (operation details, job details, etc.)

---

## Part 4: Creating Your First IPP Test File

### Understanding Test File Syntax

IPP test files use a simple JSON-like syntax. Let's build one step by step.

#### Basic Structure
```
{
    NAME "Test Name"
    OPERATION Operation-Name
    GROUP group-type
    ATTR attribute-type attribute-name attribute-value
    STATUS expected-status
}
```

**Let's break this down:**

**`NAME "Test Name"`**
- Human-readable description
- Shows in output when test runs
- Optional but helpful for debugging

**`OPERATION Operation-Name`**
- The IPP operation to perform
- Examples: Get-Printer-Attributes, Get-Jobs, Print-Job
- Must match IPP specification

**`GROUP group-type`**
- Organizes attributes into categories
- Common types:
  - `operation-attributes-tag` - Operation parameters
  - `job-attributes-tag` - Job-specific parameters
  - `printer-attributes-tag` - Printer-specific parameters

**`ATTR attribute-type attribute-name attribute-value`**
- Defines one attribute
- **attribute-type:** Data type (charset, language, uri, integer, keyword)
- **attribute-name:** The attribute's name
- **attribute-value:** The value to send (or $variable)

**`STATUS expected-status`**
- What response code you expect
- `successful-ok` means request succeeded
- If actual status doesn't match, test fails

---

### Creating Get-Printer-Attributes Test File

This is the most important test - it retrieves printer information.

#### Step 1: Create the File

```bash
# Create a directory for test files
mkdir -p ~/ipp-tests
cd ~/ipp-tests

# Create the test file
nano get-printer-attributes.test
```

#### Step 2: Add the Content

Copy this EXACTLY:

```
{
    NAME "Get All Printer Attributes"
    OPERATION Get-Printer-Attributes
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "kali-user"
    ATTR keyword requested-attributes all
    
    STATUS successful-ok
}
```

**Save and exit:** Ctrl+O, Enter, Ctrl+X

---

#### Step 3: Understanding Each Line

Let's analyze what we just created:

**Line 1-2: Test Metadata**
```
NAME "Get All Printer Attributes"
OPERATION Get-Printer-Attributes
```
- **NAME:** Identifies this test as "Get All Printer Attributes"
- **OPERATION:** Uses the IPP operation "Get-Printer-Attributes"
  - This operation asks the printer for its configuration/status

**Line 3: Group Declaration**
```
GROUP operation-attributes-tag
```
- **GROUP:** Starts a new attribute group
- **operation-attributes-tag:** This group contains operation parameters
  - Think of it as the "header" section of the request

**Line 4: Character Encoding**
```
ATTR charset attributes-charset utf-8
```
- **ATTR:** Declares an attribute
- **charset:** This is a charset attribute (character encoding type)
- **attributes-charset:** The attribute name (how to interpret characters)
- **utf-8:** The value (use UTF-8 encoding)
- **Why needed:** Tells printer how to read the text in this request

**Line 5: Language**
```
ATTR language attributes-natural-language en
```
- **language:** This is a language attribute
- **attributes-natural-language:** The attribute name
- **en:** English (ISO 639-1 code)
- **Why needed:** Tells printer what language you prefer for responses

**Line 6: Printer URI**
```
ATTR uri printer-uri $uri
```
- **uri:** This is a URI attribute (web address type)
- **printer-uri:** The attribute name (which printer)
- **$uri:** A VARIABLE that will be filled in by ipptool
  - When you run: `ipptool ipp://192.168.1.131:631/ipp/print test.file`
  - $uri becomes: `ipp://192.168.1.131:631/ipp/print`
- **Why needed:** Identifies which printer you're talking to

**Line 7: Requesting User**
```
ATTR name requesting-user-name "kali-user"
```
- **name:** This is a name attribute (text string)
- **requesting-user-name:** Who is making this request
- **"kali-user":** Identifies you as "kali-user"
- **Why needed:** Some printers log who made requests; useful for tracking

**Line 8: What Attributes to Return**
```
ATTR keyword requested-attributes all
```
- **keyword:** This is a keyword attribute (predefined value)
- **requested-attributes:** What information do you want back
- **all:** Give me EVERYTHING
  - Alternative: You could list specific attributes like `printer-location,printer-contact`
- **Why needed:** Without this, printer might only send basic info

**Line 9-10: Expected Response**
```
STATUS successful-ok
```
- **STATUS:** What response code should the printer return
- **successful-ok:** IPP status code meaning "request succeeded"
- **Why needed:** ipptool will report if the response doesn't match

---

## Part 5: Running Your First IPP Query

### Step 1: Set Your Printer IP

```bash
# Set as environment variable for easy reuse
export PRINTER_IP="192.168.1.131"
```

**Why export:** You can now use `$PRINTER_IP` in all subsequent commands.

---

### Step 2: Run ipptool

```bash
# Basic run (minimal output)
ipptool ipp://$PRINTER_IP:631/ipp/print get-printer-attributes.test
```

**What happens:**
1. ipptool reads the test file
2. Connects to printer on port 631
3. Sends the Get-Printer-Attributes request
4. Receives the response
5. Parses the response
6. Displays results

**Expected Output:**
```
Get All Printer Attributes                                              [PASS]
    Received 2847 bytes in response
    status-code = successful-ok (successful-ok)
```

**What this means:**
- ✅ Test passed (printer responded correctly)
- ✅ Received 2847 bytes of data (the printer's attributes)
- ✅ Status code was successful-ok

---

### Step 3: Run with Verbose Output

**Basic output doesn't show the actual data.** Use verbose mode:

```bash
# Run with verbose flag
ipptool -v ipp://$PRINTER_IP:631/ipp/print get-printer-attributes.test
```

**New flags:**
- `-v` : Verbose mode (shows all attribute values)

**Expected Output (Partial - will be very long):**
```
Get All Printer Attributes                                              [PASS]
    Received 2847 bytes in response
    status-code = successful-ok (successful-ok)
    attributes-charset (charset) = utf-8
    attributes-natural-language (naturalLanguage) = en
    printer-uri-supported (uri) = ipp://192.168.1.131:631/ipp/print
    uri-authentication-supported (keyword) = none
    uri-security-supported (keyword) = none
    printer-name (nameWithoutLanguage) = HP_Color_LaserJet_MFP_4301
    printer-location (nameWithoutLanguage) = Server-Room-B | Discovery Code: FLAG{LUKE47239581}
    printer-info (nameWithoutLanguage) = HP-MFP-CTF-FLAG{HAN62947103}
    printer-more-info (uri) = http://192.168.1.131
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
    document-format-supported (mimeMediaType) = application/pdf,text/plain,image/jpeg
    printer-is-accepting-jobs (boolean) = true
    queued-job-count (integer) = 0
    printer-message-from-operator (textWithoutLanguage) = 
    color-supported (boolean) = true
    pages-per-minute (integer) = 35
    pages-per-minute-color (integer) = 35
    printer-contact (nameWithoutLanguage) = SecTeam@lab.local | FLAG{LEIA83920174}
    ... [continues for many more lines]
```

---

### Step 4: Understanding the Verbose Output

**Each line follows this pattern:**
```
attribute-name (attribute-type) = value
```

**Let's analyze key lines:**

**Printer Location:**
```
printer-location (nameWithoutLanguage) = Server-Room-B | Discovery Code: FLAG{LUKE47239581}
```
- **Attribute Name:** printer-location
- **Type:** nameWithoutLanguage (text string without language tag)
- **Value:** `Server-Room-B | Discovery Code: FLAG{LUKE47239581}`

**What you found:**
- 🚨 **Physical location:** Server-Room-B
- 🚨 **Access code:** FLAG{LUKE47239581}
- **Security Issue:** Physical location exposed to anyone who can query IPP

---

**Printer Info (Name):**
```
printer-info (nameWithoutLanguage) = HP-MFP-CTF-FLAG{HAN62947103}
```
- **Attribute Name:** printer-info
- **Type:** nameWithoutLanguage
- **Value:** `HP-MFP-CTF-FLAG{HAN62947103}`

**What you found:**
- 🚨 **Hostname/Name:** Contains FLAG{HAN62947103}
- **Security Issue:** Non-standard hostname format leaking information

---

**Printer Contact:**
```
printer-contact (nameWithoutLanguage) = SecTeam@lab.local | FLAG{LEIA83920174}
```
- **Attribute Name:** printer-contact
- **Type:** nameWithoutLanguage
- **Value:** `SecTeam@lab.local | FLAG{LEIA83920174}`

**What you found:**
- 🚨 **Contact Email:** SecTeam@lab.local
- 🚨 **Access code:** FLAG{LEIA83920174}
- **Security Issue:** Internal email addresses and codes exposed

---

### Step 5: Run with Test Mode

Add test mode to see the test name and result more clearly:

```bash
# Run with test mode and verbose
ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-printer-attributes.test
```

**New flags:**
- `-t` : Test mode (shows test name and pass/fail)
- `-v` : Verbose (shows all values)

**Output (Combined):**
```
Get All Printer Attributes:
    PASS
    Received 2847 bytes in response
    status-code = successful-ok (successful-ok)
    
    printer-location (nameWithoutLanguage) = Server-Room-B | Discovery Code: FLAG{LUKE47239581}
    printer-info (nameWithoutLanguage) = HP-MFP-CTF-FLAG{HAN62947103}
    printer-contact (nameWithoutLanguage) = SecTeam@lab.local | FLAG{LEIA83920174}
    ... [more attributes]
```

---

### Step 6: Saving Output for Analysis

```bash
# Save output to a file for detailed analysis
ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-printer-attributes.test > printer_attributes.txt

# View the saved output
less printer_attributes.txt

# Search for specific terms
grep -i "location\|contact\|info" printer_attributes.txt
```

**This creates a text file you can:**
- Search through easily
- Share with team
- Include in reports
- Archive for later reference

---

## Part 6: Finding Specific Information

### Method 1: Filter Output with grep

Instead of reading thousands of lines, filter for what matters:

```bash
# Find location, contact, and info fields
ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-printer-attributes.test | grep -E "printer-location|printer-contact|printer-info|printer-name"
```

**Output:**
```
printer-name (nameWithoutLanguage) = HP_Color_LaserJet_MFP_4301
printer-location (nameWithoutLanguage) = Server-Room-B | Discovery Code: FLAG{LUKE47239581}
printer-info (nameWithoutLanguage) = HP-MFP-CTF-FLAG{HAN62947103}
printer-contact (nameWithoutLanguage) = SecTeam@lab.local | FLAG{LEIA83920174}
```

**Much cleaner!**

---

### Method 2: Request Specific Attributes Only

Create a targeted test file that only requests specific attributes.

#### Create Specific Attributes Test

```bash
nano get-specific-attributes.test
```

**Content:**
```
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
```

**Key difference:** Line 6
```
ATTR keyword requested-attributes printer-location,printer-contact,printer-info,printer-name,printer-make-and-model
```
- Instead of `all`, we list specific attributes we want
- Comma-separated list
- No spaces after commas

**Run it:**
```bash
ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-specific-attributes.test
```

**Output (Much Shorter):**
```
Get Specific Printer Attributes:
    PASS
    Received 342 bytes in response
    status-code = successful-ok (successful-ok)
    
    printer-name (nameWithoutLanguage) = HP_Color_LaserJet_MFP_4301
    printer-location (nameWithoutLanguage) = Server-Room-B | Discovery Code: FLAG{LUKE47239581}
    printer-info (nameWithoutLanguage) = HP-MFP-CTF-FLAG{HAN62947103}
    printer-contact (nameWithoutLanguage) = SecTeam@lab.local | FLAG{LEIA83920174}
    printer-make-and-model (textWithoutLanguage) = HP Color LaserJet Pro MFP 4301fdw
```

**Benefits:**
- ✅ Faster (less data transferred)
- ✅ Cleaner output
- ✅ Easier to read
- ✅ More stealthy (less network traffic)

---

## Part 7: Discovering Print Jobs (FLAG 12)

Now let's query print jobs to find job-related flags.

### Understanding Get-Jobs Operation

**Get-Jobs** is an IPP operation that retrieves information about print jobs:
- Active jobs (printing now)
- Pending jobs (waiting)
- Completed jobs (recently finished)
- Held jobs (paused)

### Step 1: Create Get-Jobs Test File

```bash
nano get-jobs.test
```

**Content:**
```
{
    NAME "Get All Print Jobs"
    OPERATION Get-Jobs
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "kali-user"
    ATTR keyword which-jobs all
    ATTR keyword requested-attributes all
    
    STATUS successful-ok
}
```

**Key line to understand:**
```
ATTR keyword which-jobs all
```
- **which-jobs:** Which jobs to return
- **all:** Return all jobs (completed, active, pending)
- **Alternatives:**
  - `completed` - Only finished jobs
  - `not-completed` - Only active/pending jobs
  - `pending` - Only waiting jobs

---

### Step 2: Run Get-Jobs Query

```bash
ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test
```

**Expected Output:**
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
    job-printer-uri (uri) = ipp://192.168.1.131:631/ipp/print
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
    
    job-id (integer) = 1237
    job-uri (uri) = ipp://192.168.1.131:631/ipp/print/1237
    job-name (nameWithoutLanguage) = CTF-Challenge-Job-FLAG{MACE41927365}
    job-originating-user-name (nameWithoutLanguage) = security-audit
    job-state (enum) = held
    job-state-reasons (keyword) = job-hold-until-specified
```

---

### Step 3: Understanding Job Information

**Each job contains multiple attributes:**

**Job 1234 - Confidential Report:**
```
job-id (integer) = 1234
job-name (nameWithoutLanguage) = Confidential-Security-Report
job-originating-user-name (nameWithoutLanguage) = admin
job-state (enum) = completed
```
- **job-id:** Unique identifier (1234)
- **job-name:** Document name
- **job-originating-user-name:** Who submitted it (admin)
- **job-state:** Current state (completed = finished printing)

**Job 1236 - Username Contains Flag:**
```
job-id (integer) = 1236
job-name (nameWithoutLanguage) = Network-Config-Backup
job-originating-user-name (nameWithoutLanguage) = FLAG{PADME91562837}
```
- 🚨 **Username field** contains: FLAG{PADME91562837}
- **Security Issue:** Sensitive data in user metadata

**Job 1237 - Job Name Contains Flag:**
```
job-id (integer) = 1237
job-name (nameWithoutLanguage) = CTF-Challenge-Job-FLAG{MACE41927365}
job-state (enum) = held
```
- 🚨 **Job name itself** contains: FLAG{MACE41927365}
- **State: held** means job is paused (still in queue)
- **Security Issue:** Job names visible to anyone

---

### Step 4: Filter for Interesting Jobs

```bash
# Find job names
ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test | grep "job-name"

# Find usernames
ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test | grep "job-originating-user-name"

# Find both
ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test | grep -E "job-name|job-originating-user"
```

---

### Step 5: Get Details of Specific Job

If you want more details about a specific job:

```bash
nano get-job-attributes.test
```

**Content:**
```
{
    NAME "Get Specific Job Attributes"
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

**Key line:**
```
ATTR integer job-id 1237
```
- **integer:** This is an integer attribute
- **job-id:** The attribute name (which job)
- **1237:** The specific job ID we want details for

**Run it:**
```bash
ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-job-attributes.test
```

**Output:**
```
Get Specific Job Attributes:
    PASS
    
    job-id (integer) = 1237
    job-uri (uri) = ipp://192.168.1.131:631/ipp/print/1237
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
```

**More metadata revealed:**
- Document format: text/plain
- Document name: challenge_document.txt
- Page count: 1
- When created: (timestamp)

---

## Part 8: Finding the Right IPP Endpoint

Sometimes `/ipp/print` doesn't work. Let's test all common paths.

### Method 1: Manual Testing

```bash
# Test common paths
for path in /ipp/print /ipp/printer /ipp /printers ""; do
    echo "Testing: ipp://$PRINTER_IP:631$path"
    if ipptool -t ipp://$PRINTER_IP:631$path get-printer-attributes.test 2>&1 | grep -q "PASS"; then
        echo "✓ SUCCESS: Use ipp://$PRINTER_IP:631$path"
        break
    else
        echo "✗ Failed"
    fi
    echo ""
done
```

**What this does:**
- Tests 5 common IPP paths
- Tries to run Get-Printer-Attributes on each
- Reports which one works
- Stops when it finds a working path

**Output:**
```
Testing: ipp://192.168.1.131:631/ipp/print
✓ SUCCESS: Use ipp://192.168.1.131:631/ipp/print

Testing: ipp://192.168.1.131:631/ipp/printer
✗ Failed
...
```

---

### Method 2: Using HTTP to Find Endpoint

```bash
# Check what the web server says
curl -k https://$PRINTER_IP | grep -i "ipp://"

# Check specific config page
curl -k https://$PRINTER_IP/DevMgmt/ProductConfigDyn.xml | grep -i "ipp"
```

**This may reveal the official IPP URI in the printer's config.**

---

### Method 3: Using mDNS/Bonjour Discovery

```bash
# Install avahi-utils if not present
sudo apt install avahi-utils

# Discover printers on network
avahi-browse -rt _ipp._tcp

# Look for your printer's IP in output
```

**Output will show:**
```
=  eth0 IPv4 HP Color LaserJet MFP 4301          Internet Printer     local
   hostname = [HP-MFP-4301.local]
   address = [192.168.1.131]
   port = [631]
   txt = ["rp=ipp/print" "ty=HP Color LaserJet" ...]
```

**Look for `rp=ipp/print`** - that's your path!

---

## Part 9: Advanced Queries and Filtering

### Query Only Active Jobs

```bash
nano get-active-jobs.test
```

**Content:**
```
{
    NAME "Get Active Jobs Only"
    OPERATION Get-Jobs
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR keyword which-jobs not-completed
    ATTR keyword requested-attributes job-id,job-name,job-state
    
    STATUS successful-ok
}
```

**Changes:**
- `which-jobs not-completed` - Only active/pending jobs
- `requested-attributes` - Only 3 fields (minimal)

---

### Query Recent Jobs (Limited)

```bash
nano get-recent-jobs.test
```

**Content:**
```
{
    NAME "Get Recent Jobs"
    OPERATION Get-Jobs
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR keyword which-jobs completed
    ATTR integer limit 10
    ATTR keyword requested-attributes job-id,job-name,job-originating-user-name,time-at-creation
    
    STATUS successful-ok
}
```

**New attribute:**
```
ATTR integer limit 10
```
- **integer:** This is an integer type
- **limit:** Attribute name (max results)
- **10:** Return at most 10 jobs

**Use case:** Printers with many jobs, you only want recent ones.

---

### Check Job Status

```bash
nano check-job-status.test
```

**Content:**
```
{
    NAME "Check Job Status"
    OPERATION Get-Job-Attributes
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR integer job-id 1237
    ATTR keyword requested-attributes job-state,job-state-reasons
    
    STATUS successful-ok
}
```

**Run it:**
```bash
ipptool -tv ipp://$PRINTER_IP:631/ipp/print check-job-status.test
```

**Output:**
```
Check Job Status:
    PASS
    
    job-state (enum) = held
    job-state-reasons (keyword) = job-hold-until-specified
```

**Job States:**
- `pending` - Waiting to print
- `processing` - Currently printing
- `held` - Paused
- `completed` - Finished
- `canceled` - Canceled
- `aborted` - Failed

---

## Part 10: Comprehensive Discovery Script

Let's create a complete script that discovers everything.

```bash
nano discover_printer_ipp.sh
```

**Content:**
```bash
#!/bin/bash
# Comprehensive IPP Printer Discovery Script
# Usage: ./discover_printer_ipp.sh <PRINTER_IP>

PRINTER_IP="${1:-192.168.1.131}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  IPP Printer Discovery Tool${NC}"
echo -e "${BLUE}  Target: $PRINTER_IP${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo ""

# Check if ipptool exists
if ! command -v ipptool &>/dev/null; then
    echo -e "${RED}[ERROR]${NC} ipptool not found. Install with:"
    echo "  sudo apt install cups-ipp-utils"
    exit 1
fi

# Test connectivity
echo -e "${YELLOW}[1/5]${NC} Testing connectivity..."
if ! ping -c 2 -W 2 $PRINTER_IP &>/dev/null; then
    echo -e "${RED}[FAIL]${NC} Cannot reach $PRINTER_IP"
    exit 1
fi
echo -e "${GREEN}[OK]${NC} Printer is reachable"
echo ""

# Test IPP port
echo -e "${YELLOW}[2/5]${NC} Testing IPP port 631..."
if ! nc -zv $PRINTER_IP 631 2>&1 | grep -q "succeeded"; then
    echo -e "${RED}[FAIL]${NC} Port 631 is closed"
    exit 1
fi
echo -e "${GREEN}[OK]${NC} IPP port is open"
echo ""

# Find working endpoint
echo -e "${YELLOW}[3/5]${NC} Finding IPP endpoint..."
IPP_PATH=""
for path in /ipp/print /ipp/printer /ipp ""; do
    # Create temporary test file
    cat > /tmp/test_ipp_$$.test << 'EOF'
{
    NAME "Test"
    OPERATION Get-Printer-Attributes
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR keyword requested-attributes printer-name
    STATUS successful-ok
}
EOF
    
    if ipptool -t ipp://$PRINTER_IP:631$path /tmp/test_ipp_$$.test 2>&1 | grep -q "PASS"; then
        IPP_PATH=$path
        echo -e "${GREEN}[OK]${NC} Found working endpoint: ipp://$PRINTER_IP:631$path"
        rm /tmp/test_ipp_$$.test
        break
    fi
    rm /tmp/test_ipp_$$.test
done

if [ -z "$IPP_PATH" ]; then
    echo -e "${RED}[FAIL]${NC} No working IPP endpoint found"
    exit 1
fi

IPP_URI="ipp://$PRINTER_IP:631$IPP_PATH"
echo ""

# Get printer attributes
echo -e "${YELLOW}[4/5]${NC} Querying printer attributes..."

cat > /tmp/get_printer_$$.test << 'EOF'
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

ATTRS=$(ipptool -tv $IPP_URI /tmp/get_printer_$$.test 2>&1)
rm /tmp/get_printer_$$.test

echo -e "${GREEN}[OK]${NC} Attributes retrieved"
echo ""

# Display important attributes
echo -e "${BLUE}═══ Printer Information ═══${NC}"
echo "$ATTRS" | grep "printer-name" | head -1
echo "$ATTRS" | grep "printer-make-and-model" | head -1
echo "$ATTRS" | grep "printer-location"
echo "$ATTRS" | grep "printer-contact"
echo "$ATTRS" | grep "printer-info"
echo ""

# Get print jobs
echo -e "${YELLOW}[5/5]${NC} Querying print jobs..."

cat > /tmp/get_jobs_$$.test << 'EOF'
{
    NAME "Get Jobs"
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

JOBS=$(ipptool -tv $IPP_URI /tmp/get_jobs_$$.test 2>&1)
rm /tmp/get_jobs_$$.test

if echo "$JOBS" | grep -q "job-id"; then
    echo -e "${GREEN}[OK]${NC} Jobs found"
    echo ""
    echo -e "${BLUE}═══ Print Jobs ═══${NC}"
    echo "$JOBS" | grep -E "job-id|job-name|job-originating-user-name|job-state" | head -20
else
    echo -e "${YELLOW}[INFO]${NC} No jobs in queue"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Discovery Complete!${NC}"
echo ""
echo "Full output saved to: printer_discovery.log"
echo ""

# Save full output
{
    echo "=== Printer Attributes ==="
    echo "$ATTRS"
    echo ""
    echo "=== Print Jobs ==="
    echo "$JOBS"
} > printer_discovery.log

echo "Commands used:"
echo "  Printer attributes: ipptool -tv $IPP_URI get-printer-attributes.test"
echo "  Print jobs: ipptool -tv $IPP_URI get-jobs.test"
```

**Make it executable:**
```bash
chmod +x discover_printer_ipp.sh
```

**Run it:**
```bash
./discover_printer_ipp.sh 192.168.1.131
```

---

## Part 11: Troubleshooting Common Issues

### Issue 1: "Connection refused"

**Error:**
```
ipptool: Unable to connect to "192.168.1.131" on port 631 - Connection refused
```

**Diagnosis:**
```bash
# Check if port is actually open
nc -zv 192.168.1.131 631
nmap -p 631 192.168.1.131
```

**Solutions:**
1. IPP service may be disabled
2. Enable via web interface: Network → Services → IPP
3. Check printer firewall settings
4. Verify you're on same network/VLAN

---

### Issue 2: "Unsupported operation"

**Error:**
```
status-code = server-error-operation-not-supported
```

**Diagnosis:**
- The printer doesn't support that IPP operation
- Try simpler operations first

**Solutions:**
```bash
# Try IPP version 1.0 or 1.1
ipptool -V 1.1 -tv ipp://192.168.1.131:631/ipp/print get-printer-attributes.test

# Try minimal attributes
# Change requested-attributes from "all" to specific ones
```

---

### Issue 3: "Bad Request"

**Error:**
```
status-code = client-error-bad-request
```

**Common Causes:**
- Syntax error in test file
- Missing required attribute
- Wrong attribute type

**Check:**
```bash
# Validate test file syntax
cat get-printer-attributes.test

# Look for:
# - Matching curly braces { }
# - All ATTR lines have correct format
# - No typos in attribute names
```

---

### Issue 4: Empty Response

**Error:**
```
Received 0 bytes in response
```

**Solutions:**
1. Wrong IPP path - try different paths
2. Printer doesn't support IPP properly
3. Network issue - check firewall

**Debug:**
```bash
# Try HTTP instead
curl http://192.168.1.131:631/

# Check printer web interface
firefox https://192.168.1.131
```

---

### Issue 5: ipptool Not Found

**Error:**
```
bash: ipptool: command not found
```

**Solution:**
```bash
# Install it
sudo apt update
sudo apt install cups-ipp-utils

# Verify
which ipptool
ipptool --version
```

---

## Part 12: Summary and Key Takeaways

### What You Discovered

Using ipptool from your Kali box, you discovered:

**From Get-Printer-Attributes:**
1. ✅ printer-location: `FLAG{LUKE47239581}`
2. ✅ printer-info: `FLAG{HAN62947103}`
3. ✅ printer-contact: `FLAG{LEIA83920174}`

**From Get-Jobs:**
4. ✅ job-originating-user-name: `FLAG{PADME91562837}`
5. ✅ job-name: `FLAG{MACE41927365}`

**Total:** 5 flags discovered via IPP

---

### Commands You Mastered

```bash
# Basic query
ipptool ipp://192.168.1.131:631/ipp/print get-printer-attributes.test

# Verbose output
ipptool -v ipp://192.168.1.131:631/ipp/print get-printer-attributes.test

# Test mode + verbose
ipptool -tv ipp://192.168.1.131:631/ipp/print get-printer-attributes.test

# Different IPP version
ipptool -V 1.1 -tv ipp://192.168.1.131:631/ipp/print get-printer-attributes.test

# Save output
ipptool -tv ipp://192.168.1.131:631/ipp/print get-printer-attributes.test > output.txt

# Get jobs
ipptool -tv ipp://192.168.1.131:631/ipp/print get-jobs.test

# Get specific job
ipptool -tv ipp://192.168.1.131:631/ipp/print get-job-attributes.test
```

---

### Test Files You Created

1. **get-printer-attributes.test** - Get all printer info
2. **get-specific-attributes.test** - Get targeted info
3. **get-jobs.test** - List all print jobs
4. **get-active-jobs.test** - Only active jobs
5. **get-recent-jobs.test** - Limited number of recent jobs
6. **get-job-attributes.test** - Details of specific job
7. **check-job-status.test** - Check job state

---

### Security Lessons Learned

**IPP exposes:**
- ✅ Printer configuration (location, contact, name)
- ✅ Print job history and metadata
- ✅ User information (who printed what)
- ✅ Document names and properties
- ✅ Network configuration details

**Defense mechanisms often missing:**
- ❌ No authentication required
- ❌ All data transmitted unencrypted
- ❌ Job history not cleared
- ❌ Sensitive data in public fields

---

### Next Steps for Learning

**Practice:**
1. Create your own test files with different operations
2. Query other printers on your network (with permission)
3. Compare SNMP data vs IPP data (same info, different protocol)
4. Write scripts to automate discovery

**Advanced Topics:**
1. IPP job submission (Print-Job operation)
2. Job manipulation (Hold-Job, Release-Job, Cancel-Job)
3. Printer control operations
4. Custom attributes and vendor extensions

---

## Quick Reference Card

### Essential Commands
```bash
# Install
sudo apt install cups-ipp-utils

# Basic query
ipptool -tv ipp://IP:631/ipp/print test.file

# Find endpoint
for p in /ipp/print /ipp/printer /ipp ""; do 
    ipptool -t ipp://IP:631$p test.file && echo "Use: $p" && break
done

# Save output
ipptool -tv ipp://IP:631/ipp/print test.file > out.txt

# Filter output
ipptool -tv ipp://IP:631/ipp/print test.file | grep -i "location\|contact"
```

### Test File Template
```
{
    NAME "Description"
    OPERATION Operation-Name
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR keyword requested-attributes all
    STATUS successful-ok
}
```

---

**You are now proficient in using ipptool for printer enumeration!** 🎯
