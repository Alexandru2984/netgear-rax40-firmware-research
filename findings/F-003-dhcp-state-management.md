# F-003 — DHCP configuration state transitions need validation

**Components:** `liblanservices.so`, `/etc/init.d/dnsmasq`, `/etc/config/dhcp`  
**Functions:** `dhcp_modify()`, internal `dhcp_writeConfig()`  
**Status:** Hypothesis; no confirmed defect or root cause  
**Security severity:** Not assigned

## Observed static behavior

`dhcp_writeConfig()` includes paths that set `dhcp.lan.dhcpv4_dnsmasq=disabled` and `...=relay`. The stock configuration contains `...=server`. The init script skips DHCP range generation when configured as `disabled` and also requires a `static` LAN protocol.

The internal RouterMode `Mode == 1` test participates in the disable condition, although the precise mode mapping is not yet established.

## Open questions

- Which code path restores `server` after `disabled` or `relay`?
- What do RouterMode values represent on this firmware?
- Can a configuration or service reload failure leave DNS operational while DHCP is unavailable?
- Was any of these conditions present during the observed incident?

## Required validation

Map the relevant state transitions and test them only in an authorized isolated lab. Do not describe the observed incident as caused by this mechanism until confirmed by runtime evidence.
