# 🔧 TROUBLESHOOTING.md — Common Issues and Solutions

> This document is structured as a production runbook. Each entry follows the format: **Symptom → Diagnosis → Cause → Solution**.

---

## Table of Contents

1. [VirtualBox](#1-virtualbox)
2. [Inter-VM Networking](#2-inter-vm-networking)
3. [DNS (Bind9)](#3-dns-bind9)
4. [DHCP](#4-dhcp)
5. [SSH](#5-ssh)
6. [Samba](#6-samba)
7. [Apache / WordPress](#7-apache--wordpress)
8. [MariaDB](#8-mariadb)
9. [Squid Proxy](#9-squid-proxy)
10. [iptables](#10-iptables)

---

## 1. VirtualBox

### ❌ Error: `vboxconfig` fails with "Secure Boot"

**Symptom:**
```
modprobe: ERROR: could not insert 'vboxdrv': Operation not permitted
```

**Cause:** Secure Boot prevents unsigned kernel modules from loading.

**Solution A — Disable Secure Boot (simplest):**
1. Reboot the machine
2. Enter BIOS/UEFI (usually Del, F2, or F12)
3. Find "Secure Boot" → Disable
4. Save and reboot

**Solution B — Sign the module (keeps Secure Boot active):**
```bash
# Generate a signing key
openssl req -new -x509 -newkey rsa:2048 -keyout MOK.priv \
  -outform DER -out MOK.der -days 36500 -subj "/CN=VirtualBox/"

# Sign the vboxdrv module
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file \
  sha256 MOK.priv MOK.der \
  $(modinfo -n vboxdrv)

# Register the key with MOK manager
sudo mokutil --import MOK.der
# Enter a temporary password when prompted

# Reboot and accept the key in the MOK enrollment screen
reboot
```

---

### ❌ VMs fail to start after a kernel update

**Cause:** VirtualBox kernel modules must be rebuilt for the new kernel version.

**Solution:**
```bash
sudo dnf install -y kernel-devel-$(uname -r) kernel-headers-$(uname -r)
sudo /sbin/vboxconfig
```

---

## 2. Inter-VM Networking

### ❌ VMs cannot ping each other on the internal network

**Diagnosis:**
```bash
ip a                          # Check whether enp0s8 has an IP assigned
ping 192.168.10.1             # Test gateway reachability
ip route                      # Check routing table
```

**Solution 1 — Interface not configured:**
```bash
sudo netplan apply
# If it still fails:
sudo ip link set enp0s8 up
sudo ip addr add 192.168.10.X/24 dev enp0s8
```

**Solution 2 — Interface name differs from expected:**
```bash
ip a
# Note the actual name of the second interface (may be enp0s8, eth1, etc.)
# Update /etc/netplan/00-installer-config.yaml with the correct name
sudo netplan apply
```

**Solution 3 — Internal network names don't match across VMs:**
- Verify that all VMs use exactly the same name under "Internal Network"
- In VirtualBox: Settings → Network → Adapter 2 → Name: `intnet`
- The name is case-sensitive

---

### ❌ VM2 / VM3 have no internet access (NAT is active but outbound traffic fails)

**Check on VM1:**
```bash
# Is ip_forward enabled?
cat /proc/sys/net/ipv4/ip_forward
# Must return 1

# Is the NAT rule present?
sudo iptables -t nat -L POSTROUTING -n -v
# Must show MASQUERADE for enp0s3
```

**Check on VM2 / VM3:**
```bash
# Is the default gateway pointing to VM1?
ip route
# Expected: default via 192.168.10.1

# Is DNS configured correctly?
cat /etc/resolv.conf
# Expected: nameserver 192.168.10.1
```

---

## 3. DNS (Bind9)

### ❌ Bind9 fails to start

**Diagnosis:**
```bash
sudo systemctl status bind9
sudo journalctl -u bind9 -n 50
sudo named-checkconf
sudo named-checkzone lab.local /etc/bind/zones/db.lab.local
```

**Common errors:**

| Error | Cause | Solution |
|---|---|---|
| Zone file fails to load | Syntax error in zone file | Run `named-checkzone` and fix reported line |
| `permission denied` | Incorrect file ownership | `sudo chown -R bind:bind /etc/bind/zones/` |
| `address already in use` | Port 53 already occupied | `sudo ss -tulpn \| grep 53` — identify and stop the conflicting process |

---

### ❌ DNS resolution fails on clients

**Test from the client:**
```bash
dig @192.168.10.1 vm2.lab.local    # Direct query to the DNS server
nslookup vm2.lab.local 192.168.10.1
```

**If it works with `@192.168.10.1` but not without:**
```bash
# Check resolv.conf
cat /etc/resolv.conf
# Must contain: nameserver 192.168.10.1

# On Ubuntu with systemd-resolved:
sudo nano /etc/systemd/resolved.conf
# Add: DNS=192.168.10.1
sudo systemctl restart systemd-resolved
```

---

### ❌ Zone changes are not taking effect (stale serial number)

Always increment the serial number after modifying a zone file:
```
2026070101   →   2026070102   (same day, second change)
2026070101   →   2026070201   (next day)
```

Then reload Bind9:
```bash
sudo systemctl reload bind9
```

---

## 4. DHCP

### ❌ isc-dhcp-server fails to start

```bash
sudo systemctl status isc-dhcp-server
sudo journalctl -u isc-dhcp-server -n 30
```

**Common error — interface not specified:**
```bash
cat /etc/default/isc-dhcp-server
# INTERFACESv4 must contain the correct internal interface name
```

**Common error — subnet does not cover the interface IP:**
```bash
# The interface IP (192.168.10.1) must fall within the declared subnet (192.168.10.0/24)
# Verify dhcpd.conf
```

---

### ❌ Client does not receive an IP from DHCP

```bash
# Monitor DHCP traffic in real time on VM1
sudo tcpdump -i enp0s8 port 67 or port 68

# Check current leases
cat /var/lib/dhcp/dhcpd.leases
```

---

## 5. SSH

### ❌ SSH connection refused

```bash
# Check whether the service is running
sudo systemctl status ssh

# Check which port SSH is listening on
sudo ss -tlpn | grep ssh

# Test with verbose output
ssh -v -i ~/.ssh/lab_key -p 22 admin@192.168.10.1
```

---

### ❌ "Permission denied (publickey)"

```bash
# Fix permissions on the client side
chmod 600 ~/.ssh/lab_key
chmod 700 ~/.ssh/

# Verify authorized_keys on the server
cat ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

---

## 6. Samba

### ❌ Samba shares not visible on the network

```bash
sudo systemctl status smbd nmbd

# Test locally
smbclient -L localhost -N

# Validate smb.conf syntax
testparm
```

---

### ❌ "NT_STATUS_LOGON_FAILURE" when connecting

**Cause:** The user does not have a Samba account, or the Samba password differs from the Linux password.

```bash
# Add or update the Samba password for the user
sudo smbpasswd -a usuario
sudo smbpasswd -e usuario   # enable the account
```

---

### ❌ Permission denied when writing to a share

```bash
# Check share directory permissions
ls -la /srv/samba/

# Fix for public shares
sudo chmod 777 /srv/samba/publico

# Fix for authenticated shares
sudo chown -R usuario:usuario /srv/samba/ti
sudo chmod 770 /srv/samba/ti
```

---

## 7. Apache / WordPress

### ❌ Apache fails to start

```bash
sudo systemctl status apache2
sudo apache2ctl configtest   # Validate configuration syntax

# Check error log
sudo tail -50 /var/log/apache2/error.log
```

**Common error — port 80 already in use:**
```bash
sudo ss -tlpn | grep 80
# If occupied: sudo systemctl stop nginx
```

---

### ❌ WordPress shows "Error establishing a database connection"

```bash
# Test the database connection manually
mysql -u wp_user -p wordpress_db

# Verify credentials in wp-config.php
grep DB_ /var/www/wordpress/public_html/wp-config.php
```

---

### ❌ WordPress cannot upload files (permission error)

```bash
sudo chown -R www-data:www-data /var/www/wordpress
sudo find /var/www/wordpress -type d -exec chmod 755 {} \;
sudo find /var/www/wordpress -type f -exec chmod 644 {} \;
```

---

## 8. MariaDB

### ❌ "Access denied for user"

```bash
sudo mariadb -u root -p
```

```sql
-- List existing users
SELECT user, host FROM mysql.user;

-- Recreate the user if necessary
DROP USER IF EXISTS 'wp_user'@'localhost';
CREATE USER 'wp_user'@'localhost' IDENTIFIED BY 'SenhaForte@2026';
GRANT ALL PRIVILEGES ON wordpress_db.* TO 'wp_user'@'localhost';
FLUSH PRIVILEGES;
```

---

## 9. Squid Proxy

### ❌ Squid fails to start

```bash
sudo systemctl status squid
sudo squid -k check

# Initialize cache directories (required on first run)
sudo squid -z
sudo systemctl restart squid
```

---

### ❌ "Access Denied" for all clients

```bash
# Review ACL order in squid.conf
sudo grep -n "http_access" /etc/squid/squid.conf

# The "allow rede_local" rule MUST appear BEFORE "deny all"
```

---

### ❌ Blocked sites are not being blocked

```bash
# Force Squid to reload its configuration
sudo squid -k reconfigure

# Test from a client with the proxy configured
curl -x http://192.168.10.3:3128 http://facebook.com
# Should return an access denied error

# Monitor the access log
sudo tail -f /var/log/squid/access.log
```

---

## 10. iptables

### ❌ Rules do not persist after reboot

```bash
# Save current rules
sudo iptables-save > /etc/iptables/rules.v4

# Ensure iptables-persistent is installed
sudo apt install -y iptables-persistent

# Reload saved rules
sudo netfilter-persistent reload
```

---

### ❌ NAT not working (VM2/VM3 cannot reach the internet despite the rule being present)

```bash
# Check ip_forward
cat /proc/sys/net/ipv4/ip_forward    # Must be 1

# Enable temporarily
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward

# Make it permanent
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

---

### ❌ View all active rules

```bash
# Filter table
sudo iptables -L -n -v --line-numbers

# NAT table
sudo iptables -t nat -L -n -v

# Flush all rules (caution — will drop SSH if connected remotely)
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
```

---

## Quick Diagnostic Reference

```bash
# Check status of all services at once
for srv in bind9 isc-dhcp-server ssh smbd apache2 mariadb squid; do
    echo "=== $srv ==="
    systemctl is-active $srv
done

# List all open ports and listening processes
sudo ss -tulpn

# Follow system logs in real time
sudo journalctl -f

# Resource usage overview
htop
df -h
free -h
```
