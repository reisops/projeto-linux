#!/bin/bash
# =============================================================
# setup/vm1-setup.sh — Configuração automática da VM1
# Execute como root após instalar Ubuntu Server
# =============================================================

set -e  # Parar em qualquer erro

RED='\033[0;31m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()     { echo -e "${CYAN}[$(date '+%H:%M:%S')] $1${NC}"; }
success() { echo -e "${GREEN}[✅] $1${NC}"; }
die()     { echo -e "${RED}[❌] ERRO: $1${NC}"; exit 1; }

[[ $EUID -ne 0 ]] && die "Execute como root: sudo $0"

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║      Setup VM1 — Servidor Principal              ║"
echo "║      DNS · DHCP · SSH · Samba · Firewall         ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

# ──────────────────────────────────────────────────────
# 1. SISTEMA BASE
# ──────────────────────────────────────────────────────
log "Atualizando sistema..."
apt update -qq && apt upgrade -y -qq
apt install -y -qq net-tools curl wget nano htop \
  bind9 bind9utils dnsutils \
  isc-dhcp-server \
  samba smbclient cifs-utils \
  iptables iptables-persistent
success "Pacotes instalados"

# ──────────────────────────────────────────────────────
# 2. REDE — IP estático na interface interna
# ──────────────────────────────────────────────────────
log "Configurando rede..."

# Detectar interface interna (segunda interface)
IFACE_NAT=$(ip route | grep default | awk '{print $5}' | head -1)
IFACE_INT=$(ip link show | grep -v lo | grep -v "$IFACE_NAT" \
            | grep "state UP\|state DOWN" | awk '{print $2}' \
            | tr -d ':' | head -1)

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
        - 192.168.10.1/24
EOF

netplan apply
success "IP 192.168.10.1 configurado em $IFACE_INT"

# ──────────────────────────────────────────────────────
# 3. DNS — Bind9
# ──────────────────────────────────────────────────────
log "Configurando DNS (Bind9)..."

cat > /etc/bind/named.conf.options << 'EOF'
options {
    directory "/var/cache/bind";
    recursion yes;
    allow-query { any; };
    allow-recursion { 192.168.10.0/24; localhost; };
    forwarders { 8.8.8.8; 8.8.4.4; };
    dnssec-validation auto;
    listen-on { 192.168.10.1; 127.0.0.1; };
    listen-on-v6 { none; };
};
EOF

cat > /etc/bind/named.conf.local << 'EOF'
zone "lab.local" {
    type master;
    file "/etc/bind/zones/db.lab.local";
};
zone "10.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/db.192.168.10";
};
EOF

mkdir -p /etc/bind/zones

cat > /etc/bind/zones/db.lab.local << 'EOF'
$TTL    604800
@   IN  SOA ns1.lab.local. admin.lab.local. (
            2026070101 3600 1800 604800 86400 )
@   IN  NS  ns1.lab.local.
ns1 IN  A   192.168.10.1
vm1 IN  A   192.168.10.1
vm2 IN  A   192.168.10.2
vm3 IN  A   192.168.10.3
www IN  CNAME vm2
proxy IN CNAME vm3
EOF

cat > /etc/bind/zones/db.192.168.10 << 'EOF'
$TTL    604800
@   IN  SOA ns1.lab.local. admin.lab.local. (
            2026070101 3600 1800 604800 86400 )
@   IN  NS  ns1.lab.local.
1   IN  PTR vm1.lab.local.
2   IN  PTR vm2.lab.local.
3   IN  PTR vm3.lab.local.
EOF

chown -R bind:bind /etc/bind/zones
named-checkconf && named-checkzone lab.local /etc/bind/zones/db.lab.local
systemctl restart bind9 && systemctl enable bind9
success "DNS configurado e ativo"

# ──────────────────────────────────────────────────────
# 4. DHCP
# ──────────────────────────────────────────────────────
log "Configurando DHCP..."

sed -i "s/INTERFACESv4=\"\"/INTERFACESv4=\"${IFACE_INT}\"/" \
    /etc/default/isc-dhcp-server

cat > /etc/dhcp/dhcpd.conf << 'EOF'
default-lease-time 600;
max-lease-time 7200;
authoritative;
option domain-name "lab.local";
option domain-name-servers 192.168.10.1;

subnet 192.168.10.0 netmask 255.255.255.0 {
    range 192.168.10.100 192.168.10.200;
    option routers 192.168.10.1;
    option broadcast-address 192.168.10.255;
}
EOF

systemctl restart isc-dhcp-server && systemctl enable isc-dhcp-server
success "DHCP configurado e ativo"

# ──────────────────────────────────────────────────────
# 5. SAMBA
# ──────────────────────────────────────────────────────
log "Configurando Samba..."

mkdir -p /srv/samba/{publico,ti,lixeira}
chmod 777 /srv/samba/publico /srv/samba/lixeira
chmod 770 /srv/samba/ti

mv /etc/samba/smb.conf /etc/samba/smb.conf.original 2>/dev/null || true

cat > /etc/samba/smb.conf << 'EOF'
[global]
   workgroup = LAB
   server string = Servidor de Arquivos
   security = user
   map to guest = bad user
   vfs objects = recycle
   recycle:repository = /srv/samba/lixeira/%U
   recycle:keeptree = yes
   recycle:versions = yes

[publico]
   path = /srv/samba/publico
   guest ok = yes
   browseable = yes
   writable = yes

[ti]
   path = /srv/samba/ti
   valid users = admin
   browseable = yes
   writable = yes
EOF

systemctl restart smbd nmbd && systemctl enable smbd nmbd
success "Samba configurado e ativo"

# ──────────────────────────────────────────────────────
# 6. IPTABLES / NAT
# ──────────────────────────────────────────────────────
log "Configurando Firewall + NAT..."

echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p -q

cat > /etc/iptables/rules.sh << EOF
#!/bin/bash
iptables -F
iptables -X
iptables -t nat -F
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 2222 -j ACCEPT
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --dport 67 -j ACCEPT
iptables -A INPUT -p tcp --dport 445 -j ACCEPT
iptables -A INPUT -p tcp --dport 139 -j ACCEPT
iptables -A INPUT -p udp --dport 137:138 -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -o ${IFACE_NAT} -j MASQUERADE
iptables -A FORWARD -i ${IFACE_INT} -o ${IFACE_NAT} -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables-save > /etc/iptables/rules.v4
EOF

chmod +x /etc/iptables/rules.sh
bash /etc/iptables/rules.sh
success "Firewall configurado com NAT ativo"

# ──────────────────────────────────────────────────────
# 7. SSH HARDENING
# ──────────────────────────────────────────────────────
log "Endurecendo SSH..."

sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
sed -i 's/X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config

systemctl restart ssh && systemctl enable ssh
success "SSH hardened (porta 2222)"

# ──────────────────────────────────────────────────────
# CONCLUÍDO
# ──────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║       ✅ VM1 configurada com sucesso!            ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║  DNS:   192.168.10.1:53                         ║"
echo "║  DHCP:  192.168.10.100-200                      ║"
echo "║  Samba: \\\\192.168.10.1\\publico               ║"
echo "║  SSH:   porta 2222                              ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"
