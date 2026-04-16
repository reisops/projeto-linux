# 📦 INSTALL.md — Complete Installation Guide

> Follow this guide from zero: from VirtualBox setup through all services running and validated.

## ⚠️ Networking Note

During development, Adapter 1 was temporarily switched from **NAT** to **Bridged** to resolve connectivity issues.

The lab was later validated, but the documented setup in this guide assumes **NAT + Internal Network**, which is the recommended and more reproducible configuration.

If you experience networking issues, consider testing with Bridged mode for debugging purposes.

---

## Table of Contents

1. [Install VirtualBox on Fedora](#1-install-virtualbox-on-fedora)
2. [Download Ubuntu Server](#2-download-ubuntu-server)
3. [Create the VMs](#3-create-the-vms)
4. [Install Ubuntu Server on Each VM](#4-install-ubuntu-server-on-each-vm)
5. [Initial VM Configuration](#5-initial-vm-configuration)
6. [VM1 — DNS (Bind9)](#6-vm1--dns-bind9)
7. [VM1 — DHCP Server](#7-vm1--dhcp-server)
8. [VM1 — Hardened SSH](#8-vm1--hardened-ssh)
9. [VM1 — Samba File Server](#9-vm1--samba-file-server)
10. [VM1 — iptables Firewall](#10-vm1--iptables-firewall)
11. [VM2 — Apache2 + Virtual Hosts](#11-vm2--apache2--virtual-hosts)
12. [VM2 — MariaDB](#12-vm2--mariadb)
13. [VM2 — WordPress](#13-vm2--wordpress)
14. [VM3 — Squid Proxy](#14-vm3--squid-proxy)
15. [Validation Tests](#15-validation-tests)

---

## 1. Install VirtualBox on Fedora

### 1.1 — Update the system

```bash
sudo dnf update -y
```

### 1.2 — Install kernel build dependencies

```bash
sudo dnf install -y \
  kernel-devel \
  kernel-headers \
  gcc \
  make \
  perl \
  wget \
  elfutils-libelf-devel \
  dkms
```

> ⚠️ **Important:** The `kernel-devel` and `kernel-headers` versions must match the running kernel exactly. Verify with `uname -r`.

### 1.3 — Add Oracle's official repository

```bash
sudo wget https://download.virtualbox.org/virtualbox/rpm/fedora/virtualbox.repo \
  -O /etc/yum.repos.d/virtualbox.repo
```

### 1.4 — Import the GPG key

```bash
sudo rpm --import https://www.virtualbox.org/download/oracle_vbox.asc
```

### 1.5 — Install VirtualBox

```bash
sudo dnf install -y VirtualBox
```

### 1.6 — Add your user to the vboxusers group

```bash
sudo usermod -aG vboxusers $USER
```

### 1.7 — Build kernel modules

```bash
sudo /sbin/vboxconfig
```

Expected output:
```
vboxdrv.sh: Stopping VirtualBox services.
vboxdrv.sh: Starting VirtualBox services.
vboxdrv.sh: Building VirtualBox kernel modules.
```

> ⚠️ **Secure Boot:** If you see a Secure Boot-related error, you have two options:
> - Disable Secure Boot in BIOS/UEFI (simplest)
> - Sign the kernel module manually using `mokutil` (see [TROUBLESHOOTING.md](./TROUBLESHOOTING.md))

### 1.8 — Reboot and verify

```bash
reboot
# After reboot:
virtualbox --version
# Expected output: 7.x.x (or higher)
```

---

## 2. Download Ubuntu Server

Go to: **https://ubuntu.com/download/server**

Download **Ubuntu Server 24.04 LTS (Noble Numbat)** — the `.iso` file is approximately 2.5 GB.

Verify the download integrity:
```bash
sha256sum ubuntu-24.04-live-server-amd64.iso
# Compare the output against the official hash listed on the download page
```

---

## 3. Create the VMs

### VM Configuration Reference

| Setting | VM1 (Core Services) | VM2 (Web Server) | VM3 (Proxy) |
|---|---|---|---|
| Name | `vm1-core` | `vm2-web` | `vm3-proxy` |
| OS | Ubuntu Server 24.04 | Ubuntu Server 24.04 | Ubuntu Server 24.04 |
| RAM | 2048 MB | 2048 MB | 1024 MB |
| CPU | 2 cores | 2 cores | 1 core |
| Disk | 20 GB | 20 GB | 15 GB |
| Network 1 | NAT | NAT | NAT |
| Network 2 | Internal Network (`intnet`) | Internal Network (`intnet`) | Internal Network (`intnet`) |

### Steps to create each VM

1. Open VirtualBox → click **"New"**
2. Fill in the name and select:
   - Type: `Linux`
   - Version: `Ubuntu (64-bit)`
3. Set RAM as specified in the table above
4. Create a virtual hard disk (VDI, dynamically allocated)
5. After creation: select the VM → **Settings → Network**
   - **Adapter 1:** NAT (pre-configured by default)
   - **Adapter 2:** Internal Network → Name: `intnet`
6. Under **Settings → Storage**, attach the Ubuntu ISO to the optical drive
7. Repeat for all 3 VMs

---

## 4. Install Ubuntu Server on Each VM

> Repeat this process on all 3 VMs.

1. Start the VM → select **"Try or Install Ubuntu Server"**
2. Language: **English**
3. Keyboard layout: **Portuguese (Brazil)**
4. Installation type: **Ubuntu Server** (no additional snaps)
5. Network configuration:
   - The installer detects interfaces automatically
   - Leave the NAT interface on DHCP (internet access during installation)
   - The internal network interface will be configured after installation
6. Storage: **Use an entire disk** → confirm
7. Profile setup:
   - VM1: server name `vm1`, username `admin`, strong password
   - VM2: server name `vm2`, username `admin`, strong password
   - VM3: server name `vm3`, username `admin`, strong password
8. **SSH:** select "Install OpenSSH server"
9. Additional snaps: **select nothing** → Continue
10. Wait for installation to complete, then reboot

---

## 5. Initial VM Configuration

> Run on all 3 VMs after installation.

### 5.1 — Update the system

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y net-tools curl wget nano htop
```

### 5.2 — Configure static IPs on the internal network interface

Identify the network interfaces:
```bash
ip a
# Note the interface names: enp0s3 (NAT) and enp0s8 (internal)
```

Edit the Netplan configuration:
```bash
sudo nano /etc/netplan/00-installer-config.yaml
```

**VM1 (Core Services) — `192.168.10.1`:**
```yaml
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: true
    enp0s8:
      dhcp4: false
      addresses:
        - 192.168.10.1/24
```

**VM2 (Web Server) — `192.168.10.2`:**
```yaml
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: true
    enp0s8:
      dhcp4: false
      addresses:
        - 192.168.10.2/24
      routes:
        - to: default
          via: 192.168.10.1
      nameservers:
        addresses: [192.168.10.1]
```

**VM3 (Proxy) — `192.168.10.3`:**
```yaml
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: true
    enp0s8:
      dhcp4: false
      addresses:
        - 192.168.10.3/24
      routes:
        - to: default
          via: 192.168.10.1
      nameservers:
        addresses: [192.168.10.1]
```

Apply the configuration:
```bash
sudo netplan apply
```

Verify:
```bash
ip a
ping 192.168.10.1   # From VM2 or VM3 — should respond
```

---

## 6. VM1 — DNS (Bind9)

### 6.1 — Install

```bash
sudo apt install -y bind9 bind9utils dnsutils
```

### 6.2 — Configure global options

```bash
sudo nano /etc/bind/named.conf.options
```

```
options {
    directory "/var/cache/bind";

    recursion yes;
    allow-query { any; };
    allow-recursion { 192.168.10.0/24; localhost; };

    forwarders {
        8.8.8.8;
        8.8.4.4;
    };

    dnssec-validation auto;
    listen-on { 192.168.10.1; 127.0.0.1; };
    listen-on-v6 { none; };
};
```

### 6.3 — Declare the zones

```bash
sudo nano /etc/bind/named.conf.local
```

```
# Forward zone
zone "lab.local" {
    type master;
    file "/etc/bind/zones/db.lab.local";
};

# Reverse zone
zone "10.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/db.192.168.10";
};
```

### 6.4 — Create zone files

```bash
sudo mkdir /etc/bind/zones
```

**Forward zone:**
```bash
sudo nano /etc/bind/zones/db.lab.local
```

```
$TTL    604800
@   IN  SOA ns1.lab.local. admin.lab.local. (
            2026070101  ; Serial (YYYYMMDDXX)
            3600        ; Refresh
            1800        ; Retry
            604800      ; Expire
            86400 )     ; Negative Cache TTL

; Name servers
@       IN  NS      ns1.lab.local.

; A Records
ns1     IN  A       192.168.10.1
vm1     IN  A       192.168.10.1
vm2     IN  A       192.168.10.2
vm3     IN  A       192.168.10.3

; Aliases (CNAME)
www     IN  CNAME   vm2
proxy   IN  CNAME   vm3

; MX Record
@       IN  MX  10  mail.lab.local.
mail    IN  A       192.168.10.2
```

**Reverse zone:**
```bash
sudo nano /etc/bind/zones/db.192.168.10
```

```
$TTL    604800
@   IN  SOA ns1.lab.local. admin.lab.local. (
            2026070101
            3600
            1800
            604800
            86400 )

@   IN  NS  ns1.lab.local.

; PTR Records (IP → hostname)
1   IN  PTR vm1.lab.local.
2   IN  PTR vm2.lab.local.
3   IN  PTR vm3.lab.local.
```

### 6.5 — Validate and start

```bash
# Validate syntax
sudo named-checkconf
sudo named-checkzone lab.local /etc/bind/zones/db.lab.local
sudo named-checkzone 10.168.192.in-addr.arpa /etc/bind/zones/db.192.168.10

# Start and enable
sudo systemctl restart bind9
sudo systemctl enable bind9
sudo systemctl status bind9
```

### 6.6 — Test

```bash
dig @192.168.10.1 vm2.lab.local
dig @192.168.10.1 -x 192.168.10.2
nslookup vm2.lab.local 192.168.10.1
```

---

## 7. VM1 — DHCP Server

### 7.1 — Install

```bash
sudo apt install -y isc-dhcp-server
```

### 7.2 — Bind to the internal network interface

```bash
sudo nano /etc/default/isc-dhcp-server
```

```
INTERFACESv4="enp0s8"
INTERFACESv6=""
```

### 7.3 — Configure the DHCP server

```bash
sudo nano /etc/dhcp/dhcpd.conf
```

```
# Global settings
default-lease-time 600;
max-lease-time 7200;
authoritative;

# DNS integration
option domain-name "lab.local";
option domain-name-servers 192.168.10.1;

# Internal network subnet
subnet 192.168.10.0 netmask 255.255.255.0 {
    range 192.168.10.100 192.168.10.200;
    option routers 192.168.10.1;
    option broadcast-address 192.168.10.255;
}

# Static reservation (MAC → fixed IP)
host workstation-01 {
    hardware ethernet 08:00:27:AA:BB:CC;   # replace with actual MAC
    fixed-address 192.168.10.50;
}
```

### 7.4 — Start and enable

```bash
sudo systemctl restart isc-dhcp-server
sudo systemctl enable isc-dhcp-server
sudo systemctl status isc-dhcp-server
```

### 7.5 — Monitor active leases

```bash
cat /var/lib/dhcp/dhcpd.leases
```

---

## 8. VM1 — Hardened SSH

### 8.1 — Generate an Ed25519 key pair (on the Fedora host)

```bash
ssh-keygen -t ed25519 -C "portfolio-lab" -f ~/.ssh/lab_key
```

### 8.2 — Copy the public key to VM1

```bash
ssh-copy-id -i ~/.ssh/lab_key.pub admin@192.168.10.1
```

### 8.3 — Harden sshd_config

```bash
sudo nano /etc/ssh/sshd_config
```

Set or confirm the following directives:
```
Port 22
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
AllowUsers admin
```

### 8.4 — Restart SSH

```bash
sudo systemctl restart ssh
```

### 8.5 — Test (from the Fedora host)

```bash
ssh -i ~/.ssh/lab_key admin@192.168.10.1
```

---

## 9. VM1 — Samba File Server

### 9.1 — Install

```bash
sudo apt install -y samba smbclient cifs-utils
```

### 9.2 — Create share directories

```bash
sudo mkdir -p /srv/samba/{publico,ti,financeiro,lixeira}
sudo chmod 777 /srv/samba/publico
sudo chmod 770 /srv/samba/ti
sudo chmod 770 /srv/samba/financeiro
sudo chmod 777 /srv/samba/lixeira
```

### 9.3 — Create Samba users

```bash
sudo adduser joao --no-create-home --disabled-password
sudo adduser maria --no-create-home --disabled-password
sudo smbpasswd -a joao
sudo smbpasswd -a maria
sudo smbpasswd -e joao
sudo smbpasswd -e maria
```

### 9.4 — Configure smb.conf

```bash
sudo mv /etc/samba/smb.conf /etc/samba/smb.conf.original
sudo nano /etc/samba/smb.conf
```

```ini
[global]
   workgroup = LAB
   server string = LAB File Server
   security = user
   map to guest = bad user
   dns proxy = no
   log file = /var/log/samba/log.%m
   max log size = 1000

   # Global recycle bin
   vfs objects = recycle
   recycle:repository = /srv/samba/lixeira/%U
   recycle:keeptree = yes
   recycle:versions = yes

[publico]
   comment = Public Share
   path = /srv/samba/publico
   guest ok = yes
   browseable = yes
   writable = yes

[ti]
   comment = IT Department
   path = /srv/samba/ti
   valid users = joao maria
   browseable = yes
   writable = yes
   create mask = 0660
   directory mask = 0770

[financeiro]
   comment = Finance — Read-only for IT
   path = /srv/samba/financeiro
   valid users = maria
   read list = joao
   writable = yes
   browseable = no

   # Block executables and media files
   veto files = /*.exe/*.mp3/*.mp4/*.avi/
```

### 9.5 — Start and enable

```bash
sudo systemctl restart smbd nmbd
sudo systemctl enable smbd nmbd
```

### 9.6 — Test

```bash
smbclient //192.168.10.1/publico -N
smbclient //192.168.10.1/ti -U joao
```

---

## 10. VM1 — iptables Firewall

### 10.1 — Install iptables-persistent

```bash
sudo apt install -y iptables-persistent
```

### 10.2 — Create the firewall rules script

```bash
sudo nano /etc/iptables/rules.sh
```

```bash
#!/bin/bash

# Flush existing rules
iptables -F
iptables -X
iptables -t nat -F

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT

# Allow established and related connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# SSH
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# DNS
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -j ACCEPT

# DHCP
iptables -A INPUT -p udp --dport 67 -j ACCEPT

# Samba
iptables -A INPUT -p tcp --dport 445 -j ACCEPT
iptables -A INPUT -p tcp --dport 139 -j ACCEPT
iptables -A INPUT -p udp --dport 137:138 -j ACCEPT

# ICMP (ping)
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# NAT — share internet access with the internal network
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE

# FORWARD — allow traffic between interfaces
iptables -A FORWARD -i enp0s8 -o enp0s3 -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Block external access to MariaDB
iptables -A INPUT -p tcp --dport 3306 -j DROP

# Save rules
iptables-save > /etc/iptables/rules.v4
echo "Firewall rules applied successfully."
```

```bash
sudo chmod +x /etc/iptables/rules.sh
sudo bash /etc/iptables/rules.sh
```

### 10.3 — Enable IP forwarding permanently

```bash
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

---

## 11. VM2 — Apache2 + Virtual Hosts

### 11.1 — Install

```bash
sudo apt install -y apache2 php libapache2-mod-php \
  php-mysql php-curl php-gd php-mbstring \
  php-xml php-xmlrpc php-soap php-intl php-zip
```

### 11.2 — Create site directories

```bash
sudo mkdir -p /var/www/{site1,wordpress}/public_html
```

**Test page:**
```bash
sudo nano /var/www/site1/public_html/index.html
```

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Linux Lab — Site 1</title>
</head>
<body>
    <h1>🐧 Apache is Running!</h1>
    <p>VM2 — Web Server — Linux Infrastructure Lab</p>
</body>
</html>
```

### 11.3 — Create virtual host

```bash
sudo nano /etc/apache2/sites-available/site1.conf
```

```apache
<VirtualHost *:80>
    ServerName site1.lab.local
    ServerAlias www.site1.lab.local
    DocumentRoot /var/www/site1/public_html

    <Directory /var/www/site1/public_html>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/site1-error.log
    CustomLog ${APACHE_LOG_DIR}/site1-access.log combined
</VirtualHost>
```

```bash
sudo a2ensite site1.conf
sudo a2enmod rewrite
sudo a2dissite 000-default.conf
sudo systemctl reload apache2
```

---

## 12. VM2 — MariaDB

### 12.1 — Install

```bash
sudo apt install -y mariadb-server
```

### 12.2 — Run the secure installation wizard

```bash
sudo mysql_secure_installation
# Recommended: Y, set root password, Y, Y, Y, Y
```

### 12.3 — Create the WordPress database

```bash
sudo mariadb -u root -p
```

```sql
CREATE DATABASE wordpress_db DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'wp_user'@'localhost' IDENTIFIED BY 'SenhaForte@2026';
GRANT ALL PRIVILEGES ON wordpress_db.* TO 'wp_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

---

## 13. VM2 — WordPress

### 13.1 — Download WordPress

```bash
cd /tmp
wget https://wordpress.org/latest.tar.gz
tar xzvf latest.tar.gz
sudo cp -r wordpress/. /var/www/wordpress/public_html/
```

### 13.2 — Set correct ownership and permissions

```bash
sudo chown -R www-data:www-data /var/www/wordpress
sudo find /var/www/wordpress -type d -exec chmod 750 {} \;
sudo find /var/www/wordpress -type f -exec chmod 640 {} \;
```

### 13.3 — Configure wp-config.php

```bash
sudo cp /var/www/wordpress/public_html/wp-config-sample.php \
        /var/www/wordpress/public_html/wp-config.php
sudo nano /var/www/wordpress/public_html/wp-config.php
```

Update the following lines:
```php
define( 'DB_NAME', 'wordpress_db' );
define( 'DB_USER', 'wp_user' );
define( 'DB_PASSWORD', 'SenhaForte@2026' );
define( 'DB_HOST', 'localhost' );
define( 'FS_METHOD', 'direct' );
```

### 13.4 — Create the WordPress virtual host

```bash
sudo nano /etc/apache2/sites-available/wordpress.conf
```

```apache
<VirtualHost *:80>
    ServerName wordpress.lab.local
    DocumentRoot /var/www/wordpress/public_html

    <Directory /var/www/wordpress/public_html>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/wordpress-error.log
    CustomLog ${APACHE_LOG_DIR}/wordpress-access.log combined
</VirtualHost>
```

```bash
sudo a2ensite wordpress.conf
sudo systemctl reload apache2
```

Navigate to `http://192.168.10.2` from any VM on the internal network and complete the WordPress installation wizard.

---

## 14. VM3 — Squid Proxy

### 14.1 — Install

```bash
sudo apt install -y squid apache2-utils
```

### 14.2 — Configure Squid

```bash
sudo mv /etc/squid/squid.conf /etc/squid/squid.conf.original
sudo nano /etc/squid/squid.conf
```

```
# Listening port
http_port 3128

# Allow internal network
acl rede_local src 192.168.10.0/24
http_access allow rede_local

# Block listed sites
acl sites_bloqueados dstdomain "/etc/squid/blocked-sites.txt"
http_access deny sites_bloqueados

# Deny everything else
http_access deny all

# Cache settings
cache_mem 256 MB
maximum_object_size_in_memory 512 KB
cache_dir ufs /var/spool/squid 2048 16 256

# Logging
access_log /var/log/squid/access.log
```

**Create the blocklist:**
```bash
sudo nano /etc/squid/blocked-sites.txt
```

```
.facebook.com
.tiktok.com
.youtube.com
```

### 14.3 — Initialize cache and start

```bash
sudo squid -z   # Initialize cache directories (required on first run)
sudo systemctl restart squid
sudo systemctl enable squid
```

### 14.4 — Configure clients to use the proxy

Point HTTP clients in the internal network to:
- **Address:** `192.168.10.3`
- **Port:** `3128`

---

## 15. Validation Tests

Run these tests to confirm the full environment is functional:

```bash
# DNS — forward and reverse resolution
dig @192.168.10.1 vm2.lab.local
dig @192.168.10.1 -x 192.168.10.2

# DHCP — verify active leases
cat /var/lib/dhcp/dhcpd.leases

# SSH — key-based login
ssh -i ~/.ssh/lab_key admin@192.168.10.1

# Samba — anonymous and authenticated access
smbclient //192.168.10.1/publico -N
smbclient //192.168.10.1/ti -U joao

# Apache — HTTP response from internal network
curl http://192.168.10.2

# MariaDB — database and table visibility
mysql -u wp_user -p wordpress_db -e "SHOW TABLES;"

# Squid — proxied HTTP request
curl -x http://192.168.10.3:3128 http://example.com

# iptables — current ruleset
iptables -L -n -v

# Inter-VM connectivity
ping 192.168.10.2   # From VM1
ping 192.168.10.1   # From VM2
```

---

> ✅ If all tests pass, the infrastructure is fully operational.
