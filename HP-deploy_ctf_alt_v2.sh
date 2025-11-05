#!/bin/bash
################################################################################
# Alternative Print Job Flag Deployment
# Since held jobs aren't persisting, we'll use completed job history
################################################################################

PRINTER_IP="192.168.1.131"
PRINTER_URI="ipp://${PRINTER_IP}:631/ipp/print"

echo "Testing print job methods..."
echo ""

# Method 1: Submit WITHOUT hold parameter and query completed jobs
echo "[Method 1] Submit job without hold, query completed history..."

cat > /tmp/ctf_document.txt << 'DOCEOF'
CTF Challenge Document - Security Assessment
DOCEOF

cat > /tmp/submit-normal-job.test << 'EOF'
{
    NAME "Submit Normal Job"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "FLAG{PADME91562837}"
    ATTR name job-name "CTF-Challenge-Job-FLAG{MACE41927365}"
    
    FILE /tmp/ctf_document.txt
    
    STATUS successful-ok
}
EOF

ipptool -tv ${PRINTER_URI} /tmp/submit-normal-job.test

echo ""
echo "Waiting 3 seconds for job to process..."
sleep 3

# Query completed jobs
echo ""
echo "Querying completed jobs:"
cat > /tmp/get-completed-jobs.test << 'EOF'
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

ipptool -tv ${PRINTER_URI} /tmp/get-completed-jobs.test | grep -E "job-id|job-name|job-originating-user-name|FLAG"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Method 2: Query ALL jobs (not, completed, pending, processing, aborted, canceled)
echo "[Method 2] Query all job types..."

cat > /tmp/get-all-jobs-types.test << 'EOF'
{
    NAME "Get All Job Types"
    OPERATION Get-Jobs
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR keyword which-jobs all
    ATTR keyword requested-attributes job-id,job-name,job-originating-user-name,job-state,job-state-reasons
    STATUS successful-ok
}
EOF

ipptool -tv ${PRINTER_URI} /tmp/get-all-jobs-types.test

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Method 3: Submit multiple jobs rapidly
echo "[Method 3] Submitting 3 jobs rapidly..."

for i in {1..3}; do
    cat > /tmp/submit-job-$i.test << EOF
{
    NAME "Submit Job $i"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri \$uri
    ATTR name requesting-user-name "FLAG{PADME91562837}"
    ATTR name job-name "CTF-Challenge-Job-FLAG{MACE41927365}-$i"
    
    FILE /tmp/ctf_document.txt
    
    STATUS successful-ok
}
EOF
    
    ipptool ${PRINTER_URI} /tmp/submit-job-$i.test &>/dev/null &
done

wait
echo "Jobs submitted, querying immediately..."

ipptool -tv ${PRINTER_URI} /tmp/get-all-jobs-types.test | grep -E "job-id|FLAG"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Cleanup
rm /tmp/ctf_document.txt /tmp/submit-*.test /tmp/get-*.test

echo "Summary:"
echo "  - If completed jobs are kept: Method 1 works"
echo "  - If no job history: Jobs won't persist"
echo "  - Alternative: Use PRET filesystem-based flags (permanent)"
echo ""
