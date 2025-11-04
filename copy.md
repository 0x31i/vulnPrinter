# Create the get-jobs test file
cat > /tmp/get-jobs-now.test << 'EOF'
{
    NAME "Get Jobs Now"
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

# Query RIGHT NOW while jobs are visible in web UI
ipptool -tv ipp://192.168.1.131:631/ipp/print /tmp/get-jobs-now.test > /tmp/current-jobs.txt

# Search for our flags
grep -E "FLAG|PADME|MACE|job-name|job-originating" /tmp/current-jobs.txt
