#!/bin/bash
# =============================================================
# monitor.sh — Monitoramento de Serviços do Lab Linux
# Uso: ./monitor.sh [--watch] [--log]
# =============================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

LOG_FILE="/var/log/lab-monitor.log"
WATCH_MODE=false
LOG_MODE=false

# Parse args
for arg in "$@"; do
    case $arg in
        --watch) WATCH_MODE=true ;;
        --log)   LOG_MODE=true ;;
    esac
done

# Detectar qual VM está executando
detect_vm() {
    HOSTNAME=$(hostname)
    case $HOSTNAME in
        vm1*) VM="VM1 — Servidor Principal" ;;
        vm2*) VM="VM2 — Servidor Web"       ;;
        vm3*) VM="VM3 — Proxy/Segurança"    ;;
        *)    VM="Desconhecido ($HOSTNAME)" ;;
    esac
}

# Verificar status de um serviço
check_service() {
    local name=$1
    local service=$2
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo -e "  ${GREEN}✅ $name${NC} (ativo)"
        return 0
    else
        echo -e "  ${RED}❌ $name${NC} (inativo/falhou)"
        return 1
    fi
}

# Verificar porta aberta
check_port() {
    local name=$1
    local port=$2
    local proto=${3:-tcp}
    if ss -tulpn 2>/dev/null | grep -q ":$port "; then
        echo -e "  ${GREEN}✅ Porta $port/$proto${NC} ($name)"
    else
        echo -e "  ${RED}❌ Porta $port/$proto${NC} ($name) — não está escutando"
    fi
}

# Verificar conectividade de rede
check_ping() {
    local host=$1
    local label=$2
    if ping -c 1 -W 1 "$host" &>/dev/null; then
        echo -e "  ${GREEN}✅ $label ($host)${NC}"
    else
        echo -e "  ${RED}❌ $label ($host)${NC} — sem resposta"
    fi
}

# Cabeçalho
print_header() {
    clear
    echo -e "${BOLD}${BLUE}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║         🐧 Lab Linux — Monitor de Serviços           ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${CYAN}  Host:${NC} $VM"
    echo -e "${CYAN}  Data:${NC} $(date '+%d/%m/%Y %H:%M:%S')"
    echo -e "${CYAN}  IP:${NC}   $(hostname -I | awk '{print $1}')"
    echo ""
}

# Seção de serviços por VM
monitor_vm1() {
    echo -e "${BOLD}━━━ Serviços ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    check_service "DNS (Bind9)"         "bind9"
    check_service "DHCP Server"         "isc-dhcp-server"
    check_service "SSH"                 "ssh"
    check_service "Samba (smbd)"        "smbd"
    check_service "Samba (nmbd)"        "nmbd"

    echo ""
    echo -e "${BOLD}━━━ Portas ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    check_port "DNS"   53   "udp"
    check_port "DHCP"  67   "udp"
    check_port "SSH"   2222 "tcp"
    check_port "Samba" 445  "tcp"

    echo ""
    echo -e "${BOLD}━━━ Rede ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    check_ping "192.168.10.2" "VM2 (Web Server)"
    check_ping "192.168.10.3" "VM3 (Proxy)"
    check_ping "8.8.8.8"      "Internet (Google DNS)"

    echo ""
    echo -e "${BOLD}━━━ DHCP Leases Ativos ━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    LEASES=$(grep -c "lease" /var/lib/dhcp/dhcpd.leases 2>/dev/null || echo 0)
    echo -e "  Leases no arquivo: ${YELLOW}$LEASES${NC}"
}

monitor_vm2() {
    echo -e "${BOLD}━━━ Serviços ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    check_service "Apache2"  "apache2"
    check_service "MariaDB"  "mariadb"

    echo ""
    echo -e "${BOLD}━━━ Portas ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    check_port "HTTP"    80   "tcp"
    check_port "MariaDB" 3306 "tcp"

    echo ""
    echo -e "${BOLD}━━━ Rede ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    check_ping "192.168.10.1" "VM1 (Gateway/DNS)"
    check_ping "8.8.8.8"      "Internet"

    echo ""
    echo -e "${BOLD}━━━ Espaço em Disco — Sites ━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [ -d /var/www ]; then
        du -sh /var/www/* 2>/dev/null | while read size dir; do
            echo -e "  ${YELLOW}$size${NC}  $dir"
        done
    fi
}

monitor_vm3() {
    echo -e "${BOLD}━━━ Serviços ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    check_service "Squid Proxy" "squid"

    echo ""
    echo -e "${BOLD}━━━ Portas ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    check_port "Squid" 3128 "tcp"

    echo ""
    echo -e "${BOLD}━━━ Rede ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    check_ping "192.168.10.1" "VM1 (Gateway)"
    check_ping "8.8.8.8"      "Internet"

    echo ""
    echo -e "${BOLD}━━━ Últimos Acessos via Proxy ━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [ -f /var/log/squid/access.log ]; then
        tail -5 /var/log/squid/access.log | awk '{print "  " $1 " - " $7}' 2>/dev/null
    else
        echo -e "  ${YELLOW}Log não encontrado${NC}"
    fi
}

# Recursos do sistema (todas as VMs)
show_resources() {
    echo ""
    echo -e "${BOLD}━━━ Recursos do Sistema ━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # CPU Load
    LOAD=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    echo -e "  CPU Load (1/5/15min): ${YELLOW}$LOAD${NC}"

    # Memória
    MEM_TOTAL=$(free -h | awk '/Mem:/{print $2}')
    MEM_USED=$(free -h | awk '/Mem:/{print $3}')
    MEM_FREE=$(free -h | awk '/Mem:/{print $4}')
    echo -e "  RAM: ${YELLOW}$MEM_USED${NC} usada / $MEM_TOTAL total ($MEM_FREE livre)"

    # Disco
    DISK=$(df -h / | awk 'NR==2{print $3 " usados / " $2 " total (" $5 " cheio)"}')
    echo -e "  Disco (/): ${YELLOW}$DISK${NC}"

    # Uptime
    UPTIME=$(uptime -p)
    echo -e "  Uptime: ${YELLOW}$UPTIME${NC}"
}

# Rodapé
print_footer() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if $WATCH_MODE; then
        echo -e "  ${CYAN}Modo watch ativo — atualizando a cada 5 segundos${NC}"
        echo -e "  ${CYAN}Pressione Ctrl+C para sair${NC}"
    fi
    echo ""
}

# Função de logging
log_status() {
    if $LOG_MODE; then
        {
            echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
            systemctl is-active bind9 isc-dhcp-server ssh smbd apache2 mariadb squid 2>/dev/null
        } >> "$LOG_FILE"
    fi
}

# Loop principal
run_monitor() {
    detect_vm
    print_header

    case $HOSTNAME in
        vm1*) monitor_vm1 ;;
        vm2*) monitor_vm2 ;;
        vm3*) monitor_vm3 ;;
        *)
            # Modo genérico — tenta todos os serviços
            echo -e "${BOLD}━━━ Serviços Detectados ━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            for svc in bind9 isc-dhcp-server ssh smbd apache2 mariadb squid; do
                check_service "$svc" "$svc"
            done
            ;;
    esac

    show_resources
    log_status
    print_footer
}

# Execução
if $WATCH_MODE; then
    while true; do
        run_monitor
        sleep 5
    done
else
    run_monitor
fi
