#!/bin/bash
################################################################################
# Alternative Methods to Send PJL Commands
# When netcat hangs, use these instead
################################################################################

PRINTER_IP="192.168.1.131"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     PJL Command Sending - Alternative Methods                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

################################################################################
# Method 1: Netcat with proper timeout flags
################################################################################

echo "[Method 1] Netcat with timeout and quit flags..."

cat > /tmp/yoda_flag.pjl << 'EOF'
%-12345X@PJL
@PJL RDYMSG DISPLAY="Printer Ready | FLAG{YODA62847193}"
%-12345X
EOF

# Try different netcat variations
if timeout 5 nc -w 2 -q 1 ${PRINTER_IP} 9100 < /tmp/yoda_flag.pjl 2>/dev/null; then
    echo "✓ Method 1a worked (-w 2 -q 1)"
elif timeout 5 nc -w 2 ${PRINTER_IP} 9100 < /tmp/yoda_flag.pjl 2>/dev/null; then
    echo "✓ Method 1b worked (-w 2)"
elif timeout 5 nc ${PRINTER_IP} 9100 < /tmp/yoda_flag.pjl 2>/dev/null; then
    echo "✓ Method 1c worked (basic timeout)"
else
    echo "✗ Netcat methods failed"
fi
echo ""

################################################################################
# Method 2: Using telnet
################################################################################

echo "[Method 2] Using telnet..."

(
    sleep 1
    cat /tmp/yoda_flag.pjl
    sleep 1
) | timeout 5 telnet ${PRINTER_IP} 9100 2>/dev/null | head -10

if [ $? -eq 0 ]; then
    echo "✓ Telnet method worked"
else
    echo "✗ Telnet method failed"
fi
echo ""

################################################################################
# Method 3: Using Python socket (most reliable)
################################################################################

echo "[Method 3] Using Python socket..."

python3 << PYEOF
import socket
import time

printer_ip = "${PRINTER_IP}"
port = 9100

pjl_command = b"""%-12345X@PJL
@PJL RDYMSG DISPLAY="Printer Ready | FLAG{YODA62847193}"
%-12345X
"""

try:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(5)
    sock.connect((printer_ip, port))
    sock.sendall(pjl_command)
    time.sleep(0.5)
    
    # Try to receive response
    try:
        response = sock.recv(1024)
        if response:
            print("Response:", response.decode('utf-8', errors='ignore'))
    except:
        pass
    
    sock.close()
    print("✓ Python socket method succeeded")
except Exception as e:
    print(f"✗ Python socket failed: {e}")
PYEOF

echo ""

################################################################################
# Method 4: Using socat (if installed)
################################################################################

echo "[Method 4] Using socat..."

if command -v socat &>/dev/null; then
    timeout 5 socat - TCP:${PRINTER_IP}:9100 < /tmp/yoda_flag.pjl 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✓ socat method worked"
    else
        echo "✗ socat method failed"
    fi
else
    echo "⊘ socat not installed (skip)"
fi
echo ""

################################################################################
# Method 5: Using expect (interactive automation)
################################################################################

echo "[Method 5] Using expect..."

if command -v expect &>/dev/null; then
    expect << 'EXPECTEOF' 2>/dev/null
set timeout 5
spawn nc 192.168.1.131 9100
send [read [open /tmp/yoda_flag.pjl r]]
expect timeout
close
EXPECTEOF
    echo "✓ Expect method completed"
else
    echo "⊘ expect not installed (skip)"
fi
echo ""

################################################################################
# Method 6: Using /dev/tcp bash built-in (most portable)
################################################################################

echo "[Method 6] Using bash /dev/tcp..."

(
    exec 3<>/dev/tcp/${PRINTER_IP}/9100
    cat /tmp/yoda_flag.pjl >&3
    sleep 1
    exec 3>&-
) 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✓ Bash /dev/tcp method worked"
else
    echo "✗ Bash /dev/tcp method failed"
fi
echo ""

rm /tmp/yoda_flag.pjl

################################################################################
# Verification
################################################################################

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    VERIFICATION                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "Testing if YODA flag was set..."

# Use Python to read back
python3 << PYEOF
import socket

printer_ip = "${PRINTER_IP}"
port = 9100

query = b"""%-12345X@PJL INFO STATUS
%-12345X
"""

try:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(5)
    sock.connect((printer_ip, port))
    sock.sendall(query)
    
    response = b""
    while True:
        try:
            chunk = sock.recv(1024)
            if not chunk:
                break
            response += chunk
        except socket.timeout:
            break
    
    sock.close()
    
    response_str = response.decode('utf-8', errors='ignore')
    if "FLAG{YODA62847193}" in response_str:
        print("✅ YODA flag is set and readable!")
        print("\nResponse excerpt:")
        for line in response_str.split('\n'):
            if 'FLAG' in line or 'Ready' in line:
                print(f"  {line}")
    else:
        print("⚠️  YODA flag not found in response")
        print("\nFull response:")
        print(response_str[:500])
        
except Exception as e:
    print(f"❌ Verification failed: {e}")
PYEOF

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                  RECOMMENDED METHOD                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Based on testing above, use the method that showed ✓ success"
echo ""
echo "Most reliable: Python socket method (Method 3)"
echo ""

exit 0
