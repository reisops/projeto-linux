# 🏗️ ARCHITECTURE.md — Infrastructure Architecture

-----

## Overview

This lab simulates a real corporate network with three dedicated servers, each with a specific role, communicating over an isolated internal network.

-----

> 📘 Related Documentation:
> - [INSTALL.md](./INSTALL.md) — Step-by-step setup guide
> - [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) — Common issues and fixes
> - [DISCLAIMER.md](./DISCLAIMER.md) — Scope and limitations

----

## Network Diagram

```
╔══════════════════════════════════════════════════════════════════╗
║                     HOST — Fedora Linux                          ║
║                    VirtualBox 7.2                                ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  ┌──────────────────────────────────────────────────────────┐    ║
║  │                  NAT Network (Internet)                  │    ║
║  │            10.0.2.0/24 (managed by VirtualBox)          │    ║
║  └───────────────┬──────────────┬──────────────┬────────────┘    ║
║                  │              │              │                 ║
║         ┌────────┴──┐  ┌────────┴──┐  ┌───────┴───┐              ║
║         │   VM1     │  │   VM2     │  │   VM3     │              ║
║         │ enp0s3    │  │ enp0s3    │  │ enp0s3    │              ║
║         │(NAT/DHCP) │  │(NAT/DHCP) │  │(NAT/DHCP) │              ║
║         │           │  │           │  │           │              ║
║         │ enp0s8    │  │ enp0s8    │  │ enp0s8    │              ║
║         │192.168.10.1  │192.168.10.2  │192.168.10.3              ║
║         └────────┬──┘  └────────┬──┘  └───────┬───┘              ║
║                  │              │              │                 ║
║  ┌───────────────┴──────────────┴──────────────┴────────────┐    ║
║  │               Private Internal Network (intnet)          │    ║
║  │                      192.168.10.0/24                     │    ║
║  └──────────────────────────────────────────────────────────┘    ║
╚══════════════════════════════════════════════════════════════════╝
```

-----

## Components

### VM1 — Core Services (`192.168.10.1`)

**Role:** Gateway, DNS, DHCP, Authentication, File Sharing

|Service            |Function                                              |Port      |
|-------------------|------------------------------------------------------|----------|
|**Bind9**          |Authoritative DNS for `lab.local` + recursive resolver|53/UDP,TCP|
|**isc-dhcp-server**|Assigns IPs in the range `192.168.10.100–200`         |67–68/UDP |
|**SSH**            |Secure remote access using Ed25519 key authentication |22/TCP    |
|**Samba**          |Cross-platform file sharing (SMB/CIFS)                |445/TCP   |
|**iptables**       |Stateful firewall + NAT for outbound internet access  |—         |

**Boot sequence:**

```
Boot → iptables (NAT) → bind9 → isc-dhcp-server → samba → ssh
```

-----

### VM2 — Web Server (`192.168.10.2`)

**Role:** Web hosting, database, CMS

|Service      |Function                               |Port                 |
|-------------|---------------------------------------|---------------------|
|**Apache2**  |HTTP server with multiple virtual hosts|80/TCP               |
|**MariaDB**  |Relational database server             |3306/TCP (local only)|
|**WordPress**|CMS deployed on the LAMP stack         |80/TCP               |
|**PHP**      |Server-side scripting for WordPress    |—                    |

**LAMP stack:**

```
Linux (Ubuntu) → Apache → MariaDB → PHP → WordPress
```

-----

### VM3 — Proxy / Security (`192.168.10.3`)

**Role:** HTTP proxy with caching and access control

|Service  |Function                                     |Port    |
|---------|---------------------------------------------|--------|
|**Squid**|HTTP proxy with content filtering and caching|3128/TCP|

-----

## Communication Flows

### DNS Query

```
Client → [port 53] → VM1 (Bind9)
VM1 resolves internally (lab.local) OR
VM1 forwards to 8.8.8.8 (external domains)
```

### DHCP Request

```
Client (broadcast) → VM1 (isc-dhcp-server)
VM1 responds with: IP address, subnet mask, gateway, DNS server
```

### Proxied Browsing

```
Client → [port 3128] → VM3 (Squid) → Internet
                           ↓
                  Checks blocklist
                  Serves from cache if available
```

### NAT / Outbound Internet Access

```
VM2 or VM3 → [192.168.10.1] → VM1 (iptables MASQUERADE) → Internet
```

### File Share Access

```
Windows/Linux client → [port 445] → VM1 (Samba)
Authentication → Permission check → Share access
```

-----

## IP and Service Reference

|Host               |IP                |Service         |Port        |
|-------------------|------------------|----------------|------------|
|VM1 (Core Services)|192.168.10.1      |DNS             |53          |
|VM1 (Core Services)|192.168.10.1      |DHCP            |67/68       |
|VM1 (Core Services)|192.168.10.1      |SSH             |22          |
|VM1 (Core Services)|192.168.10.1      |Samba           |445         |
|VM1 (Core Services)|192.168.10.1      |Gateway / NAT   |—           |
|VM2 (Web Server)   |192.168.10.2      |HTTP (Apache2)  |80          |
|VM2 (Web Server)   |192.168.10.2      |MariaDB         |3306 (local)|
|VM3 (Proxy)        |192.168.10.3      |Squid Proxy     |3128        |
|—                  |192.168.10.100–200|DHCP lease range|—           |

-----

## Design Decisions

### Why Ubuntu Server instead of Debian?

- 5-year LTS with active security support
- Netplan as the network configuration layer (more modern than `/etc/network/interfaces`)
- Larger community and more abundant documentation
- More widely deployed in real corporate environments

### Why separate Web and Proxy into different VMs?

- Security isolation: a compromised VM does not affect the others
- More accurately reflects a real DMZ architecture
- Enables VM-specific firewall rules between network segments

### Why MariaDB instead of MySQL?

- Community fork maintained by the original MySQL developers
- Better benchmark performance in general workloads
- More permissive GPL license
- 100% compatible with MySQL

### Why key-based SSH authentication?

- Eliminates password-based login, removing a major attack surface
- Reduces exposure to brute-force attacks
- Standard practice in corporate and cloud environments
- Ed25519 keys are used for their modern design and strong security properties

-----

## Service Directory Structure

```
/
├── etc/
│   ├── bind/
│   │   ├── named.conf.options      # Global DNS options
│   │   ├── named.conf.local        # Zone declarations
│   │   └── zones/
│   │       ├── db.lab.local        # Forward zone
│   │       └── db.192.168.10       # Reverse zone
│   ├── dhcp/
│   │   └── dhcpd.conf              # DHCP server configuration
│   ├── samba/
│   │   └── smb.conf                # Samba shares and global config
│   ├── apache2/
│   │   └── sites-available/
│   │       ├── site1.conf
│   │       └── wordpress.conf
│   ├── squid/
│   │   ├── squid.conf              # Squid proxy configuration
│   │   └── blocked-sites.txt       # Domain blocklist
│   ├── iptables/
│   │   ├── rules.sh                # Firewall rules script
│   │   └── rules.v4                # Saved iptables rules
│   └── ssh/
│       └── sshd_config             # Hardened SSH configuration
├── srv/
│   └── samba/                      # Samba share directories
│       ├── publico/
│       ├── ti/
│       ├── financeiro/
│       └── lixeira/
└── var/
    ├── www/                        # Web server document roots
    │   ├── site1/
    │   └── wordpress/
    └── lib/
        └── dhcp/
            └── dhcpd.leases        # Active DHCP leases
```