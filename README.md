# 🐧 Linux Infrastructure Lab — Portfolio Project

> Infraestrutura completa de rede local com Ubuntu Server, implementando serviços essenciais de administração de sistemas Linux.

![Ubuntu](https://img.shields.io/badge/Ubuntu_Server-24.04_LTS-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![VirtualBox](https://img.shields.io/badge/VirtualBox-7.0-183A61?style=for-the-badge&logo=virtualbox&logoColor=white)
![Status](https://img.shields.io/badge/Status-Em_Desenvolvimento-yellow?style=for-the-badge)

---

## 📋 Visão Geral

Este projeto simula uma infraestrutura de rede corporativa real usando máquinas virtuais, demonstrando habilidades práticas em administração de sistemas Linux. Todo o ambiente foi construído do zero, documentado e versionado.

**Período de desenvolvimento:** Abril/2026  
**Ambiente:** VirtualBox + Ubuntu Server 24.04 LTS  
**Rede interna:** `192.168.10.0/24`

---

## 🏗️ Arquitetura

```
                        INTERNET
                            │
                    ┌───────┴────────┐
                    │  HOST (Fedora) │
                    │  VirtualBox    │
                    └───────┬────────┘
                            │ NAT
              ┌─────────────┼─────────────┐
              │             │             │
     ┌────────┴──────┐ ┌────┴──────┐ ┌───┴───────────┐
     │  VM1          │ │  VM2      │ │  VM3           │
     │  Servidor     │ │  Web      │ │  Proxy/Seg.    │
     │  Principal    │ │  Server   │ │                │
     │               │ │           │ │                │
     │ 192.168.10.1  │ │192.168.10.2│ │ 192.168.10.3  │
     │               │ │           │ │                │
     │ • DNS (Bind9) │ │ • Apache  │ │ • Squid Proxy  │
     │ • DHCP        │ │ • WordPress│ │ • Monitoramento│
     │ • Firewall    │ │ • MariaDB │ │                │
     │ • SSH         │ │           │ │                │
     │ • Samba       │ │           │ │                │
     └───────────────┘ └───────────┘ └────────────────┘
              │                 │              │
              └─────────────────┴──────────────┘
                        Rede Interna
                      192.168.10.0/24
```

---

## 🛠️ Serviços Implementados

| Serviço | VM | IP | Porta(s) | Status |
|---|---|---|---|---|
| DNS (Bind9) | VM1 | 192.168.10.1 | 53 | ✅ |
| DHCP Server | VM1 | 192.168.10.1 | 67/68 | ✅ |
| SSH | VM1 | 192.168.10.1 | 22 | ✅ |
| Samba | VM1 | 192.168.10.1 | 445 | ✅ |
| iptables Firewall | VM1 | 192.168.10.1 | — | ✅ |
| Apache2 | VM2 | 192.168.10.2 | 80 | ✅ |
| WordPress | VM2 | 192.168.10.2 | 80 | ✅ |
| MariaDB | VM2 | 192.168.10.2 | 3306 | ✅ |
| Squid Proxy | VM3 | 192.168.10.3 | 3128 | ✅ |

---

## 📁 Estrutura do Repositório

```
projeto-linux/
├── README.md                  # Este arquivo
├── INSTALL.md                 # Guia completo de instalação
├── ARCHITECTURE.md            # Arquitetura detalhada
├── TROUBLESHOOTING.md         # Problemas comuns e soluções
├── configs/
│   ├── bind/                  # Configurações do DNS
│   ├── dhcp/                  # Configurações do DHCP
│   ├── samba/                 # Configurações do Samba
│   ├── apache/                # Virtual hosts Apache
│   ├── squid/                 # Configurações do Squid
│   ├── iptables/              # Regras de firewall
│   └── ssh/                   # Configurações SSH hardened
├── scripts/
│   ├── setup/                 # Scripts de instalação automatizada
│   ├── backup.sh              # Backup automatizado
│   ├── monitor.sh             # Monitoramento de serviços
│   └── restart-services.sh    # Restart de todos os serviços
└── docs/
    └── screenshots/           # Evidências de funcionamento
```

---

## 🚀 Quick Start

> Guia resumido. Para instalação completa, veja [INSTALL.md](./INSTALL.md)

```bash
# 1. Clone o repositório
git clone https://github.com/reisops/projeto-linux.git
cd projeto-linux

# 2. Execute o setup da VM1 (como root)
chmod +x scripts/setup/vm1-setup.sh
sudo ./scripts/setup/vm1-setup.sh

# 3. Execute o setup da VM2
sudo ./scripts/setup/vm2-setup.sh

# 4. Execute o setup da VM3
sudo ./scripts/setup/vm3-setup.sh
```

---

## 📸 Evidências de Funcionamento

### 🔗 Comunicação entre VMs

![Rede entre VMs](docs/screenshots/allvms.png)

### 🔧 Servidor Principal (VM1)

![Status VM1](docs/screenshots/vm1status.png)

### 🌐 Servidor Web (VM2)

![Status VM2](docs/screenshots/vm2status.png)
![WordPress](docs/screenshots/wordpress.png)

### 🔒 Proxy (VM3)

![Logs do Squid](docs/screenshots/squid-logs.png)

### 📊 Monitoramento

![Monitor de Serviços](docs/screenshots/monitor.png)

### 💾 Backup Automatizado (todas as VMs)

Execução do script de backup em todas as máquinas do ambiente, demonstrando padronização e automação da infraestrutura.

- VM1 (Servidor Principal): backup de DNS, DHCP, Samba e firewall
- VM2 (Web Server): backup de Apache, WordPress e MariaDB
- VM3 (Proxy): backup do Squid e logs

![Backup em todas as VMs](docs/screenshots/backup-all-vms.png)

> O script detecta automaticamente quais serviços estão ativos em cada VM e realiza o backup apenas do que existe, evitando erros.


---

## 🧠 Habilidades Demonstradas

- Administração de servidores Linux (Ubuntu Server)
- Configuração de serviços de rede (DNS, DHCP, Proxy)
- Segurança de redes com iptables (NAT, port forwarding, firewall)
- Deploy de aplicações web (LAMP stack, WordPress)
- Compartilhamento de arquivos cross-platform (Samba)
- Scripting Bash para automação de tarefas
- Documentação técnica profissional
- Versionamento com Git/GitHub

---

## 👤 Autor

**Luis Reis**  
[LinkedIn](https://linkedin.com/in/luis-reis-ops) | [GitHub](https://github.com/reisops)

---
