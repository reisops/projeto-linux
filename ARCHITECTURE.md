# 🏗️ ARCHITECTURE.md — Arquitetura da Infraestrutura

---

## Visão Geral

Este laboratório simula uma rede corporativa real com três servidores dedicados,
cada um com função específica, comunicando-se via rede interna isolada.

---

## Diagrama de Rede

```
╔══════════════════════════════════════════════════════════════════╗
║                     HOST — Fedora Linux                          ║
║                    VirtualBox 7.0                                ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  ┌──────────────────────────────────────────────────────────┐    ║
║  │                  NAT Network (Internet)                  │    ║
║  │            10.0.2.0/24 (gerenciado pelo VirtualBox)      │    ║
║  └───────────────┬──────────────┬──────────────┬────────────┘    ║
║                  │              │              │                  ║
║         ┌────────┴──┐  ┌────────┴──┐  ┌───────┴───┐            ║
║         │   VM1     │  │   VM2     │  │   VM3     │            ║
║         │ enp0s3    │  │ enp0s3    │  │ enp0s3    │            ║
║         │(NAT/DHCP) │  │(NAT/DHCP) │  │(NAT/DHCP) │            ║
║         │           │  │           │  │           │            ║
║         │ enp0s8    │  │ enp0s8    │  │ enp0s8    │            ║
║         │192.168.10.1  │192.168.10.2  │192.168.10.3            ║
║         └────────┬──┘  └────────┬──┘  └───────┬───┘            ║
║                  │              │              │                  ║
║  ┌───────────────┴──────────────┴──────────────┴────────────┐    ║
║  │              Rede Interna Privada (intnet)                │    ║
║  │                   192.168.10.0/24                        │    ║
║  └──────────────────────────────────────────────────────────┘    ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Componentes

### VM1 — Servidor Principal (`192.168.10.1`)

**Função:** Gateway, DNS, DHCP, Autenticação, Arquivos

| Serviço | Função | Porta |
|---|---|---|
| **Bind9** | DNS autoritativo para `lab.local` + recursivo | 53/UDP,TCP |
| **isc-dhcp-server** | Distribui IPs na faixa `192.168.10.100-200` | 67-68/UDP |
| **SSH** | Acesso remoto seguro com chave Ed25519 | 2222/TCP |
| **Samba** | Compartilhamento de arquivos (SMB/CIFS) | 445/TCP |
| **iptables** | Firewall + NAT para saída à internet | — |

**Fluxo de inicialização:**
```
Boot → iptables (NAT) → bind9 → isc-dhcp-server → samba → ssh
```

---

### VM2 — Servidor Web (`192.168.10.2`)

**Função:** Hospedagem web, banco de dados, CMS

| Serviço | Função | Porta |
|---|---|---|
| **Apache2** | Servidor HTTP com múltiplos virtual hosts | 80/TCP |
| **MariaDB** | Banco de dados relacional | 3306/TCP (local) |
| **WordPress** | CMS instalado como LAMP stack | 80/TCP |
| **PHP** | Linguagem de backend para WordPress | — |

**Stack LAMP:**
```
Linux (Ubuntu) → Apache → MariaDB → PHP → WordPress
```

---

### VM3 — Proxy/Segurança (`192.168.10.3`)

**Função:** Proxy HTTP com cache e controle de acesso

| Serviço | Função | Porta |
|---|---|---|
| **Squid** | Proxy HTTP com cache e filtragem de conteúdo | 3128/TCP |

---

## Fluxo de Comunicação

### Requisição DNS
```
Cliente → [porta 53] → VM1 (Bind9)
VM1 resolve internamente (lab.local) OU
VM1 repassa para 8.8.8.8 (domínios externos)
```

### Requisição DHCP
```
Cliente (broadcast) → VM1 (isc-dhcp-server)
VM1 responde com: IP, máscara, gateway, DNS
```

### Navegação via Proxy
```
Cliente → [porta 3128] → VM3 (Squid) → Internet
                    ↓
            Verifica lista de bloqueios
            Serve do cache se disponível
```

### NAT / Saída para internet
```
VM2 ou VM3 → [192.168.10.1] → VM1 (iptables MASQUERADE) → Internet
```

### Acesso a arquivo compartilhado
```
Cliente Windows/Linux → [porta 445] → VM1 (Samba)
Autenticação → Verificação de permissões → Acesso ao share
```

---

## Tabela de IPs e Serviços

| Host | IP | Serviço | Porta |
|---|---|---|---|
| VM1 | 192.168.10.1 | DNS | 53 |
| VM1 | 192.168.10.1 | DHCP | 67/68 |
| VM1 | 192.168.10.1 | SSH | 2222 |
| VM1 | 192.168.10.1 | Samba | 445 |
| VM1 | 192.168.10.1 | Gateway/NAT | — |
| VM2 | 192.168.10.2 | HTTP (Apache) | 80 |
| VM2 | 192.168.10.2 | MariaDB | 3306 (local) |
| VM3 | 192.168.10.3 | Squid Proxy | 3128 |
| — | 192.168.10.100-200 | Range DHCP | — |

---

## Decisões de Design

### Por que Ubuntu Server em vez de Debian?
- LTS de 5 anos com suporte ativo
- Netplan como sistema de configuração de rede (mais moderno)
- Comunidade maior e documentação mais abundante
- Mais comum em ambientes corporativos reais

### Por que separar Web e Proxy em VMs diferentes?
- Isolamento de segurança: comprometimento de uma VM não afeta a outra
- Simula melhor uma arquitetura real de DMZ
- Permite aplicar regras de firewall específicas entre as VMs

### Por que MariaDB em vez de MySQL?
- Fork comunitário mantido pelos criadores originais do MySQL
- Melhor desempenho em benchmarks gerais
- Licença GPL mais permissiva
- Compatível 100% com MySQL

### Por que porta 2222 no SSH?
- Evitar bots automatizados que varrem a porta 22
- Boa prática de hardening mesmo em ambientes de lab
- Demonstra consciência de segurança para recrutadores

---

## Estrutura de Diretórios dos Serviços

```
/
├── etc/
│   ├── bind/
│   │   ├── named.conf.options      # Opções globais DNS
│   │   ├── named.conf.local        # Declaração de zonas
│   │   └── zones/
│   │       ├── db.lab.local        # Zona direta
│   │       └── db.192.168.10       # Zona reversa
│   ├── dhcp/
│   │   └── dhcpd.conf              # Config DHCP
│   ├── samba/
│   │   └── smb.conf                # Config Samba
│   ├── apache2/
│   │   └── sites-available/
│   │       ├── site1.conf
│   │       └── wordpress.conf
│   ├── squid/
│   │   ├── squid.conf              # Config Squid
│   │   └── blocked-sites.txt       # Blacklist
│   ├── iptables/
│   │   ├── rules.sh                # Script de regras
│   │   └── rules.v4                # Regras salvas
│   └── ssh/
│       └── sshd_config             # SSH hardened
├── srv/
│   └── samba/                      # Compartilhamentos
│       ├── publico/
│       ├── ti/
│       ├── financeiro/
│       └── lixeira/
└── var/
    ├── www/                        # Sites web
    │   ├── site1/
    │   └── wordpress/
    └── lib/
        └── dhcp/
            └── dhcpd.leases        # Leases DHCP ativos
```
