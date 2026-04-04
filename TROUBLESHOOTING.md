# 🔧 TROUBLESHOOTING.md — Problemas Comuns e Soluções

---

## Índice

1. [VirtualBox](#1-virtualbox)
2. [Rede entre VMs](#2-rede-entre-vms)
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

### ❌ Erro: `vboxconfig` falha com "Secure Boot"

**Sintoma:**
```
modprobe: ERROR: could not insert 'vboxdrv': Operation not permitted
```

**Causa:** Secure Boot impede módulos de kernel não assinados.

**Solução A — Desabilitar Secure Boot (mais fácil):**
1. Reinicie o computador
2. Entre na BIOS/UEFI (geralmente Del, F2 ou F12)
3. Encontre "Secure Boot" → Disable
4. Salve e reinicie

**Solução B — Assinar o módulo (mantém Secure Boot ativo):**
```bash
# Gerar chave de assinatura
openssl req -new -x509 -newkey rsa:2048 -keyout MOK.priv \
  -outform DER -out MOK.der -days 36500 -subj "/CN=VirtualBox/"

# Assinar o módulo
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file \
  sha256 MOK.priv MOK.der \
  $(modinfo -n vboxdrv)

# Registrar a chave
sudo mokutil --import MOK.der
# Digite uma senha temporária

# Reiniciar e aceitar a chave no gerenciador MOK
reboot
```

---

### ❌ Erro: VMs não iniciam após atualização do kernel

**Causa:** Os módulos do VirtualBox precisam ser recompilados para o novo kernel.

**Solução:**
```bash
sudo dnf install -y kernel-devel-$(uname -r) kernel-headers-$(uname -r)
sudo /sbin/vboxconfig
```

---

## 2. Rede entre VMs

### ❌ VMs não se pingam pela rede interna

**Diagnóstico:**
```bash
ip a                          # Verificar se enp0s8 tem IP
ping 192.168.10.1             # Testar gateway
ip route                      # Verificar rotas
```

**Solução 1 — Interface não configurada:**
```bash
sudo netplan apply
# Se ainda falhar:
sudo ip link set enp0s8 up
sudo ip addr add 192.168.10.X/24 dev enp0s8
```

**Solução 2 — Nome da interface diferente:**
```bash
ip a
# Anote o nome real da segunda interface (pode ser enp0s8, eth1, etc.)
# Edite /etc/netplan/00-installer-config.yaml com o nome correto
sudo netplan apply
```

**Solução 3 — Rede Interna com nomes diferentes no VirtualBox:**
- Verifique se todas as VMs usam exatamente o mesmo nome em "Rede Interna"
- No VirtualBox: Configurações → Rede → Adaptador 2 → Nome: `intnet`
- O nome é case-sensitive!

---

### ❌ VMs sem acesso à internet (NAT funcionando mas VM2/VM3 não navegam)

**Verificar na VM1:**
```bash
# ip_forward ativo?
cat /proc/sys/net/ipv4/ip_forward
# Deve retornar 1

# Regra NAT existe?
sudo iptables -t nat -L POSTROUTING -n -v
# Deve mostrar MASQUERADE para enp0s3
```

**Verificar nas VM2/VM3:**
```bash
# Gateway apontando para VM1?
ip route
# Deve mostrar: default via 192.168.10.1

# DNS configurado?
cat /etc/resolv.conf
# Deve mostrar: nameserver 192.168.10.1
```

---

## 3. DNS (Bind9)

### ❌ bind9 falha ao iniciar

**Diagnóstico:**
```bash
sudo systemctl status bind9
sudo journalctl -u bind9 -n 50
sudo named-checkconf
sudo named-checkzone lab.local /etc/bind/zones/db.lab.local
```

**Erros comuns:**

| Erro | Causa | Solução |
|---|---|---|
| `zone lab.local/IN: loaded serial X` seguido de falha | Sintaxe no arquivo de zona | Verificar com `named-checkzone` |
| `permission denied` | Permissões nos arquivos de zona | `sudo chown -R bind:bind /etc/bind/zones/` |
| `address already in use` | Outro processo usando porta 53 | `sudo ss -tulpn \| grep 53` — identificar e parar |

---

### ❌ Resolução DNS não funciona nos clientes

**Verificar do cliente:**
```bash
dig @192.168.10.1 vm2.lab.local    # Consulta direta ao servidor
nslookup vm2.lab.local 192.168.10.1
```

**Se funcionar com `@192.168.10.1` mas não sem:**
```bash
# Verificar /etc/resolv.conf
cat /etc/resolv.conf
# Deve ter: nameserver 192.168.10.1

# No Ubuntu com systemd-resolved pode precisar de:
sudo nano /etc/systemd/resolved.conf
# Adicionar: DNS=192.168.10.1
sudo systemctl restart systemd-resolved
```

---

### ❌ Serial number desatualizado (zona não propaga)

Sempre que alterar um arquivo de zona, incremente o serial:
```
2026070101   →   2026070102   (mesmo dia, segunda alteração)
2026070101   →   2026070201   (dia seguinte)
```

Depois:
```bash
sudo systemctl reload bind9
```

---

## 4. DHCP

### ❌ isc-dhcp-server falha ao iniciar

```bash
sudo systemctl status isc-dhcp-server
sudo journalctl -u isc-dhcp-server -n 30
```

**Erro comum — interface não especificada:**
```bash
# Verificar /etc/default/isc-dhcp-server
cat /etc/default/isc-dhcp-server
# INTERFACESv4 deve ter o nome correto da interface interna
```

**Erro — subnet não cobre a interface:**
```bash
# O IP da interface (192.168.10.1) deve estar dentro da subnet declarada (192.168.10.0/24)
# Verifique o dhcpd.conf
```

---

### ❌ Cliente não recebe IP do DHCP

```bash
# Na VM1, monitorar requisições em tempo real:
sudo tcpdump -i enp0s8 port 67 or port 68

# Verificar leases ativos:
cat /var/lib/dhcp/dhcpd.leases
```

---

## 5. SSH

### ❌ Conexão SSH recusada

```bash
# Verificar se o serviço está rodando
sudo systemctl status ssh

# Verificar a porta
sudo ss -tlpn | grep ssh

# Testar conexão com verbose
ssh -v -i ~/.ssh/lab_key -p 2222 admin@192.168.10.1
```

---

### ❌ "Permission denied (publickey)"

```bash
# Verificar permissões do arquivo de chave no cliente
chmod 600 ~/.ssh/lab_key
chmod 700 ~/.ssh/

# Verificar authorized_keys no servidor
cat ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

---

## 6. Samba

### ❌ Samba não aparece na rede

```bash
sudo systemctl status smbd nmbd

# Testar localmente
smbclient -L localhost -N

# Verificar sintaxe do smb.conf
testparm
```

---

### ❌ "NT_STATUS_LOGON_FAILURE" ao conectar

**Causa:** Usuário não tem conta Samba ou senha Samba diferente da Linux.

```bash
# Adicionar/atualizar senha Samba
sudo smbpasswd -a usuario
sudo smbpasswd -e usuario   # ativar conta
```

---

### ❌ Permissão negada ao gravar arquivos

```bash
# Verificar permissões do diretório
ls -la /srv/samba/

# Corrigir
sudo chmod 777 /srv/samba/publico
# ou para compartilhamentos autenticados:
sudo chown -R usuario:usuario /srv/samba/ti
sudo chmod 770 /srv/samba/ti
```

---

## 7. Apache / WordPress

### ❌ Apache não inicia

```bash
sudo systemctl status apache2
sudo apache2ctl configtest   # Verificar sintaxe

# Verificar logs
sudo tail -50 /var/log/apache2/error.log
```

**Erro comum — porta em uso:**
```bash
sudo ss -tlpn | grep 80
# Se ocupado: sudo systemctl stop nginx (se instalado)
```

---

### ❌ WordPress mostra "Error establishing database connection"

```bash
# Testar conexão manual
mysql -u wp_user -p wordpress_db

# Verificar wp-config.php
grep DB_ /var/www/wordpress/public_html/wp-config.php
```

---

### ❌ WordPress com problema de permissão para upload

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
-- Verificar usuários existentes
SELECT user, host FROM mysql.user;

-- Recriar usuário se necessário
DROP USER IF EXISTS 'wp_user'@'localhost';
CREATE USER 'wp_user'@'localhost' IDENTIFIED BY 'SenhaForte@2026';
GRANT ALL PRIVILEGES ON wordpress_db.* TO 'wp_user'@'localhost';
FLUSH PRIVILEGES;
```

---

## 9. Squid Proxy

### ❌ Squid não inicia

```bash
sudo systemctl status squid
sudo squid -k check

# Inicializar diretórios de cache (obrigatório na primeira vez)
sudo squid -z
sudo systemctl restart squid
```

---

### ❌ "Access Denied" para todos os clientes

```bash
# Verificar ACLs no squid.conf
sudo grep -n "http_access" /etc/squid/squid.conf

# A regra "allow rede_local" deve vir ANTES de "deny all"
```

---

### ❌ Sites bloqueados não estão sendo bloqueados

```bash
# Verificar se o arquivo de bloqueio está sendo lido
sudo squid -k reconfigure

# Testar do cliente com proxy configurado
curl -x http://192.168.10.3:3128 http://facebook.com
# Deve retornar erro de acesso negado

# Ver log de acessos
sudo tail -f /var/log/squid/access.log
```

---

## 10. iptables

### ❌ Regras não persistem após reboot

```bash
# Salvar regras atuais
sudo iptables-save > /etc/iptables/rules.v4

# Verificar se iptables-persistent está instalado
sudo apt install -y iptables-persistent

# Recarregar
sudo netfilter-persistent reload
```

---

### ❌ NAT não funciona (VM2/VM3 sem internet mesmo com regra)

```bash
# Verificar ip_forward
cat /proc/sys/net/ipv4/ip_forward    # Deve ser 1

# Se for 0:
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward

# Para permanente:
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

---

### ❌ Ver todas as regras ativas

```bash
# Tabela filter
sudo iptables -L -n -v --line-numbers

# Tabela nat
sudo iptables -t nat -L -n -v

# Limpar tudo (cuidado — perde acesso SSH se remoto!)
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
```

---

## Comandos de Diagnóstico Rápido

```bash
# Status de todos os serviços
for srv in bind9 isc-dhcp-server ssh smbd apache2 mariadb squid; do
    echo "=== $srv ==="
    systemctl is-active $srv
done

# Verificar portas abertas
sudo ss -tulpn

# Ver logs em tempo real
sudo journalctl -f

# Uso de recursos
htop
df -h
free -h
```
