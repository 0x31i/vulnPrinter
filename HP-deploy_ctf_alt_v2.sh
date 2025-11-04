#!/bin/bash
###############################################################################
# HP MFP 4301 CTF - Alternative Deployment Script V5
# Description: Added delays and retry logic for busy printer
# Platform: Kali Linux (or any Debian-based system)
# Usage: sudo ./deploy_ctf_alternative_V5.sh <PRINTER_IP> <ADMIN_PIN>
###############################################################################

set -e

# Configuration
PRINTER_IP="${1:-192.168.1.131}"
ADMIN_PIN="${2}"
TMP_DIR="/tmp/ctf_printer_v5_$$"
LOG_FILE="/tmp/ctf_deployment_v5_$(date +%Y%m%d_%H%M%S).log"
JOB_DELAY=5  # Seconds to wait between job submissions
MAX_RETRIES=3

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Banner
clear
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║          HP MFP 4301 CTF - Deployment Script V5                          ║
║          Fixed: Added delays and retry logic for busy printer            ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Logging functions
log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
info() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
header() { echo -e "\n${PURPLE}═══ $1 ═══${NC}" | tee -a "$LOG_FILE"; }

# Check requirements
if [ -z "$ADMIN_PIN" ]; then
    warning "Admin PIN not provided - skipping web API flags"
fi

if ! command -v ipptool &>/dev/null; then
    error "ipptool not installed. Install with: sudo apt install cups-ipp-utils"
    exit 1
fi

log "Starting CTF deployment V5 for printer: $PRINTER_IP"
log "Job submission delay: ${JOB_DELAY}s between jobs"
log "Log file: $LOG_FILE"

# Create workspace
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

# Deploy Web API flags
deploy_web_api_flags() {
    header "Deploying Flags via Web API"
    
    if [ -z "$ADMIN_PIN" ]; then
        warning "Skipping web API deployment (no admin PIN)"
        return
    fi
    
    info "FLAG 1: Deploying System Location..."
    curl -k -s -X POST "https://$PRINTER_IP/hp/device/set_config" \
        -u "admin:$ADMIN_PIN" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "sysLocation=Server-Room-B | Discovery Code: FLAG{LUKE47239581}" \
        &>>"$LOG_FILE" && success "FLAG 1 deployed - FLAG{LUKE47239581}" || warning "FLAG 1 failed"
    
    info "FLAG 2: Deploying System Contact..."
    curl -k -s -X POST "https://$PRINTER_IP/hp/device/set_config" \
        -u "admin:$ADMIN_PIN" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "sysContact=SecTeam@lab.local | FLAG{LEIA83920174}" \
        &>>"$LOG_FILE" && success "FLAG 2 deployed - FLAG{LEIA83920174}" || warning "FLAG 2 failed"
    
    info "FLAG 3: Deploying System Name..."
    curl -k -s -X POST "https://$PRINTER_IP/hp/device/set_config" \
        -u "admin:$ADMIN_PIN" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "sysName=HP-MFP-CTF-FLAG{HAN62947103}" \
        &>>"$LOG_FILE" && success "FLAG 3 deployed - FLAG{HAN62947103}" || warning "FLAG 3 failed"
}

# Submit a single IPP job with retry logic
submit_ipp_job_with_retry() {
    local job_name="$1"
    local user_name="$2"
    local display_name="$3"
    local file_path="$4"
    local flag_location="$5"
    
    info "Submitting job: $display_name"
    info "  Job Name: $job_name"
    info "  User: $user_name"
    
    # Verify file exists
    if [ ! -f "$file_path" ]; then
        error "File not found: $file_path"
        return 1
    fi
    
    # Create test file
    local test_file="$TMP_DIR/submit_${display_name}_$$.test"
    
    cat > "$test_file" <<TESTEOF
{
    NAME "$display_name"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri \$uri
    ATTR name requesting-user-name "$user_name"
    ATTR name job-name "$job_name"
    
    FILE $file_path
    
    STATUS successful-ok
}
TESTEOF
    
    # Try submitting with retries
    local retry=0
    while [ $retry -lt $MAX_RETRIES ]; do
        local output_file="$TMP_DIR/ipp_output_${display_name}_${retry}_$$.txt"
        
        info "Attempt $((retry+1))/$MAX_RETRIES..."
        
        if timeout 15 ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$test_file" > "$output_file" 2>&1; then
            if grep -q "successful-ok" "$output_file"; then
                success "✓ Job submitted successfully on attempt $((retry+1))"
                info "  Flag location: $flag_location"
                return 0
            elif grep -q "server-error-busy" "$output_file"; then
                warning "Printer is busy, waiting 10 seconds..."
                sleep 10
                ((retry++))
                continue
            else
                error "✗ Job submission failed with error:"
                grep "status-code" "$output_file" | head -5 | tee -a "$LOG_FILE"
                ((retry++))
                sleep 5
                continue
            fi
        else
            error "✗ ipptool command timed out"
            ((retry++))
            sleep 5
            continue
        fi
    done
    
    error "Job submission failed after $MAX_RETRIES attempts"
    return 1
}

# Deploy PADME flag
deploy_padme_flag() {
    header "Deploying FLAG{PADME91562837} - Job Metadata Challenge"
    
    # Create document content
    local padme_file="$TMP_DIR/padme_job.txt"
    cat > "$padme_file" << 'EOF'
════════════════════════════════════════════════════════════════
NETWORK CONFIGURATION BACKUP - METADATA CHALLENGE
════════════════════════════════════════════════════════════════

FLAG LOCATION: job-originating-user-name attribute

Discovery Method:
1. Create get-jobs.test file with Get-Jobs operation
2. Run: ipptool -tv ipp://PRINTER_IP:631/ipp/print get-jobs.test
3. Search output for "job-originating-user-name" attribute
4. Look for the FLAG in the username field

════════════════════════════════════════════════════════════════
EOF
    
    info "PADME job file created: $(wc -l < "$padme_file") lines"
    
    # Submit job - just once to avoid overwhelming the printer
    if submit_ipp_job_with_retry \
        "Network-Config-Backup" \
        "FLAG{PADME91562837}" \
        "PADME_Job" \
        "$padme_file" \
        "job-originating-user-name"; then
        success "FLAG{PADME91562837} deployed successfully"
    else
        error "FLAG{PADME91562837} deployment failed"
    fi
    
    info "Waiting ${JOB_DELAY}s before next submission..."
    sleep $JOB_DELAY
}

# Deploy MACE flag
deploy_mace_flag() {
    header "Deploying FLAG{MACE41927365} - Job Name Challenge"
    
    # Create document content
    local mace_file="$TMP_DIR/mace_job.txt"
    cat > "$mace_file" << 'EOF'
════════════════════════════════════════════════════════════════
CTF CHALLENGE JOB - JOB NAME FLAG
════════════════════════════════════════════════════════════════

FLAG LOCATION: job-name attribute

Discovery Method:
1. Create get-jobs.test file with Get-Jobs operation
2. Run: ipptool -tv ipp://PRINTER_IP:631/ipp/print get-jobs.test
3. Search output for "job-name" attribute
4. Look for "CTF-Challenge-Job-FLAG" in the job name

════════════════════════════════════════════════════════════════
EOF
    
    info "MACE job file created: $(wc -l < "$mace_file") lines"
    
    # Submit job - just once to avoid overwhelming the printer
    if submit_ipp_job_with_retry \
        "CTF-Challenge-Job-FLAG{MACE41927365}" \
        "security-audit" \
        "MACE_Job" \
        "$mace_file" \
        "job-name"; then
        success "FLAG{MACE41927365} deployed successfully"
    else
        error "FLAG{MACE41927365} deployment failed"
    fi
    
    info "Waiting ${JOB_DELAY}s before next submission..."
    sleep $JOB_DELAY
}

# Deploy additional jobs
deploy_other_jobs() {
    header "Deploying Additional Print Jobs"
    
    # Confidential Report
    info "Creating Confidential Security Report job..."
    local conf_file="$TMP_DIR/confidential.txt"
    cat > "$conf_file" << 'EOF'
CONFIDENTIAL - SECURITY ASSESSMENT REPORT
Authorization Token: FLAG{OBIWAN73049281}
Subject: Network Printer Security Assessment
EOF
    
    submit_ipp_job_with_retry \
        "Confidential-Security-Report" \
        "security-team" \
        "Confidential" \
        "$conf_file" \
        "document content" || warning "Confidential job failed"
    
    sleep $JOB_DELAY
    
    # PostScript Challenge
    info "Creating PostScript Challenge job..."
    local ps_file="$TMP_DIR/ps_challenge.txt"
    cat > "$ps_file" << 'EOF'
PostScript Security Challenge
Flag for this challenge: FLAG{VADER28374615}
Hint: PostScript is Turing-complete
EOF
    
    submit_ipp_job_with_retry \
        "PostScript-Challenge" \
        "ctf-challenge" \
        "PostScript" \
        "$ps_file" \
        "document content" || warning "PostScript job failed"
}

# Verify deployment
verify_flags() {
    header "Verifying Flag Deployment"
    
    info "Waiting 10 seconds for jobs to settle in queue..."
    sleep 10
    
    # Create verification test
    cat > "$TMP_DIR/verify.test" << 'EOF'
{
    NAME "Verify Jobs"
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
    
    info "Querying all jobs in queue..."
    local verify_output="$TMP_DIR/verification.txt"
    
    if timeout 15 ipptool -tv "ipp://$PRINTER_IP:631/ipp/print" "$TMP_DIR/verify.test" > "$verify_output" 2>&1; then
        
        echo ""
        info "═══ Verification Results ═══"
        
        # Check PADME flag
        if grep -q "FLAG{PADME91562837}" "$verify_output"; then
            success "✓✓✓ FLAG{PADME91562837} FOUND in queue ✓✓✓"
            local padme_count=$(grep -c "FLAG{PADME91562837}" "$verify_output" || echo 0)
            info "  Appears $padme_count time(s) in queue"
        else
            error "✗ FLAG{PADME91562837} NOT FOUND in queue"
            warning "  Job may have processed quickly and left the queue"
        fi
        
        # Check MACE flag
        if grep -q "FLAG{MACE41927365}" "$verify_output"; then
            success "✓✓✓ FLAG{MACE41927365} FOUND in queue ✓✓✓"
            local mace_count=$(grep -c "FLAG{MACE41927365}" "$verify_output" || echo 0)
            info "  Appears $mace_count time(s) in queue"
        else
            error "✗ FLAG{MACE41927365} NOT FOUND in queue"
            warning "  Job may have processed quickly and left the queue"
        fi
        
        echo ""
        info "All jobs currently in queue:"
        grep -E "job-id|job-name|job-originating-user-name|job-state" "$verify_output" | head -50 | tee "$TMP_DIR/jobs_summary.txt"
        
        echo ""
        info "Full verification saved to: $verify_output"
        
    else
        error "Job verification query failed or timed out"
    fi
}

# Create student guide
create_student_guide() {
    cat > "$TMP_DIR/STUDENT_GUIDE.txt" << EOF
════════════════════════════════════════════════════════════════
    STUDENT DISCOVERY GUIDE
    HP MFP 4301 IoT Printer CTF - IPP Job Enumeration
════════════════════════════════════════════════════════════════

TARGET: $PRINTER_IP
PORT: 631 (IPP)

OBJECTIVE: Find 2 flags hidden in print job metadata

═══════════════════════════════════════════════════════════════

STEP 1: Create IPP test file
-----------------------------
cat > get-jobs.test << 'TESTFILE'
{
    NAME "Get All Print Jobs"
    OPERATION Get-Jobs
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri \$uri
    ATTR keyword which-jobs all
    ATTR keyword requested-attributes all
    STATUS successful-ok
}
TESTFILE

STEP 2: Query the printer
--------------------------
ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test

STEP 3: Find the flags
----------------------
Search the output for:
1. "job-originating-user-name" → Contains FLAG{PADME91562837}
2. "job-name" → Contains FLAG{MACE41927365}

Quick search command:
ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test | grep FLAG

════════════════════════════════════════════════════════════════
EOF
    
    success "Student guide created: $TMP_DIR/STUDENT_GUIDE.txt"
}

# Main execution
main() {
    deploy_web_api_flags
    echo ""
    deploy_padme_flag
    echo ""
    deploy_mace_flag
    echo ""
    deploy_other_jobs
    echo ""
    verify_flags
    echo ""
    create_student_guide
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                     DEPLOYMENT COMPLETE                                   ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}Important Files:${NC}"
    echo "  Log: $LOG_FILE"
    echo "  Workspace: $TMP_DIR"
    echo "  Student Guide: $TMP_DIR/STUDENT_GUIDE.txt"
    echo "  Verification: $TMP_DIR/verification.txt"
    echo ""
    
    echo -e "${CYAN}Student Test Command:${NC}"
    echo "  ipptool -tv ipp://$PRINTER_IP:631/ipp/print get-jobs.test | grep FLAG"
    echo ""
    
    echo -e "${PURPLE}Notes:${NC}"
    echo "  - Jobs process quickly on this printer"
    echo "  - Run verification immediately to catch flags in queue"
    echo "  - Can re-run deployment script to create fresh jobs"
    echo ""
}

main
exit 0
