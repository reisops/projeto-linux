#!/bin/bash
# =============================================================
# restart-services.sh — Reinicia todos os serviços do Lab
# Uso: sudo ./restart-services.sh [vm1|vm2|vm3|all]
# =============================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

TARGET=${1:-"auto"}

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Execute como root: sudo $0${NC}"
    exit 1
fi

restart_service() {
    local name=$1
    local svc=$2
    printf "  %-25s " "$name"
    if systemctl is-enabled "$svc" &>/dev/null; then
        systemctl restart "$svc" 2>/dev/null
        if systemctl is-active --quiet "$svc"; then
            echo -e "${GREEN}✅ OK${NC}"
        else
            echo -e "${RED}❌ FALHOU${NC}"
            systemctl status "$svc" --no-pager -n 3 2>/dev/null | tail -3 | sed 's/^/    /'
        fi
    else
        echo -e "${YELLOW}⏭  não instalado${NC}"
    fi
}

echo -e "${BOLD}${CYAN}"
echo "╔═════════════════════════════════════════════╗"
echo "║      🔄 Reiniciando Serviços do Lab          ║"
echo "╚═════════════════════════════════════════════╝"
echo -e "${NC}"

HOSTNAME=$(hostname)

case "$TARGET" in
    vm1|"auto")
        if [[ "$TARGET" == "vm1" ]] || [[ "$HOSTNAME" == vm1* ]]; then
            echo -e "${BOLD}━━━ VM1 — Servidor Principal ━━━━━━━━━━━━━━━━━━━${NC}"
            restart_service "DNS (Bind9)"    "bind9"
            restart_service "DHCP Server"   "isc-dhcp-server"
            restart_service "SSH"           "ssh"
            restart_service "Samba (smbd)"  "smbd"
            restart_service "Samba (nmbd)"  "nmbd"

            echo ""
            echo -e "${BOLD}━━━ Reaplicando regras de firewall ━━━━━━━━━━━━━${NC}"
            if [ -f /etc/iptables/rules.sh ]; then
                bash /etc/iptables/rules.sh
                echo -e "  ${GREEN}✅ iptables recarregado${NC}"
            fi
            [[ "$TARGET" == "vm1" ]] && exit 0
        fi
        ;;& # fallthrough para vm2 se auto
    vm2)
        if [[ "$TARGET" == "vm2" ]] || [[ "$HOSTNAME" == vm2* ]]; then
            echo -e "${BOLD}━━━ VM2 — Servidor Web ━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            restart_service "MariaDB"  "mariadb"
            restart_service "Apache2"  "apache2"
            exit 0
        fi
        ;;
    vm3)
        if [[ "$TARGET" == "vm3" ]] || [[ "$HOSTNAME" == vm3* ]]; then
            echo -e "${BOLD}━━━ VM3 — Proxy/Segurança ━━━━━━━━━━━━━━━━━━━━━${NC}"
            restart_service "Squid Proxy" "squid"
            exit 0
        fi
        ;;
    all)
        echo -e "${BOLD}━━━ VM1 — Servidor Principal ━━━━━━━━━━━━━━━━━━━${NC}"
        restart_service "DNS (Bind9)"    "bind9"
        restart_service "DHCP Server"   "isc-dhcp-server"
        restart_service "SSH"           "ssh"
        restart_service "Samba (smbd)"  "smbd"
        restart_service "Samba (nmbd)"  "nmbd"
        echo ""
        echo -e "${BOLD}━━━ VM2 — Servidor Web ━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        restart_service "MariaDB"  "mariadb"
        restart_service "Apache2"  "apache2"
        echo ""
        echo -e "${BOLD}━━━ VM3 — Proxy/Segurança ━━━━━━━━━━━━━━━━━━━━━${NC}"
        restart_service "Squid Proxy" "squid"
        ;;
    *)
        echo "Uso: $0 [vm1|vm2|vm3|all]"
        echo "  Sem argumento: detecta automaticamente pela VM atual"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}${BOLD}✅ Serviços reiniciados!${NC}"
echo -e "   Execute ${CYAN}./monitor.sh${NC} para verificar o status."
echo ""
