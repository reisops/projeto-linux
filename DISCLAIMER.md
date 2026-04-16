# ⚠️ DISCLAIMER — Lab Environment

## 📎 Related Documentation

- 📦 [Installation Guide](./INSTALL.md)
- 🔧 [Troubleshooting Guide](./TROUBLESHOOTING.md)

## Purpose

This project was developed as a hands-on practical lab for Linux infrastructure and system administration. It simulates a real-world corporate network environment using virtual machines, with the goal of demonstrating applied technical skills — not theoretical knowledge.

## Scope

The environment covers network service configuration (DNS, DHCP, proxy), web application deployment (LAMP stack, WordPress), file sharing (Samba), firewall management (iptables/NAT), and SSH hardening — all built and validated on a single physical host running Fedora Linux with VirtualBox.

## What This Project Represents

This is not a "perfect setup." It is an honest record of an infrastructure built from scratch, including the failures encountered along the way. Real issues were diagnosed and resolved during development, including:

- VirtualBox kernel module failures related to Secure Boot
- Interface naming inconsistencies between NAT and internal network adapters
- Manual interface adjustments required after Netplan mismatches
- Iterative troubleshooting across multiple service configurations before achieving a stable state

Every problem encountered is documented in [TROUBLESHOOTING.md](./TROUBLESHOOTING.md). That documentation is part of the project — not an appendix.

## Reproducibility

This environment was validated on the author's specific setup. Behavior may differ depending on:

- Host operating system and version
- VirtualBox version
- Physical hardware (particularly Secure Boot configuration)
- Network adapter naming on the guest OS

Steps and configurations are provided in full detail to maximize reproducibility, but manual adjustments may be necessary depending on your environment.

## Limitations

- All services run within a private virtual network (`192.168.10.0/24`) and are not exposed to the public internet
- This is a lab environment — it is not hardened for production deployment
- MariaDB is accessible only locally on VM2; external access is explicitly blocked at the firewall level

---

**Author:** Luis Reis
**Date:** April 2026
[LinkedIn](https://linkedin.com/in/luis-reis-ops) | [GitHub](https://github.com/reisops)
