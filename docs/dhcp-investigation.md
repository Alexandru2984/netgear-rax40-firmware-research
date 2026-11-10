# LAN DHCP incident investigation

## Field observations

- Router: NETGEAR RAX40, firmware `V1.0.6.106_1.0.1`.
- Affected devices included an Ubuntu laptop and a PlayStation 5.
- Packet capture showed repeated DHCPDISCOVER transmissions without corresponding DHCPOFFER replies.
- The PS5 assigned itself an address in the `169.254.0.0/16` link-local range.
- Manually configured LAN addresses allowed internet access and DNS resolution.
- The router's DHCP server setting appeared enabled in the management interface.
- The problem later cleared after router reconfiguration/setup.

## Interpretation

These observations demonstrate DHCP address assignment failure during the incident. They do not alone identify whether dnsmasq ignored a request, had no eligible address pool, failed a startup/reload step, or was suppressed by configuration.

## Code-supported hypotheses

1. **Disabled LAN DHCP mode:** `dhcp_writeConfig()` can write `dhcp.lan.dhcpv4_dnsmasq=disabled`; the init script then omits DHCP pool setup.
2. **Non-static LAN protocol:** `dhcp_add()` skips address-range setup unless the interface protocol is `static`.
3. **DHCP server collision detection:** `dhcp_check()` may prevent pool generation when another DHCP server is detected.
4. **Error propagation:** UCI and process-management wrappers have error-reporting weaknesses that could obscure failures.

None has been shown to be the specific root cause of the incident.

## Next evidence to seek (without disrupting the live router)

- Resolve the meaning of `Device.X_VENDOR_COM_RouterMode.Mode` values.
- Locate the function restoring `dhcp.lan.dhcpv4_dnsmasq=server` (if any).
- Identify the indirectly called pool-writing function inside `dhcp_writeConfig()`.
- Confirm interpreted control flow against MIPS disassembly.
- If a future incident occurs, preserve relevant dnsmasq logs, UCI state, process status, and packet captures before reconfiguration.
