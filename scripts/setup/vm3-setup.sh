#!/bin/bash
# =============================================================
# setup/vm3-setup.sh — Configuração automática da VM3
# Squid Proxy com cache e filtragem de conteúdo
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
echo "║      Setup VM3 — Proxy / Segurança               ║"
echo "║      Squid Proxy com cache e filtragem           ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

log "Atualizando sistema..."
apt update -qq && apt upgrade -y -qq
apt install -y -qq squid apache2-utils curl nano
success "Squid instalado"

# ──────────────────────────────────────────────────────
# REDE
# ──────────────────────────────────────────────────────
log "Configurando IP estático 192.168.10.3..."

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
        - 192.168.10.3/24
      routes:
        - to: default
          via: 192.168.10.1
      nameservers:
        addresses: [192.168.10.1]
EOF

netplan apply
success "IP 192.168.10.3 configurado"

# ──────────────────────────────────────────────────────
# SQUID
# ──────────────────────────────────────────────────────
log "Configurando Squid..."

mv /etc/squid/squid.conf /etc/squid/squid.conf.original

cat > /etc/squid/blocked-sites.txt << 'EOF'
.facebook.com
.instagram.com
.tiktok.com
.twitter.com
.x.com
EOF

cat > /etc/squid/squid.conf << 'EOF'
# Porta do proxy
http_port 3128

# ACL — Rede local
acl rede_local src 192.168.10.0/24
acl localhost src 127.0.0.1/32

# ACL — Sites bloqueados
acl sites_bloqueados dstdomain "/etc/squid/blocked-sites.txt"

# ACL — Horário comercial (seg-sex 8h-18h)
acl horario_comercial time MTWHF 08:00-18:00

# Regras de acesso
http_access deny sites_bloqueados
http_access allow rede_local
http_access allow localhost
http_access deny all

# Cache
cache_mem 256 MB
maximum_object_size_in_memory 512 KB
cache_dir ufs /var/spool/squid 2048 16 256
maximum_object_size 4 MB
cache_replacement_policy lru

# Logs
access_log /var/log/squid/access.log squid
cache_log /var/log/squid/cache.log

# Ocultar versão do Squid (segurança)
httpd_suppress_version_string on
forwarded_for off
EOF

squid -z 2>/dev/null   # Inicializar diretórios de cache
systemctl restart squid && systemctl enable squid
success "Squid configurado (porta 3128)"

echo ""
echo -e "${BOLD}${GREEN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║       ✅ VM3 configurada com sucesso!            ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║  Proxy: 192.168.10.3:3128                       ║"
echo "║  Sites bloqueados: /etc/squid/blocked-sites.txt ║"
echo "║  Logs: /var/log/squid/access.log                ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"
