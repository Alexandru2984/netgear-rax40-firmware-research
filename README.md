# NETGEAR RAX40 Firmware Research

Independent static analysis of the NETGEAR RAX40 (Nighthawk AX4) firmware, focusing initially on DHCP configuration, service management, and error handling.

> **Status:** Research in progress. The findings describe code paths observed in a specific firmware image; they are **not** claims of confirmed exploitability, assigned CVEs, or the proven root cause of a field incident.

## Scope

- **Device:** NETGEAR RAX40
- **Firmware examined:** `V1.0.6.106_1.0.1`
- **Architecture:** MIPS32r2, big-endian; uClibc-based userspace
- **Primary components:** `/usr/sbin/dnsmasq`, `/etc/init.d/dnsmasq`, `/opt/lantiq/servd/lib/liblanservices.so`, `/opt/lantiq/servd/lib/libnetwork.so`, `/usr/lib/libscapi.so`
- **Methods:** Firmware extraction, ELF inspection, Ghidra decompilation, call-path review, and comparison with observed LAN behavior

## Initial incident

Multiple LAN devices sent DHCPDISCOVER packets but received no DHCPOFFER. With manually configured IP addresses, routing and DNS worked. The issue cleared following router reconfiguration. The exact causal mechanism remains **unconfirmed**; see [incident notes](docs/dhcp-investigation.md).

## Research notes

- [Methodology](docs/methodology.md)
- [DHCP architecture](docs/dhcp-architecture.md)
- [DHCP incident investigation](docs/dhcp-investigation.md)

## Findings register

| ID | Topic | Evidence status | Runtime reproduction |
| --- | --- | --- | --- |
| [F-001](findings/F-001-uci-commit-error-masking.md) | Aggregate UCI commit may mask partial failure | Supported by static decompilation | Not performed |
| [F-002](findings/F-002-process-error-handling.md) | Process status and command error handling | Supported by static decompilation | Not performed |
| [F-003](findings/F-003-dhcp-state-management.md) | DHCP state transitions and configuration persistence | Hypothesis based on identified code paths | Not performed |
| [F-004](findings/F-004-sanitizer-bounds.md) | Sanitizer reads past a 1,024-byte local buffer for oversized strings | Supported by static decompilation; reachability unknown | Not performed |

## Repository boundaries

**Do not commit** proprietary firmware images, extracted root filesystems, compiled NETGEAR libraries, large decompilation dumps, private network details, router credentials, or captures containing personal information.

Firmware and source code remain the property of their respective owners. This repository contains original research notes, small code excerpts necessary to explain findings, and independently written tooling.

## Responsible disclosure

Potential security issues should be reproduced in an isolated, authorized environment, assessed for actual impact, and reported through the vendor's appropriate security channel before publishing sensitive exploit details. Findings here are preliminary until independently validated.

## Contributions

Documentation is in English. Please distinguish observed behavior, code-supported inference, and unverified hypotheses in any proposed change.
