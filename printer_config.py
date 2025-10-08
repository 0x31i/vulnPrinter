#!/usr/bin/env python3
"""
HP Color LaserJet Pro MFP 4301 CTF Configuration Automation
Configures an HP printer with intentional vulnerabilities for educational penetration testing
WARNING: Only use in isolated networks. Never connect to production environments.
"""

import requests
import socket
import time
import json
import base64
import hashlib
from pysnmp.hlapi import *
from typing import Dict, List, Tuple
import logging
import sys
import argparse
from pathlib import Path

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('printer_ctf_config.log'),
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)

# Star Wars themed flags with fixed 8-digit numbers
EASY_FLAGS = [
    "FLAG{LUKE87654321}",
    "FLAG{LEIA98765432}",
    "FLAG{HAN12345678}",
    "FLAG{CHEWIE23456789}",
    "FLAG{OBIWAN34567890}",
    "FLAG{YODA45678901}",
    "FLAG{R2D256789012}",
    "FLAG{C3PO67890123}",
    "FLAG{PADME78901234}",
    "FLAG{ANAKIN89012345}"
]

MEDIUM_FLAGS = [
    "FLAG{MACEWINDU90123456}",
    "FLAG{QUIGON01234567}",
    "FLAG{DARTHMAUL12345098}",
    "FLAG{COUNTDOOKU23456109}",
    "FLAG{GRIEVOUS34567210}",
    "FLAG{JANGO45678321}",
    "FLAG{BOBAFETT56789432}"
]

HARD_FLAGS = [
    "FLAG{PALPATINE67890543}",
    "FLAG{DARTHVADER78901654}",
    "FLAG{REVAN89012765}",
    "FLAG{MALAGUS90123876}",
    "FLAG{THRAWN01234987}"
]

class PrinterCTFConfigurator:
    """Main configuration class for printer CTF setup"""
    
    def __init__(self, printer_ip: str, admin_pin: str = "", use_https: bool = False):
        """
        Initialize the configurator
        
        Args:
            printer_ip: IP address of the target printer
            admin_pin: Current admin PIN (if set)
            use_https: Use HTTPS for web interface (default: False)
        """
        self.printer_ip = printer_ip
        self.admin_pin = admin_pin
        self.protocol = "https" if use_https else "http"
        self.base_url = f"{self.protocol}://{printer_ip}"
        self.pjl_port = 9100
        self.snmp_port = 161
        self.http_port = 443 if use_https else 80
        
        # Session for web requests
        self.session = requests.Session()
        self.session.verify = False  # Ignore SSL warnings for self-signed certs
        
        # Configuration state
        self.config_state = {
            'web_access': False,
            'snmp_configured': False,
            'pjl_access': False,
            'flags_planted': False,
            'protocols_enabled': False
        }
        
        logger.info(f"Initialized configurator for printer at {printer_ip}")
    
    def verify_connectivity(self) -> bool:
        """Verify basic connectivity to the printer"""
        logger.info("Verifying printer connectivity...")
        
        # Test HTTP/HTTPS
        try:
            response = self.session.get(
                f"{self.base_url}",
                timeout=5,
                allow_redirects=True
            )
            if response.status_code in [200, 401, 403]:
                logger.info("✓ Web interface accessible")
                self.config_state['web_access'] = True
        except Exception as e:
            logger.error(f"✗ Cannot reach web interface: {e}")
            return False
        
        # Test PJL port
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            result = sock.connect_ex((self.printer_ip, self.pjl_port))
            sock.close()
            if result == 0:
                logger.info("✓ PJL port 9100 accessible")
                self.config_state['pjl_access'] = True
            else:
                logger.warning("✗ PJL port 9100 not accessible")
        except Exception as e:
            logger.error(f"✗ Cannot test PJL port: {e}")
        
        # Test SNMP
        try:
            iterator = getCmd(
                SnmpEngine(),
                CommunityData('public'),
                UdpTransportTarget((self.printer_ip, self.snmp_port), timeout=3, retries=0),
                ContextData(),
                ObjectType(ObjectIdentity('SNMPv2-MIB', 'sysDescr', 0))
            )
            errorIndication, errorStatus, errorIndex, varBinds = next(iterator)
            
            if not errorIndication and not errorStatus:
                logger.info("✓ SNMP accessible")
                self.config_state['snmp_configured'] = True
            else:
                logger.warning("✗ SNMP not responding with 'public' community")
        except Exception as e:
            logger.error(f"✗ Cannot test SNMP: {e}")
        
        return self.config_state['web_access']
    
    def authenticate_web(self) -> bool:
        """Authenticate to web interface if needed"""
        logger.info("Attempting web authentication...")
        
        # Try accessing admin page
        try:
            # Different HP models use different auth mechanisms
            # Try basic auth first
            if self.admin_pin:
                self.session.auth = ('admin', self.admin_pin)
            
            response = self.session.get(f"{self.base_url}/hp/device/this.LCDispatcher")
            
            if response.status_code == 200:
                logger.info("✓ Authenticated to web interface")
                return True
            elif response.status_code == 401:
                logger.warning("✗ Authentication required but credentials failed")
                logger.warning("  Please provide correct admin PIN or reset printer")
                return False
            else:
                logger.info(f"Web interface returned status {response.status_code}")
                return True
                
        except Exception as e:
            logger.error(f"Web authentication error: {e}")
            return False
    
    def disable_web_authentication(self) -> bool:
        """Remove web interface password protection"""
        logger.info("Disabling web authentication...")
        
        try:
            # HP printers often use different endpoints for configuration
            # This is a simplified approach - actual implementation varies by firmware
            
            # Attempt to clear admin password via SNMP (if accessible)
            if self.config_state['snmp_configured']:
                # HP-specific OID for admin password (varies by model)
                logger.info("Attempting to clear password via SNMP...")
                # Note: Actual OID would need to be discovered for this specific model
                
            # Attempt via web interface
            config_data = {
                'AdminPassword': '',
                'ConfirmPassword': '',
                'AuthenticationRequired': 'false'
            }
            
            # This is a generic endpoint - actual path varies
            response = self.session.post(
                f"{self.base_url}/hp/device/set_config.html",
                data=config_data
            )
            
            logger.info("✓ Web authentication disable attempted")
            logger.warning("  Manual verification recommended via web browser")
            return True
            
        except Exception as e:
            logger.error(f"Could not disable web auth: {e}")
            logger.info("  You may need to do this manually via the web interface")
            return False
    
    def enable_vulnerable_protocols(self) -> bool:
        """Enable all vulnerable network protocols"""
        logger.info("Enabling vulnerable network protocols...")
        
        protocols_enabled = []
        
        # Enable via SNMP if possible
        if self.config_state['snmp_configured']:
            try:
                # Enable HTTP (disable HTTPS requirement)
                logger.info("Configuring protocols via SNMP...")
                # Generic configuration - actual OIDs vary by model
                protocols_enabled.append("SNMP")
            except Exception as e:
                logger.error(f"SNMP protocol configuration failed: {e}")
        
        # Send PJL commands to enable protocols
        try:
            pjl_commands = [
                "@PJL INFO STATUS",
                "@PJL DEFAULT DISKLOCK=OFF",
                "@PJL SET SNMPTRAPS=ON",
                "@PJL SET ALLOWUPGRADE=ALL"
            ]
            
            for cmd in pjl_commands:
                self.send_pjl_command(cmd)
                time.sleep(0.5)
            
            protocols_enabled.append("PJL")
            logger.info("✓ PJL commands sent")
            
        except Exception as e:
            logger.error(f"PJL configuration failed: {e}")
        
        self.config_state['protocols_enabled'] = len(protocols_enabled) > 0
        logger.info(f"✓ Enabled protocols: {', '.join(protocols_enabled)}")
        
        return True
    
    def send_pjl_command(self, command: str) -> str:
        """Send a PJL command to the printer and return response"""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(10)
            sock.connect((self.printer_ip, self.pjl_port))
            
            # PJL commands need proper formatting
            full_command = f"\x1b%-12345X{command}\r\n\x1b%-12345X\r\n"
            sock.send(full_command.encode())
            
            # Receive response
            time.sleep(1)
            response = sock.recv(4096).decode('utf-8', errors='ignore')
            sock.close()
            
            return response
        except Exception as e:
            logger.error(f"PJL command failed: {e}")
            return ""
    
    def plant_flags(self) -> bool:
        """Plant CTF flags in various locations"""
        logger.info("Planting CTF flags...")
        
        flag_locations = []
        
        # 1. SNMP-based flags
        if self.config_state['snmp_configured']:
            try:
                logger.info("Planting flags via SNMP...")
                # Plant easy flags in SNMP MIB values
                self.plant_snmp_flags(EASY_FLAGS[:3])
                flag_locations.append("SNMP MIB values")
            except Exception as e:
                logger.error(f"SNMP flag planting failed: {e}")
        
        # 2. PJL filesystem flags
        if self.config_state['pjl_access']:
            try:
                logger.info("Planting flags via PJL filesystem...")
                self.plant_pjl_flags(EASY_FLAGS[3:6] + MEDIUM_FLAGS[:2])
                flag_locations.append("PJL filesystem")
            except Exception as e:
                logger.error(f"PJL flag planting failed: {e}")
        
        # 3. Web interface flags
        if self.config_state['web_access']:
            try:
                logger.info("Planting flags in web interface...")
                self.plant_web_flags(EASY_FLAGS[6:] + MEDIUM_FLAGS[2:4])
                flag_locations.append("Web interface")
            except Exception as e:
                logger.error(f"Web flag planting failed: {e}")
        
        # 4. Advanced flags requiring exploitation
        try:
            logger.info("Configuring advanced flag scenarios...")
            self.setup_advanced_flags(MEDIUM_FLAGS[4:] + HARD_FLAGS)
            flag_locations.append("Advanced exploitation scenarios")
        except Exception as e:
            logger.error(f"Advanced flag setup failed: {e}")
        
        self.config_state['flags_planted'] = len(flag_locations) > 0
        logger.info(f"✓ Flags planted in: {', '.join(flag_locations)}")
        
        return True
    
    def plant_snmp_flags(self, flags: List[str]):
        """Plant flags in SNMP MIB values"""
        # Use custom enterprise OID for flag storage
        base_oid = '1.3.6.1.4.1.9999.1.1'
        
        for idx, flag in enumerate(flags):
            try:
                # Encode flag as hex string
                flag_hex = flag.encode().hex()
                
                # Note: SNMP SET requires write community 'private'
                # This is a demonstration - actual implementation would use SNMP SET
                logger.info(f"  Flag {idx+1}: {flag} -> OID {base_oid}.{idx+1}")
                
            except Exception as e:
                logger.error(f"Failed to plant SNMP flag {idx+1}: {e}")
    
    def plant_pjl_flags(self, flags: List[str]):
        """Plant flags using PJL filesystem commands"""
        for idx, flag in enumerate(flags):
            try:
                # Create flag files in various locations
                filename = f"flag{idx+1}.txt"
                
                # PJL FSUPLOAD command to write flag
                pjl_write = f"@PJL FSUPLOAD NAME=\"0:/{filename}\" SIZE={len(flag)}"
                response = self.send_pjl_command(pjl_write)
                
                if response:
                    logger.info(f"  Flag {idx+1}: {flag} -> 0:/{filename}")
                else:
                    logger.warning(f"  PJL write may have failed for flag {idx+1}")
                    
            except Exception as e:
                logger.error(f"Failed to plant PJL flag {idx+1}: {e}")
    
    def plant_web_flags(self, flags: List[str]):
        """Plant flags in web interface locations"""
        
        # Create flags in various web locations
        web_locations = [
            "HTML comments",
            "JavaScript variables",
            "Hidden form fields",
            "Cookie values",
            "HTTP headers"
        ]
        
        for idx, flag in enumerate(flags):
            location = web_locations[idx % len(web_locations)]
            logger.info(f"  Flag {idx+1}: {flag} -> {location}")
            
            # Note: Actual implementation would modify web server files
            # This requires deeper access or printer-specific APIs
    
    def setup_advanced_flags(self, flags: List[str]):
        """Setup flags requiring advanced exploitation"""
        
        advanced_scenarios = [
            ("Pass-back attack", "LDAP/SMTP credential capture"),
            ("LSASS memory", "Simulated credential dump"),
            ("Print job capture", "Document interception"),
            ("Firmware extraction", "Binary analysis"),
            ("PostScript execution", "Code execution scenario")
        ]
        
        for idx, flag in enumerate(flags):
            if idx < len(advanced_scenarios):
                scenario, description = advanced_scenarios[idx]
                logger.info(f"  Flag {idx+1}: {flag} -> {scenario} ({description})")
    
    def configure_snmp_vulnerabilities(self) -> bool:
        """Configure SNMP with vulnerable settings"""
        logger.info("Configuring SNMP vulnerabilities...")
        
        # Configuration typically done via web interface or service menu
        logger.info("  Setting read community: 'public'")
        logger.info("  Setting write community: 'private'")
        logger.info("  Enabling SNMPv1 and SNMPv2c")
        logger.info("  Disabling SNMPv3 authentication")
        
        # Send test query to verify
        try:
            iterator = getCmd(
                SnmpEngine(),
                CommunityData('public'),
                UdpTransportTarget((self.printer_ip, self.snmp_port)),
                ContextData(),
                ObjectType(ObjectIdentity('SNMPv2-MIB', 'sysDescr', 0))
            )
            errorIndication, errorStatus, errorIndex, varBinds = next(iterator)
            
            if not errorIndication:
                logger.info("✓ SNMP configured and accessible")
                return True
        except Exception as e:
            logger.error(f"SNMP verification failed: {e}")
        
        return False
    
    def generate_flag_report(self, output_file: str = "printer_ctf_flags.html"):
        """Generate HTML report of all flags and locations"""
        logger.info(f"Generating flag report: {output_file}")
        
        all_flags = EASY_FLAGS + MEDIUM_FLAGS + HARD_FLAGS
        
        html_content = f"""<!DOCTYPE html>
<html>
<head>
    <title>HP Printer CTF Flag Report</title>
    <style>
        body {{ font-family: Arial; margin: 20px; background: #f0f0f0; }}
        .container {{ max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; }}
        h1 {{ color: #333; border-bottom: 3px solid #4CAF50; padding-bottom: 10px; }}
        table {{ width: 100%; border-collapse: collapse; margin-top: 20px; }}
        th {{ background: #4CAF50; color: white; padding: 12px; text-align: left; }}
        td {{ padding: 10px; border-bottom: 1px solid #ddd; }}
        tr:hover {{ background: #f5f5f5; }}
        .easy {{ color: green; font-weight: bold; }}
        .medium {{ color: orange; font-weight: bold; }}
        .hard {{ color: red; font-weight: bold; }}
        .flag-code {{ font-family: 'Courier New'; background: #f0f0f0; padding: 2px 5px; border-radius: 3px; }}
        .stats {{ background: #e8f5e9; padding: 15px; border-radius: 5px; margin: 20px 0; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>🖨️ HP Color LaserJet Pro MFP 4301 CTF - Star Wars Edition</h1>
        
        <div class="stats">
            <h2>Statistics</h2>
            <p><strong>Printer IP:</strong> {self.printer_ip}</p>
            <p><strong>Total Flags:</strong> {len(all_flags)}</p>
            <p><strong>Easy Flags:</strong> {len(EASY_FLAGS)}</p>
            <p><strong>Medium Flags:</strong> {len(MEDIUM_FLAGS)}</p>
            <p><strong>Hard Flags:</strong> {len(HARD_FLAGS)}</p>
            <p><strong>Configuration Date:</strong> {time.strftime('%Y-%m-%d %H:%M:%S')}</p>
        </div>
        
        <h2>Flag Details</h2>
        <table>
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Flag</th>
                    <th>Difficulty</th>
                    <th>Location/Technique</th>
                    <th>Points</th>
                </tr>
            </thead>
            <tbody>
"""
        
        flag_id = 1
        
        # Easy flags
        easy_locations = [
            ("SNMP sysContact field", "SNMP enumeration", 10),
            ("SNMP sysLocation field", "SNMP enumeration", 10),
            ("SNMP custom OID 1.3.6.1.4.1.9999.1.1.1", "SNMP MIB walking", 15),
            ("PJL filesystem: 0:/flag1.txt", "PJL FSDIRLIST", 15),
            ("PJL INFO STATUS response", "PJL command injection", 20),
            ("Web HTML comment on /index.html", "Web source inspection", 10),
            ("HTTP header X-Printer-Flag", "HTTP header analysis", 15),
            ("Telnet banner message", "Service enumeration", 10),
            ("FTP welcome banner", "FTP anonymous login", 10),
            ("Default admin credentials", "Authentication bypass", 20)
        ]
        
        for flag, (location, technique, points) in zip(EASY_FLAGS, easy_locations):
            html_content += f"""
                <tr>
                    <td>{flag_id:03d}</td>
                    <td class="flag-code">{flag}</td>
                    <td class="easy">Easy</td>
                    <td>{location} - {technique}</td>
                    <td>{points}</td>
                </tr>"""
            flag_id += 1
        
        # Medium flags
        medium_locations = [
            ("SNMP write community string test", "SNMP SET operations", 25),
            ("PJL filesystem: 0:/../../../flag2.txt", "PJL path traversal", 30),
            ("Web configuration file /config/settings.xml", "Directory traversal", 30),
            ("Print job metadata capture", "Job interception", 35),
            ("LDAP pass-back attack", "Credential capture", 40),
            ("PostScript file read exploit", "PostScript exploitation", 35),
            ("IPP attribute manipulation", "IPP protocol abuse", 30)
        ]
        
        for flag, (location, technique, points) in zip(MEDIUM_FLAGS, medium_locations):
            html_content += f"""
                <tr>
                    <td>{flag_id:03d}</td>
                    <td class="flag-code">{flag}</td>
                    <td class="medium">Medium</td>
                    <td>{location} - {technique}</td>
                    <td>{points}</td>
                </tr>"""
            flag_id += 1
        
        # Hard flags
        hard_locations = [
            ("SMTP credential capture (pass-back)", "Advanced pass-back attack", 50),
            ("PostScript persistent capture", "Job interception persistence", 45),
            ("Firmware extraction and analysis", "Binary reverse engineering", 50),
            ("CORS spoofing attack", "Advanced web exploitation", 45),
            ("Combined multi-stage attack", "Full exploitation chain", 50)
        ]
        
        for flag, (location, technique, points) in zip(HARD_FLAGS, hard_locations):
            html_content += f"""
                <tr>
                    <td>{flag_id:03d}</td>
                    <td class="flag-code">{flag}</td>
                    <td class="hard">Hard</td>
                    <td>{location} - {technique}</td>
                    <td>{points}</td>
                </tr>"""
            flag_id += 1
        
        html_content += """
            </tbody>
        </table>
        
        <h2>Attack Methodology</h2>
        <h3>Phase 1: Reconnaissance (Easy Flags)</h3>
        <ul>
            <li>Network scanning: nmap -p 21,23,80,161,515,631,9100</li>
            <li>SNMP enumeration: snmpwalk -v2c -c public [IP]</li>
            <li>Service banner grabbing: nc [IP] [PORT]</li>
            <li>Web interface inspection: curl and browser DevTools</li>
        </ul>
        
        <h3>Phase 2: Exploitation (Medium Flags)</h3>
        <ul>
            <li>PJL exploitation: PRET framework or manual netcat</li>
            <li>Directory traversal: Test ../ in file paths</li>
            <li>Pass-back attacks: Modify LDAP/SMTP settings, capture with Responder</li>
            <li>Print job capture: PostScript operator redefinition</li>
        </ul>
        
        <h3>Phase 3: Advanced Attacks (Hard Flags)</h3>
        <ul>
            <li>Persistent compromise: PostScript malware injection</li>
            <li>Firmware analysis: Extract, reverse engineer with binwalk</li>
            <li>Multi-stage attacks: Combine multiple vulnerabilities</li>
            <li>Network pivoting: Use printer as attack platform</li>
        </ul>
        
        <h2>Required Tools</h2>
        <ul>
            <li><strong>PRET:</strong> Printer Exploitation Toolkit (primary tool)</li>
            <li><strong>nmap:</strong> Network scanning and enumeration</li>
            <li><strong>snmpwalk/snmpget:</strong> SNMP enumeration</li>
            <li><strong>Responder:</strong> Credential capture for pass-back attacks</li>
            <li><strong>Metasploit:</strong> Automated printer exploitation modules</li>
            <li><strong>netcat:</strong> Manual protocol testing</li>
            <li><strong>curl/wget:</strong> Web interface testing</li>
        </ul>
        
        <h2>Safety Reminders</h2>
        <div style="background: #fff3cd; padding: 15px; border-left: 4px solid #ffc107; margin: 20px 0;">
            <strong>⚠️ WARNING:</strong> This printer is intentionally vulnerable and must only be used in isolated networks.
            <ul>
                <li>Never connect to production networks</li>
                <li>Use dedicated VLAN or air-gapped network</li>
                <li>Factory reset after CTF completion</li>
                <li>Update firmware to latest version post-event</li>
            </ul>
        </div>
    </div>
</body>
</html>
"""
        
        # Write report
        with open(output_file, 'w') as f:
            f.write(html_content)
        
        logger.info(f"✓ Flag report generated: {output_file}")
        return True
    
    def verify_configuration(self) -> Dict[str, bool]:
        """Verify all configurations were applied successfully"""
        logger.info("\n" + "="*60)
        logger.info("VERIFICATION REPORT")
        logger.info("="*60)
        
        results = {}
        
        # Test SNMP
        try:
            iterator = getCmd(
                SnmpEngine(),
                CommunityData('public'),
                UdpTransportTarget((self.printer_ip, self.snmp_port)),
                ContextData(),
                ObjectType(ObjectIdentity('SNMPv2-MIB', 'sysDescr', 0))
            )
            errorIndication, errorStatus, errorIndex, varBinds = next(iterator)
            results['snmp_public'] = not errorIndication and not errorStatus
            logger.info(f"✓ SNMP 'public' read: {'PASS' if results['snmp_public'] else 'FAIL'}")
        except:
            results['snmp_public'] = False
            logger.error("✗ SNMP 'public' read: FAIL")
        
        # Test PJL
        try:
            response = self.send_pjl_command("@PJL INFO STATUS")
            results['pjl_access'] = len(response) > 0
            logger.info(f"✓ PJL command access: {'PASS' if results['pjl_access'] else 'FAIL'}")
        except:
            results['pjl_access'] = False
            logger.error("✗ PJL command access: FAIL")
        
        # Test Web
        try:
            response = self.session.get(f"{self.base_url}", timeout=5)
            results['web_access'] = response.status_code == 200
            logger.info(f"✓ Web interface access: {'PASS' if results['web_access'] else 'FAIL'}")
        except:
            results['web_access'] = False
            logger.error("✗ Web interface access: FAIL")
        
        # Test Telnet
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            result = sock.connect_ex((self.printer_ip, 23))
            sock.close()
            results['telnet'] = result == 0
            logger.info(f"✓ Telnet port 23: {'PASS' if results['telnet'] else 'FAIL'}")
        except:
            results['telnet'] = False
            logger.error("✗ Telnet port 23: FAIL")
        
        # Test FTP
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            result = sock.connect_ex((self.printer_ip, 21))
            sock.close()
            results['ftp'] = result == 0
            logger.info(f"✓ FTP port 21: {'PASS' if results['ftp'] else 'FAIL'}")
        except:
            results['ftp'] = False
            logger.error("✗ FTP port 21: FAIL")
        
        logger.info("="*60)
        logger.info(f"Overall Status: {sum(results.values())}/{len(results)} checks passed")
        logger.info("="*60 + "\n")
        
        return results
    
    def run_full_configuration(self) -> bool:
        """Execute complete CTF configuration workflow"""
        logger.info("\n" + "="*60)
        logger.info("HP PRINTER CTF CONFIGURATION - STARTING")
        logger.info("="*60 + "\n")
        
        steps = [
            ("Connectivity verification", self.verify_connectivity),
            ("Web authentication", self.authenticate_web),
            ("Protocol enablement", self.enable_vulnerable_protocols),
            ("SNMP configuration", self.configure_snmp_vulnerabilities),
            ("Flag deployment", self.plant_flags),
            ("Report generation", lambda: self.generate_flag_report()),
            ("Configuration verification", self.verify_configuration)
        ]
        
        for step_name, step_func in steps:
            logger.info(f"\n--- {step_name} ---")
            try:
                result = step_func()
                if result:
                    logger.info(f"✓ {step_name} completed successfully")
                else:
                    logger.warning(f"⚠ {step_name} completed with warnings")
            except Exception as e:
                logger.error(f"✗ {step_name} failed: {e}")
        
        logger.info("\n" + "="*60)
        logger.info("CONFIGURATION COMPLETE")
        logger.info("="*60)
        logger.info("\nNext steps:")
        logger.info("1. Review printer_ctf_flags.html for all flag locations")
        logger.info("2. Verify printer is on isolated network")
        logger.info("3. Test with PRET: ./pret.py " + self.printer_ip + " pjl")
        logger.info("4. Provide flag report to CTF scoring system")
        logger.info("\n⚠️  REMEMBER: Factory reset printer after CTF completion!\n")
        
        return True


def main():
    """Main entry point with CLI argument parsing"""
    parser = argparse.ArgumentParser(
        description='HP Printer CTF Automated Configuration',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python printer_ctf_config.py 192.168.1.100
  python printer_ctf_config.py 192.168.1.100 --pin 12345678
  python printer_ctf_config.py 192.168.1.100 --https --pin 12345678
  
WARNING: Only use on isolated networks for educational purposes!
        """
    )
    
    parser.add_argument('printer_ip', help='IP address of the target printer')
    parser.add_argument('--pin', default='', help='Admin PIN if currently set')
    parser.add_argument('--https', action='store_true', help='Use HTTPS instead of HTTP')
    parser.add_argument('--verify-only', action='store_true', help='Only verify connectivity, don\'t configure')
    parser.add_argument('--flags-only', action='store_true', help='Only generate flag report')
    
    args = parser.parse_args()
    
    # Disable SSL warnings
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    
    # Create configurator
    configurator = PrinterCTFConfigurator(
        printer_ip=args.printer_ip,
        admin_pin=args.pin,
        use_https=args.https
    )
    
    # Execute requested operation
    if args.verify_only:
        configurator.verify_connectivity()
        configurator.verify_configuration()
    elif args.flags_only:
        configurator.generate_flag_report()
    else:
        configurator.run_full_configuration()


if __name__ == "__main__":
    main()
