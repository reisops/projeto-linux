#!/bin/bash
# =============================================================
# setup/vm2-setup.sh — Configuração automática da VM2
# Apache2 · MariaDB · WordPress
# =============================================================

set -e
RED='\033[0;31m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
log()     { echo -e "${CYAN}[$(date '+%H:%M:%S')] $1${NC}"; }
success() { echo -e "${GREEN}[✅] $1${NC}"; }
die()     { echo -e "${RED}[❌] $1${NC}"; exit 1; }

[[ $EUID -ne 0 ]] && die "Execute como root: sudo $0"

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║      Setup VM2 — Servidor Web                    ║"
echo "║      Apache · MariaDB · WordPress                ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

# ──────────────────────────────────────────────────────
# 1. SISTEMA
# ──────────────────────────────────────────────────────
log "Atualizando sistema e instalando pacotes..."
apt update -qq && apt upgrade -y -qq
apt install -y -qq \
  apache2 \
  mariadb-server \
  php libapache2-mod-php \
  php-mysql php-curl php-gd php-mbstring \
  php-xml php-xmlrpc php-soap php-intl php-zip \
  wget curl nano
success "Pacotes instalados"

# ──────────────────────────────────────────────────────
# 2. REDE — IP estático
# ──────────────────────────────────────────────────────
log "Configurando IP estático 192.168.10.2..."

IFACE_NAT=$(ip route | grep default | awk '{print $5}' | head -1)
IFACE_INT=$(ip link show | grep -v lo | grep -v "$IFACE_NAT" \
            | awk '{print $2}' | tr -d ':' | grep -v "^$" | head -1)
[[ -z "$IFACE_INT" ]] && IFACE_INT="enp0s8"

cat > /etc/netplan/00-installer-config.yaml << EOF
network:
  version: 2
  ethernets:
    ${IFACE_NAT}:
      dhcp4: true
    ${IFACE_INT}:
      dhcp4: false
      addresses:
        - 192.168.10.2/24
      routes:
        - to: default
          via: 192.168.10.1
      nameservers:
        addresses: [192.168.10.1]
EOF

netplan apply
success "IP 192.168.10.2 configurado"

# ──────────────────────────────────────────────────────
# 3. MARIADB
# ──────────────────────────────────────────────────────
log "Configurando MariaDB..."

systemctl start mariadb && systemctl enable mariadb

# Configuração de segurança automatizada
mysql -u root << 'SQLEOF'
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
CREATE DATABASE IF NOT EXISTS wordpress_db DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'wp_user'@'localhost' IDENTIFIED BY 'WpSenha@Lab2026';
GRANT ALL PRIVILEGES ON wordpress_db.* TO 'wp_user'@'localhost';
FLUSH PRIVILEGES;
SQLEOF

success "MariaDB configurado (banco wordpress_db criado)"

# ──────────────────────────────────────────────────────
# 4. APACHE — Site de demonstração
# ──────────────────────────────────────────────────────
log "Configurando Apache2..."

a2enmod rewrite
a2dissite 000-default.conf 2>/dev/null || true

mkdir -p /var/www/site1/public_html

cat > /var/www/site1/public_html/index.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Lab Linux — VM2 Web Server</title>
    <style>
        body { font-family: monospace; background: #0d1117; color: #58a6ff;
               display: flex; align-items: center; justify-content: center;
               height: 100vh; margin: 0; }
        .box { border: 1px solid #30363d; padding: 2rem; text-align: center; }
        h1 { color: #3fb950; }
        p { color: #8b949e; }
    </style>
</head>
<body>
    <div class="box">
        <h1>🐧 Apache Funcionando!</h1>
        <p>VM2 — Servidor Web do Lab Linux</p>
        <p>IP: 192.168.10.2</p>
    </div>
</body>
</html>
EOF

cat > /etc/apache2/sites-available/site1.conf << 'EOF'
<VirtualHost *:80>
    ServerName site1.lab.local
    DocumentRoot /var/www/site1/public_html
    <Directory /var/www/site1/public_html>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/site1-error.log
    CustomLog ${APACHE_LOG_DIR}/site1-access.log combined
</VirtualHost>
EOF

a2ensite site1.conf
success "Site de demonstração configurado"

# ──────────────────────────────────────────────────────
# 5. WORDPRESS
# ──────────────────────────────────────────────────────
log "Instalando WordPress..."

cd /tmp
wget -q https://wordpress.org/latest.tar.gz
tar xzf latest.tar.gz

mkdir -p /var/www/wordpress/public_html
cp -r wordpress/. /var/www/wordpress/public_html/

cp /var/www/wordpress/public_html/wp-config-sample.php \
   /var/www/wordpress/public_html/wp-config.php

# Substituir credenciais no wp-config
sed -i "s/database_name_here/wordpress_db/" /var/www/wordpress/public_html/wp-config.php
sed -i "s/username_here/wp_user/"            /var/www/wordpress/public_html/wp-config.php
sed -i "s/password_here/WpSenha@Lab2026/"    /var/www/wordpress/public_html/wp-config.php
echo "define('FS_METHOD', 'direct');" >> /var/www/wordpress/public_html/wp-config.php

chown -R www-data:www-data /var/www/
find /var/www/wordpress -type d -exec chmod 750 {} \;
find /var/www/wordpress -type f -exec chmod 640 {} \;

cat > /etc/apache2/sites-available/wordpress.conf << 'EOF'
<VirtualHost *:80>
    ServerName wordpress.lab.local
    DocumentRoot /var/www/wordpress/public_html
    <Directory /var/www/wordpress/public_html>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/wp-error.log
    CustomLog ${APACHE_LOG_DIR}/wp-access.log combined
</VirtualHost>
EOF

a2ensite wordpress.conf
systemctl restart apache2 && systemctl enable apache2
success "WordPress instalado — conclua via navegador em http://192.168.10.2"

echo ""
echo -e "${BOLD}${GREEN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║       ✅ VM2 configurada com sucesso!            ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║  Apache: http://192.168.10.2                    ║"
echo "║  WordPress: http://wordpress.lab.local          ║"
echo "║  DB User: wp_user / WpSenha@Lab2026             ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"
