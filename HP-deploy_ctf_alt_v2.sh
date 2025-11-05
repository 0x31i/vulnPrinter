#!/bin/bash
################################################################################
# Test Different Job Hold Methods
# Find which method keeps jobs in upcoming/in-progress state
################################################################################

PRINTER_IP="192.168.1.131"
PRINTER_URI="ipp://${PRINTER_IP}:631/ipp/print"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     Testing Job Hold Methods                                   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Create test document
cat > /tmp/test_doc.txt << 'EOF'
Test document for job hold testing
EOF

# Test 1: job-hold-until indefinite
echo "[Test 1] Trying: job-hold-until indefinite"
cat > /tmp/test1.test << 'EOF'
{
    NAME "Test indefinite"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "test-indefinite"
    ATTR name job-name "Test-Indefinite"
    ATTR keyword job-hold-until indefinite
    FILE /tmp/test_doc.txt
    STATUS successful-ok
}
EOF
ipptool ${PRINTER_URI} /tmp/test1.test
sleep 2
cat > /tmp/check.test << 'EOF'
{
    NAME "Check Jobs"
    OPERATION Get-Jobs
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR uri printer-uri $uri
    ATTR keyword which-jobs not-completed
    STATUS successful-ok
}
EOF
RESULT=$(ipptool -tv ${PRINTER_URI} /tmp/check.test 2>/dev/null | grep -c "test-indefinite")
if [ $RESULT -gt 0 ]; then
    echo "✅ WORKS - Job is in not-completed queue"
else
    echo "❌ FAILED - Job not in active queue"
fi
echo ""

# Test 2: job-hold-until no-hold (should process immediately but might stay pending)
echo "[Test 2] Trying: job-hold-until no-hold"
cat > /tmp/test2.test << 'EOF'
{
    NAME "Test no-hold"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "test-no-hold"
    ATTR name job-name "Test-NoHold"
    ATTR keyword job-hold-until no-hold
    FILE /tmp/test_doc.txt
    STATUS successful-ok
}
EOF
ipptool ${PRINTER_URI} /tmp/test2.test
sleep 1
RESULT=$(ipptool -tv ${PRINTER_URI} /tmp/check.test 2>/dev/null | grep -c "test-no-hold")
if [ $RESULT -gt 0 ]; then
    echo "✅ WORKS - Job is in not-completed queue"
else
    echo "❌ FAILED - Job not in active queue"
fi
echo ""

# Test 3: Specific future time (1 hour from now)
echo "[Test 3] Trying: job-hold-until with future time"
FUTURE_TIME=$(date -u -d '+1 hour' '+%Y-%m-%dT%H:%M:%S.000Z')
cat > /tmp/test3.test << EOF
{
    NAME "Test future time"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri \$uri
    ATTR name requesting-user-name "test-future"
    ATTR name job-name "Test-Future"
    ATTR keyword job-hold-until ${FUTURE_TIME}
    FILE /tmp/test_doc.txt
    STATUS successful-ok
}
EOF
ipptool ${PRINTER_URI} /tmp/test3.test
sleep 2
RESULT=$(ipptool -tv ${PRINTER_URI} /tmp/check.test 2>/dev/null | grep -c "test-future")
if [ $RESULT -gt 0 ]; then
    echo "✅ WORKS - Job is in not-completed queue"
else
    echo "❌ FAILED - Job not in active queue"
fi
echo ""

# Test 4: Using printer operation-supported values
echo "[Test 4] Checking printer-supported job-hold-until values..."
cat > /tmp/check-supported.test << 'EOF'
{
    NAME "Check Supported Values"
    OPERATION Get-Printer-Attributes
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR uri printer-uri $uri
    ATTR keyword requested-attributes job-hold-until-supported
    STATUS successful-ok
}
EOF
echo "Supported values:"
ipptool -tv ${PRINTER_URI} /tmp/check-supported.test 2>/dev/null | grep "job-hold-until-supported"
echo ""

# Test 5: Pause the print queue first, then submit
echo "[Test 5] Trying: Pause queue, submit job, leave paused"
echo "NOTE: This requires printer control permissions"
cat > /tmp/test5-pause.test << 'EOF'
{
    NAME "Pause Printer"
    OPERATION Pause-Printer
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR uri printer-uri $uri
    STATUS successful-ok
}
EOF

cat > /tmp/test5-submit.test << 'EOF'
{
    NAME "Submit to paused printer"
    OPERATION Print-Job
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    ATTR uri printer-uri $uri
    ATTR name requesting-user-name "test-paused"
    ATTR name job-name "Test-Paused"
    FILE /tmp/test_doc.txt
    STATUS successful-ok
}
EOF

ipptool ${PRINTER_URI} /tmp/test5-pause.test 2>&1 | head -3
sleep 1
ipptool ${PRINTER_URI} /tmp/test5-submit.test
sleep 2
RESULT=$(ipptool -tv ${PRINTER_URI} /tmp/check.test 2>/dev/null | grep -c "test-paused")
if [ $RESULT -gt 0 ]; then
    echo "✅ WORKS - Job is in not-completed queue (printer paused)"
else
    echo "❌ FAILED - Job not in active queue"
fi
echo ""

# Clean up
rm /tmp/test*.test /tmp/check*.test /tmp/test_doc.txt

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    RESULTS SUMMARY                             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Check which test showed ✅ WORKS above."
echo ""
echo "To see all current jobs (not-completed):"
cat > /tmp/final-check.test << 'EOF'
{
    NAME "Final Check"
    OPERATION Get-Jobs
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR uri printer-uri $uri
    ATTR keyword which-jobs not-completed
    ATTR keyword requested-attributes job-id,job-name,job-originating-user-name,job-state,job-state-reasons
    STATUS successful-ok
}
EOF
ipptool -tv ${PRINTER_URI} /tmp/final-check.test
rm /tmp/final-check.test

echo ""
echo "If Test 5 (paused queue) worked, you can resume with:"
echo "  (But leave it paused for CTF so jobs stay in queue)"
echo ""
