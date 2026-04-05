# 📦 INSTALL.md — Guia Completo de Instalação

> Siga este guia do zero: do VirtualBox até todos os serviços funcionando.

---

## ÍNDICE

1. [Instalar VirtualBox no Fedora](#1-instalar-virtualbox-no-fedora)
2. [Baixar Ubuntu Server](#2-baixar-ubuntu-server)
3. [Criar as VMs](#3-criar-as-vms)
4. [Instalar Ubuntu Server nas VMs](#4-instalar-ubuntu-server-nas-vms)
5. [Configuração inicial das VMs](#5-configuração-inicial-das-vms)
6. [VM1 — DNS (Bind9)](#6-vm1--dns-bind9)
7. [VM1 — DHCP Server](#7-vm1--dhcp-server)
8. [VM1 — SSH Hardened](#8-vm1--ssh-hardened)
9. [VM1 — Samba](#9-vm1--samba)
10. [VM1 — iptables Firewall](#10-vm1--iptables-firewall)
11. [VM2 — Apache2 + Virtual Hosts](#11-vm2--apache2--virtual-hosts)
12. [VM2 — MariaDB](#12-vm2--mariadb)
13. [VM2 — WordPress](#13-vm2--wordpress)
14. [VM3 — Squid Proxy](#14-vm3--squid-proxy)
15. [Testes de Validação](#15-testes-de-validação)

---

## 1. Instalar VirtualBox no Fedora

### 1.1 — Atualizar o sistema

```bash
sudo dnf update -y
```

### 1.2 — Instalar dependências do kernel

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

> ⚠️ **Atenção:** As versões do `kernel-devel` e `kernel-headers` devem ser idênticas ao kernel em uso. Verifique com `uname -r`.

### 1.3 — Adicionar repositório oficial da Oracle

```bash
sudo wget https://download.virtualbox.org/virtualbox/rpm/fedora/virtualbox.repo \
  -O /etc/yum.repos.d/virtualbox.repo
```

### 1.4 — Importar chave GPG

```bash
sudo rpm --import https://www.virtualbox.org/download/oracle_vbox.asc
```

### 1.5 — Instalar VirtualBox

```bash
sudo dnf install -y VirtualBox
```

### 1.6 — Adicionar usuário ao grupo vboxusers

```bash
sudo usermod -aG vboxusers $USER
```

### 1.7 — Compilar módulos do kernel

```bash
sudo /sbin/vboxconfig
```

A saída esperada é:
```
vboxdrv.sh: Stopping VirtualBox services.
vboxdrv.sh: Starting VirtualBox services.
vboxdrv.sh: Building VirtualBox kernel modules.
```

> ⚠️ **Secure Boot:** Se aparecer erro relacionado a Secure Boot, você tem duas opções:
> - Desabilitar Secure Boot na BIOS (mais simples)
> - Assinar o módulo manualmente com `mokutil`

### 1.8 — Reiniciar e verificar

```bash
reboot
# Após reiniciar:
virtualbox --version
# Saída esperada: 7.x.x (ou superior)
```

---

## 2. Baixar Ubuntu Server

Acesse: **https://ubuntu.com/download/server**

Baixe o **Ubuntu Server 24.04 LTS (Noble Numbat)** — arquivo `.iso` (~2.5 GB).

Verifique a integridade do download:
```bash
sha256sum ubuntu-24.04-live-server-amd64.iso
# Compare com o hash no site oficial
```

---

## 3. Criar as VMs

### Configurações das VMs

| Configuração | VM1 (Principal) | VM2 (Web) | VM3 (Proxy) |
|---|---|---|---|
| Nome | `vm1-servidor` | `vm2-web` | `vm3-proxy` |
| SO | Ubuntu Server 24.04 | Ubuntu Server 24.04 | Ubuntu Server 24.04 |
| RAM | 2048 MB | 2048 MB | 1024 MB |
| CPU | 2 cores | 2 cores | 1 core |
| Disco | 20 GB | 20 GB | 15 GB |
| Rede 1 | NAT | NAT | NAT |
| Rede 2 | Rede Interna (`intnet`) | Rede Interna (`intnet`) | Rede Interna (`intnet`) |

### Passo a passo para criar cada VM:

1. Abra o VirtualBox → clique em **"Novo"**
2. Preencha Nome e selecione:
   - Tipo: `Linux`
   - Versão: `Ubuntu (64-bit)`
3. Defina a RAM conforme a tabela acima
4. Crie um disco rígido virtual (VDI, dinamicamente alocado)
5. Após criar: clique na VM → **Configurações → Rede**
   - **Adaptador 1:** NAT (já vem configurado)
   - **Adaptador 2:** Rede Interna → Nome: `intnet`
6. Em **Configurações → Armazenamento**, adicione a ISO do Ubuntu no drive óptico
7. Repita para as 3 VMs

---

## 4. Instalar Ubuntu Server nas VMs

> Repita este processo nas 3 VMs.

1. Inicie a VM → selecione **"Try or Install Ubuntu Server"**
2. Idioma: **English** (recomendado para servidores)
3. Layout de teclado: **Portuguese (Brazil)**
4. Tipo de instalação: **Ubuntu Server** (sem extras)
5. Configuração de rede:
   - O instalador detecta as interfaces automaticamente
   - Deixe a interface NAT com DHCP (para internet durante instalação)
   - A interface interna configure depois
6. Storage: **Use an entire disk** → confirme
7. Perfil:
   - VM1: nome `vm1`, usuário `admin`, senha forte
   - VM2: nome `vm2`, usuário `admin`, senha forte
   - VM3: nome `vm3`, usuário `admin`, senha forte
8. **SSH:** marque "Install OpenSSH server"
9. Snaps adicionais: **não selecione nada** → Continue
10. Aguarde a instalação e reinicie

---

## 5. Configuração Inicial das VMs

> Execute em todas as VMs após a instalação.

### 5.1 — Atualizar o sistema

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y net-tools curl wget nano htop
```

### 5.2 — Configurar IPs estáticos (interface interna)

Identifique as interfaces:
```bash
ip a
# Anote os nomes: enp0s3 (NAT) e enp0s8 (interna)
```

Edite o Netplan:
```bash
sudo nano /etc/netplan/00-installer-config.yaml
```

**VM1 (`192.168.10.1`):**
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

**VM2 (`192.168.10.2`):**
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

**VM3 (`192.168.10.3`):**
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

Aplique as configurações:
```bash
sudo netplan apply
```

Verifique:
```bash
ip a
ping 192.168.10.1   # De VM2 ou VM3, deve responder
```

---

## 6. VM1 — DNS (Bind9)

### 6.1 — Instalar

```bash
sudo apt install -y bind9 bind9utils dnsutils
```

### 6.2 — Configurar opções globais

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

### 6.3 — Declarar as zonas

```bash
sudo nano /etc/bind/named.conf.local
```

```
# Zona direta
zone "lab.local" {
    type master;
    file "/etc/bind/zones/db.lab.local";
};

# Zona reversa
zone "10.168.192.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/db.192.168.10";
};
```

### 6.4 — Criar arquivos de zona

```bash
sudo mkdir /etc/bind/zones
```

**Zona direta:**
```bash
sudo nano /etc/bind/zones/db.lab.local
```

```
$TTL    604800
@   IN  SOA ns1.lab.local. admin.lab.local. (
            2026070101  ; Serial (AAAAMMDDXX)
            3600        ; Refresh
            1800        ; Retry
            604800      ; Expire
            86400 )     ; Negative Cache TTL

; Servidores de nome
@       IN  NS      ns1.lab.local.

; Registros A
ns1     IN  A       192.168.10.1
vm1     IN  A       192.168.10.1
vm2     IN  A       192.168.10.2
vm3     IN  A       192.168.10.3

; Aliases (CNAME)
www     IN  CNAME   vm2
proxy   IN  CNAME   vm3

; Registro MX (e-mail)
@       IN  MX  10  mail.lab.local.
mail    IN  A       192.168.10.2
```

**Zona reversa:**
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

; PTR Records (IP → nome)
1   IN  PTR vm1.lab.local.
2   IN  PTR vm2.lab.local.
3   IN  PTR vm3.lab.local.
```

### 6.5 — Verificar e iniciar

```bash
# Verificar sintaxe
sudo named-checkconf
sudo named-checkzone lab.local /etc/bind/zones/db.lab.local
sudo named-checkzone 10.168.192.in-addr.arpa /etc/bind/zones/db.192.168.10

# Iniciar
sudo systemctl restart bind9
sudo systemctl enable bind9
sudo systemctl status bind9
```

### 6.6 — Testar

```bash
dig @192.168.10.1 vm2.lab.local
dig @192.168.10.1 -x 192.168.10.2
nslookup vm2.lab.local 192.168.10.1
```

---

## 7. VM1 — DHCP Server

### 7.1 — Instalar

```bash
sudo apt install -y isc-dhcp-server
```

### 7.2 — Definir interface

```bash
sudo nano /etc/default/isc-dhcp-server
```

```
INTERFACESv4="enp0s8"
INTERFACESv6=""
```

### 7.3 — Configurar o DHCP

```bash
sudo nano /etc/dhcp/dhcpd.conf
```

```
# Configurações globais
default-lease-time 600;
max-lease-time 7200;
authoritative;

# Integração com DNS
option domain-name "lab.local";
option domain-name-servers 192.168.10.1;

# Subnet da rede interna
subnet 192.168.10.0 netmask 255.255.255.0 {
    range 192.168.10.100 192.168.10.200;
    option routers 192.168.10.1;
    option broadcast-address 192.168.10.255;
}

# Reservas estáticas (MAC → IP fixo)
host workstation-01 {
    hardware ethernet 08:00:27:AA:BB:CC;   # substitua pelo MAC real
    fixed-address 192.168.10.50;
}
```

### 7.4 — Iniciar

```bash
sudo systemctl restart isc-dhcp-server
sudo systemctl enable isc-dhcp-server
sudo systemctl status isc-dhcp-server
```

### 7.5 — Monitorar leases

```bash
cat /var/lib/dhcp/dhcpd.leases
```

---

## 8. VM1 — SSH Hardened

### 8.1 — Gerar par de chaves (no host Fedora)

```bash
ssh-keygen -t ed25519 -C "portfolio-lab" -f ~/.ssh/lab_key
```

### 8.2 — Copiar chave pública para a VM1

```bash
ssh-copy-id -i ~/.ssh/lab_key.pub admin@192.168.10.1
```

### 8.3 — Endurecer o sshd_config

```bash
sudo nano /etc/ssh/sshd_config
```

Altere ou confirme estas linhas:
```
Port 22                        # Porta padrão (22)
PermitRootLogin no               # Sem login root
PasswordAuthentication no        # Apenas chaves
PubkeyAuthentication yes         # Habilita chaves
AuthorizedKeysFile .ssh/authorized_keys
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
AllowUsers admin                 # Apenas este usuário
```

### 8.4 — Reiniciar

```bash
sudo systemctl restart ssh
```

### 8.5 — Testar (do host Fedora)

```bash
ssh -i ~/.ssh/lab_key admin@192.168.10.1
```

---

## 9. VM1 — Samba

### 9.1 — Instalar

```bash
sudo apt install -y samba smbclient cifs-utils
```

### 9.2 — Criar diretórios

```bash
sudo mkdir -p /srv/samba/{publico,ti,financeiro,lixeira}
sudo chmod 777 /srv/samba/publico
sudo chmod 770 /srv/samba/ti
sudo chmod 770 /srv/samba/financeiro
sudo chmod 777 /srv/samba/lixeira
```

### 9.3 — Criar usuários

```bash
sudo adduser joao --no-create-home --disabled-password
sudo adduser maria --no-create-home --disabled-password
sudo smbpasswd -a joao
sudo smbpasswd -a maria
sudo smbpasswd -e joao
sudo smbpasswd -e maria
```

### 9.4 — Configurar smb.conf

```bash
sudo mv /etc/samba/smb.conf /etc/samba/smb.conf.original
sudo nano /etc/samba/smb.conf
```

```ini
[global]
   workgroup = LAB
   server string = Servidor de Arquivos LAB
   security = user
   map to guest = bad user
   dns proxy = no
   log file = /var/log/samba/log.%m
   max log size = 1000

   # Lixeira global
   vfs objects = recycle
   recycle:repository = /srv/samba/lixeira/%U
   recycle:keeptree = yes
   recycle:versions = yes

[publico]
   comment = Compartilhamento Público
   path = /srv/samba/publico
   guest ok = yes
   browseable = yes
   writable = yes

[ti]
   comment = Departamento de TI
   path = /srv/samba/ti
   valid users = joao maria
   browseable = yes
   writable = yes
   create mask = 0660
   directory mask = 0770

[financeiro]
   comment = Financeiro — Somente Leitura para TI
   path = /srv/samba/financeiro
   valid users = maria
   read list = joao
   writable = yes
   browseable = no

   # Bloquear executáveis e mídia
   veto files = /*.exe/*.mp3/*.mp4/*.avi/
```

### 9.5 — Iniciar

```bash
sudo systemctl restart smbd nmbd
sudo systemctl enable smbd nmbd
```

### 9.6 — Testar

```bash
smbclient //192.168.10.1/publico -N
smbclient //192.168.10.1/ti -U joao
```

---

## 10. VM1 — iptables Firewall

### 10.1 — Instalar iptables-persistent

```bash
sudo apt install -y iptables-persistent
```

### 10.2 — Criar script de regras

```bash
sudo nano /etc/iptables/rules.sh
```

```bash
#!/bin/bash

# Limpar regras existentes
iptables -F
iptables -X
iptables -t nat -F

# Políticas padrão
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Loopback
iptables -A INPUT -i lo -j ACCEPT

# Conexões estabelecidas
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# SSH (porta customizada)
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

# NAT — compartilhar internet para rede interna
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE

# FORWARD — permitir tráfego entre interfaces
iptables -A FORWARD -i enp0s8 -o enp0s3 -j ACCEPT
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# Bloquear acesso externo ao MariaDB (porta 3306)
iptables -A INPUT -p tcp --dport 3306 -j DROP

# Salvar regras
iptables-save > /etc/iptables/rules.v4
echo "Regras aplicadas com sucesso."
```

```bash
sudo chmod +x /etc/iptables/rules.sh
sudo bash /etc/iptables/rules.sh
```

### 10.3 — Habilitar ip_forward permanentemente

```bash
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

---

## 11. VM2 — Apache2 + Virtual Hosts

### 11.1 — Instalar

```bash
sudo apt install -y apache2 php libapache2-mod-php \
  php-mysql php-curl php-gd php-mbstring \
  php-xml php-xmlrpc php-soap php-intl php-zip
```

### 11.2 — Criar sites

```bash
sudo mkdir -p /var/www/{site1,wordpress}/public_html
```

**Site de teste:**
```bash
sudo nano /var/www/site1/public_html/index.html
```

```html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <title>Lab Linux — Site 1</title>
</head>
<body>
    <h1>🐧 Apache Funcionando!</h1>
    <p>VM2 — Servidor Web do Lab Linux</p>
</body>
</html>
```

### 11.3 — Criar Virtual Host

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

### 12.1 — Instalar

```bash
sudo apt install -y mariadb-server
```

### 12.2 — Configuração segura

```bash
sudo mysql_secure_installation
# Responda: Y, defina senha root, Y, Y, Y, Y
```

### 12.3 — Criar banco para WordPress

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

### 13.1 — Baixar WordPress

```bash
cd /tmp
wget https://wordpress.org/latest.tar.gz
tar xzvf latest.tar.gz
sudo cp -r wordpress/. /var/www/wordpress/public_html/
```

### 13.2 — Configurar permissões

```bash
sudo chown -R www-data:www-data /var/www/wordpress
sudo find /var/www/wordpress -type d -exec chmod 750 {} \;
sudo find /var/www/wordpress -type f -exec chmod 640 {} \;
```

### 13.3 — Configurar wp-config.php

```bash
sudo cp /var/www/wordpress/public_html/wp-config-sample.php \
        /var/www/wordpress/public_html/wp-config.php
sudo nano /var/www/wordpress/public_html/wp-config.php
```

Altere as linhas:
```php
define( 'DB_NAME', 'wordpress_db' );
define( 'DB_USER', 'wp_user' );
define( 'DB_PASSWORD', 'SenhaForte@2026' );
define( 'DB_HOST', 'localhost' );
define( 'FS_METHOD', 'direct' );
```

### 13.4 — Virtual Host do WordPress

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

Acesse: `http://192.168.10.2` e conclua a instalação pelo navegador.

---

## 14. VM3 — Squid Proxy

### 14.1 — Instalar

```bash
sudo apt install -y squid apache2-utils
```

### 14.2 — Configurar

```bash
sudo mv /etc/squid/squid.conf /etc/squid/squid.conf.original
sudo nano /etc/squid/squid.conf
```

```
# Porta
http_port 3128

# Rede local permitida
acl rede_local src 192.168.10.0/24
http_access allow rede_local

# Bloquear sites
acl sites_bloqueados dstdomain "/etc/squid/blocked-sites.txt"
http_access deny sites_bloqueados

# Negar resto
http_access deny all

# Cache
cache_mem 256 MB
maximum_object_size_in_memory 512 KB
cache_dir ufs /var/spool/squid 2048 16 256

# Logs
access_log /var/log/squid/access.log
```

**Lista de sites bloqueados:**
```bash
sudo nano /etc/squid/blocked-sites.txt
```

```
.facebook.com
.tiktok.com
.youtube.com
```

### 14.3 — Iniciar

```bash
sudo squid -z   # Inicializar cache
sudo systemctl restart squid
sudo systemctl enable squid
```

### 14.4 — Configurar clientes

Para usar o proxy, configure nos clientes:
- **Endereço:** `192.168.10.3`
- **Porta:** `3128`

---

## 15. Testes de Validação

Execute estes testes para confirmar que tudo está funcionando:

```bash
# DNS
dig @192.168.10.1 vm2.lab.local
dig @192.168.10.1 -x 192.168.10.2

# DHCP (verificar leases)
cat /var/lib/dhcp/dhcpd.leases

# SSH
ssh -i ~/.ssh/lab_key admin@192.168.10.1

# Samba
smbclient //192.168.10.1/publico -N

# Apache (de qualquer VM na rede)
curl http://192.168.10.2

# MariaDB
mysql -u wp_user -p wordpress_db -e "SHOW TABLES;"

# Squid
curl -x http://192.168.10.3:3128 http://example.com

# Firewall
iptables -L -n -v

# Ping entre VMs
ping 192.168.10.2  # Da VM1
ping 192.168.10.1  # Da VM2
```

---

> ✅ Se todos os testes passarem, a infraestrutura está completa!
