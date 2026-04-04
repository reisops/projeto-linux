#!/bin/bash
# =============================================================
# backup.sh — Backup Automatizado do Lab Linux
# Uso: sudo ./backup.sh
# Cron: 0 2 * * * /opt/scripts/backup.sh >> /var/log/backup.log 2>&1
# =============================================================

# Configurações
BACKUP_DIR="/opt/backups"
RETENTION_DAYS=7
DATE=$(date '+%Y-%m-%d_%H-%M')
HOSTNAME=$(hostname)
BACKUP_NAME="${HOSTNAME}_${DATE}"

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

# Verificar root
if [[ $EUID -ne 0 ]]; then
    error "Execute como root: sudo $0"
    exit 1
fi

# Criar diretório de backup
mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}"
log "Iniciando backup: ${BACKUP_NAME}"
echo ""

# Função genérica de backup de diretório
backup_dir() {
    local src=$1
    local name=$2
    if [ -d "$src" ]; then
        tar -czf "${BACKUP_DIR}/${BACKUP_NAME}/${name}.tar.gz" "$src" 2>/dev/null
        SIZE=$(du -sh "${BACKUP_DIR}/${BACKUP_NAME}/${name}.tar.gz" | cut -f1)
        success "Backup de $src → ${name}.tar.gz (${SIZE})"
    else
        warn "Diretório não encontrado, pulando: $src"
    fi
}

# ==============================================================
# CONFIGS — Todos os arquivos de configuração
# ==============================================================
log "📁 Fazendo backup das configurações..."

backup_dir "/etc/bind"    "bind_config"
backup_dir "/etc/dhcp"    "dhcp_config"
backup_dir "/etc/samba"   "samba_config"
backup_dir "/etc/apache2" "apache_config"
backup_dir "/etc/squid"   "squid_config"
backup_dir "/etc/ssh"     "ssh_config"
backup_dir "/etc/iptables" "iptables_config"
backup_dir "/etc/netplan" "netplan_config"

# ==============================================================
# DADOS — Compartilhamentos Samba
# ==============================================================
log "📂 Fazendo backup dos dados do Samba..."
backup_dir "/srv/samba" "samba_data"

# ==============================================================
# WEB — Sites Apache / WordPress
# ==============================================================
log "🌐 Fazendo backup dos sites web..."
backup_dir "/var/www" "web_sites"

# ==============================================================
# BANCO DE DADOS — MariaDB
# ==============================================================
log "🗄️  Fazendo backup do banco de dados..."

if systemctl is-active --quiet mariadb 2>/dev/null; then
    # Dump de todos os bancos
    mysqldump --all-databases \
              --single-transaction \
              --routines \
              --triggers \
              -u root 2>/dev/null \
    | gzip > "${BACKUP_DIR}/${BACKUP_NAME}/mariadb_all.sql.gz"

    if [ $? -eq 0 ]; then
        SIZE=$(du -sh "${BACKUP_DIR}/${BACKUP_NAME}/mariadb_all.sql.gz" | cut -f1)
        success "Dump MariaDB completo (${SIZE})"
    else
        warn "MariaDB dump falhou — verifique autenticação"
        # Tentar apenas wordpress_db
        mysqldump wordpress_db 2>/dev/null \
        | gzip > "${BACKUP_DIR}/${BACKUP_NAME}/wordpress_db.sql.gz" \
        && success "Dump parcial (wordpress_db)"
    fi
else
    warn "MariaDB não encontrado ou não está rodando nesta VM — pulando dump"
fi

# ==============================================================
# LEASES DHCP
# ==============================================================
log "📋 Fazendo backup dos leases DHCP..."
if [ -f /var/lib/dhcp/dhcpd.leases ]; then
    cp /var/lib/dhcp/dhcpd.leases "${BACKUP_DIR}/${BACKUP_NAME}/dhcpd.leases"
    success "Leases DHCP copiados"
fi

# ==============================================================
# LOGS (últimas 1000 linhas de cada)
# ==============================================================
log "📜 Salvando logs recentes..."

mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/logs"

declare -A LOGS=(
    ["syslog"]="/var/log/syslog"
    ["auth"]="/var/log/auth.log"
    ["apache_access"]="/var/log/apache2/access.log"
    ["apache_error"]="/var/log/apache2/error.log"
    ["squid_access"]="/var/log/squid/access.log"
    ["samba"]="/var/log/samba/log.smbd"
)

for name in "${!LOGS[@]}"; do
    logfile="${LOGS[$name]}"
    if [ -f "$logfile" ]; then
        tail -1000 "$logfile" > "${BACKUP_DIR}/${BACKUP_NAME}/logs/${name}.log"
        success "Log salvo: $name"
    fi
done

# ==============================================================
# COMPACTAR TUDO
# ==============================================================
log "🗜️  Compactando backup completo..."

cd "$BACKUP_DIR"
tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}/" 2>/dev/null
TOTAL_SIZE=$(du -sh "${BACKUP_NAME}.tar.gz" | cut -f1)
success "Backup final: ${BACKUP_NAME}.tar.gz (${TOTAL_SIZE})"

# Remover diretório temporário
rm -rf "${BACKUP_DIR}/${BACKUP_NAME}"

# ==============================================================
# LIMPEZA — Remover backups antigos
# ==============================================================
log "🧹 Removendo backups com mais de ${RETENTION_DAYS} dias..."
DELETED=$(find "$BACKUP_DIR" -name "*.tar.gz" -mtime +${RETENTION_DAYS} -delete -print | wc -l)
if [ "$DELETED" -gt 0 ]; then
    success "$DELETED backup(s) antigo(s) removido(s)"
fi

# ==============================================================
# RELATÓRIO FINAL
# ==============================================================
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}✅ Backup concluído com sucesso!${NC}"
echo ""
echo -e "  Arquivo: ${CYAN}${BACKUP_DIR}/${BACKUP_NAME}.tar.gz${NC}"
echo -e "  Tamanho: ${CYAN}${TOTAL_SIZE}${NC}"
echo -e "  Data:    ${CYAN}$(date '+%d/%m/%Y %H:%M:%S')${NC}"
echo ""
echo -e "${BOLD}Backups existentes:${NC}"
ls -lh "${BACKUP_DIR}"/*.tar.gz 2>/dev/null | awk '{print "  " $5 "  " $9}'
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
