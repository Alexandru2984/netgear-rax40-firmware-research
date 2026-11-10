# DHCP implementation and service architecture

## Layers identified

```text
Management data model / servd
  |
  +-- liblanservices.so
  |     dhcp_modify()
  |        -> internal function logged as dhcp_writeConfig()
  |        -> libucihelper_UCISet() / libucihelper_UCICommit()
  |     dnsmasq_init() -> dhcp_init()
  |     dnsmasq_uninit() -> dnsmasq_stop() [imported]
  |
  +-- libnetwork.so
        dnsmasq_start() -> scapi_spawn("/etc/init.d/dnsmasq reload", ...)
        dnsmasq_stop()  -> scapi_spawn("/etc/init.d/dnsmasq stop", ...)

UCI: /etc/config/network, /etc/config/dhcp
  |
  +-- /etc/init.d/dnsmasq -> procd -> /usr/sbin/dnsmasq
```

## Relevant UCI settings

The firmware's stock `/etc/config/dhcp` includes `option dhcpv4_dnsmasq 'server'` for LAN.

`dhcp_writeConfig()` contains code that constructs:

- `dhcp.lan.dhcpv4_dnsmasq=relay`
- `dhcp.lan.dhcpv4_dnsmasq=disabled`

The dnsmasq init script exits `dhcp_add()` early if `dhcpv4_dnsmasq=disabled`, and it requires the relevant interface protocol to be `static` before generating a DHCP address range. These checks can result in a running DNS process with no active LAN DHCP range.

## Router-mode control

The embedded `/etc/ctrlcfg` defaults `Device.X_VENDOR_COM_RouterMode.Mode` to `0`. Decompiled code loads that value into an internal variable and includes `Mode == 1` in a condition that writes `dhcp.lan.dhcpv4_dnsmasq=disabled`. The precise semantics of `Mode == 1` and the transition back to `server` remain to be established.

## Additional service behavior

The init script performs a DHCP server collision check using `udhcpc` unless forced, stores results in `/var/run/dnsmasq.<interface>.dhcp`, and uses `/tmp/apmode` as part of AP-mode handling. Separate NAT-loopback logic in `liblanservices.so` contains an explicit `/etc/init.d/dnsmasq restart` call; it should not be assumed to be the standard DHCP reconfiguration path.
