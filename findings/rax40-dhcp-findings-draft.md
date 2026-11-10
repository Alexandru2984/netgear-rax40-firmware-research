# NETGEAR RAX40 — DHCP implementation findings (draft)

**Target:** NETGEAR RAX40 firmware `V1.0.6.106_1.0.1` (confirm image provenance and hashes before publication)  
**Analysis method:** Offline static reverse engineering of extracted MIPS32 big-endian ELF binaries in Ghidra, together with the extracted NETGEAR web resources.  
**Status:** Research draft. No finding below is represented as an exploited vulnerability, an assigned CVE, or a confirmed root cause of the observed DHCP outage.

## Observed incident (not yet causally attributed)

During a router incident, DHCP clients sent `DHCPDISCOVER` but no `DHCPOFFER` was observed; clients fell back to link-local `169.254.x.x` addresses. Manually assigned LAN addresses worked. Re-running the NETGEAR setup wizard restored DHCP service. The contemporaneous CAL, SERVD, UCI, and dnsmasq states were not captured, so this incident cannot currently be attributed to any specific code defect below.

## Verified component path

- `LAN_lan.html` submits `POST /lan.cgi` with `lan_proto=dhcp` or `lan_proto=static`, along with `dhcp_start`, `dhcp_end`, and other fields.
- `lighttpd4.conf` routes `.cgi` requests through `/opt/vendor/www2/cgi/pucgi`.
- The `pucgi` routing table at approximately `0x0008e154` associates `/LAN_lan.html` and `/lan.cgi` with GET `FUN_00033160`, POST `FUN_00033298`, output `FUN_00033f00`, and cleanup `FUN_000345c4`.
- `pucgi` dynamically depends on `libpulapi.so`. The LAN POST handler calls `PulapiCheckObjSet_Lan_DhcpSetting` and, in a forked child, `PulapiSetObj_Lan_DhcpSetting`.
- `libpulapi.so` accesses CAL objects under `Device.DHCPv4.Server` and `Device.DHCPv4.Server.Pool`. The precise mapping of CAL writes to SERVD notifications and final UCI/dnsmasq state still requires verification.

## DHCP-01 — Unreported DHCP apply failures across a `fork()` boundary

**Category:** Functional reliability / error handling  
**Static evidence:** Confirmed  
**Live reproduction:** Not performed  
**Suggested priority:** Medium

**Relevant functions:** `pucgi` `FUN_00033298` (`CGIPOST_LAN_lanSetup`); `libpulapi.so` `PulapiSetObj_Lan_DhcpSetting`.

After validating the request, the POST handler calls `fork()`. The child calls `PulapiSetObj_Lan_IpSetting(3, ...)`, sleeps three seconds, and conditionally calls `PulapiSetObj_Lan_DhcpSetting(3, ...)`. The child subsequently calls `exit(0)` even when a setter returns a non-success status. The parent independently displays `CgiShowProcessBar(...)` without waiting for or receiving the child's result; `fork() == -1` is not explicitly handled in the observed branch.

**Consequence:** An accepted Apply operation may present a progress screen despite failure to apply DHCP settings. This is an observable gap in final-result reporting, not proof that every Apply fails or that the UI explicitly displays a success confirmation.

**Evidence to retain:** Ghidra export of the POST handler around `fork`, both setter calls, `exit(0)`, `CgiShowProcessBar`, and the final return path.

**Suggested remediation:** Send the child result to the request-status mechanism (or an asynchronous operation status endpoint), represent failed operations distinctly, and handle `fork()` failures. Do not unconditionally exit with success when configuration fails.

## DHCP-02 — LAN DHCP setter cannot recover when no active pool is returned

**Category:** Functional recovery / configuration consistency  
**Static evidence:** Confirmed for the analyzed path  
**Live reproduction:** Not performed  
**Suggested priority:** Medium

**Relevant functions:** `libpulapi.so` `PulapiGetObj_Lan_DhcpSetting` (`0x3f870`), `PulapiSetObj_Lan_DhcpSetting` (`0x3fb08`).

The getter retrieves `Device.DHCPv4.Server.Pool`, counts pools whose `Enable` value begins with `true` or `1`, and can return a success result with `count == 0`. The setter proceeds with CAL mutation only when `*local_110 == 1`. Thus, a request through the LAN setter does not directly re-enable a pool when its getter returns no enabled pool. In the successful update branch the setter writes `Device.DHCPv4.Server.Enable`, optionally `Device.DHCPv4.Relay.Enable=0`, and the selected pool's `MinAddress`/`MaxAddress`, but does not explicitly add `Device.DHCPv4.Server.Pool.<n>.Enable=1`.

**Consequence:** There is no recovery path in this setter alone for the zero-enabled-pool state. Whether another service independently repairs the state is unverified.

**Important limitation:** The page-render path may itself fail under `count == 0` (see DHCP-03). It is therefore not established that a user can always reach the Apply button normally in this state.

**Suggested remediation:** Make the desired pool's enabled state explicit in the update operation and handle zero-pool states as an expected configuration condition rather than an implicit no-op.

## DHCP-03 — Potential invalid dereference in LAN page rendering with zero enabled pools

**Category:** Memory safety / availability  
**Static evidence:** Conditional path identified  
**Live reproduction:** Not performed  
**Suggested priority:** High for validation, not a confirmed remotely exploitable issue

**Relevant functions:** `libpulapi.so` `PulapiGetObj_Lan_DhcpSetting`, `pucgi` `FUN_00033160` and `FUN_00033f00`.

When the getter finds zero enabled pools, it allocates an 8-byte header, writes `count=0` into its first word, and returns it without initializing the second word (the entries pointer). `FUN_00033160` treats a successful getter result as sufficient for page setup. During expansion of `GetPageCfg("lan_proto")`, `FUN_00033f00` uses the entries pointer at header offset `+4` and reads the `+0xd0` field of its first entry, without a visible `count > 0` check.

**Consequence:** The zero-enabled-pool state can lead to a dereference through an uninitialized pointer during page rendering, depending on the actual rendered paths and runtime memory contents. This requires controlled confirmation; impact beyond a process fault is not established.

**Excluded false positive:** `PulapiFreeObj_Lan_DhcpSetting` checks `*param_1 != 0` before freeing the entries pointer. Thus the same uninitialized field does **not** by itself demonstrate an invalid free in the `count=0` cleanup path.

**Suggested remediation:** Zero-initialize the header; initialize `entries=NULL` when `count=0`; check `count` and `entries` at every use site; show an explicit no-active-pool state in the page.

## DHCP-04 — Unbounded CAL strings copied into 24-byte stack arrays

**Category:** Memory safety / bounds checking  
**Static evidence:** Bounds defect visible in decompiled code  
**Source-data reachability:** Unknown  
**Suggested priority:** High for validation; no CVSS assigned

**Relevant function:** `libpulapi.so` `FUN_0004d544`, called from `PulapiGetObj_Lan_DhcpSetting`.

The helper allocates `char local_128[24]` and `char local_110[24]` for pool addresses. For each string sourced from CAL, it performs a copy with a length derived solely from `strlen(source)`, then writes a NUL at index `strlen(source)`:

```c
size_t n = strlen(source);
strncpy(local_128, source, n);
local_128[n] = '\0';
```

A source string of 24 or more bytes would exceed the destination capacity (including the terminator). The code path does not itself clamp the length to 23.

**Limitations:** A valid IPv4 address is shorter than the destination. The LAN CGI handler performs IPv4 validation, and `Pulapi_Common_CheckStr` is used in an additional validation layer. Whether an attacker, another management interface, or a corrupted CAL database can supply an overlong value is not established. No claim of remote code execution is made.

**Suggested remediation:** Validate CAL schema values at entry and use fixed-capacity copy logic based on `sizeof(destination)`, rejecting overlong strings rather than truncating silently.

## DHCP-05 — Inconsistent interpretation of textual `true` for global DHCP server enable

**Category:** Logic / input normalization  
**Static evidence:** Confirmed from branch logic  
**Web UI reachability:** Unverified  
**Suggested priority:** Medium

**Relevant function:** `liblanservices.so` `FUN_00014bf0`, logged as `dhcp_handleServerRelayEnable`.

When `gServerStatus == 0` and the input for `Device.DHCPv4.Server.Enable` is the literal string `true`, `atoi("true")` returns `0`. The first branch additionally requires `gServerStatus == 1` to accept a true-like value as already enabled; the next branch can skip activation because it also sees a numeric zero. Consequently, the server is not activated on this path. The literal `1` takes a different branch and can enable the server. Other invalid textual values may cause unintended transitions.

**Limitations:** The NETGEAR `LAN_lan.html` POST transmits `lan_proto=dhcp` or `static`; its backend converts this into numeric `1` or `0` for the global Server Enable field. There is no proof that the public LAN UI can reach the text-`true` case.

**Suggested remediation:** Parse the Enable field into a strict boolean once, reject unknown values, and apply a single state-transition routine for server and relay.

## DHCP-06 — Getter result unchecked before dereference in DHCP setter

**Category:** Memory safety / error handling  
**Static evidence:** Conditional path identified  
**Suggested priority:** Medium for validation

**Relevant functions:** `PulapiSetObj_Lan_DhcpSetting`, `PulapiGetObj_Lan_DhcpSetting`.

The setter invokes `PulapiGetObj_Lan_DhcpSetting(&local_110)` without checking the boolean result and then dereferences `*local_110`. The getter can fail (e.g., on allocation failure or database retrieval errors) without necessarily assigning a valid output pointer. The local variable is not visibly initialized before the call.

**Consequence:** Potential invalid pointer dereference on getter failure. Verify exact MIPS assembly and the getter's failure contract before treating it as a reproducible crash.

**Suggested remediation:** Initialize the output pointer to `NULL` and abort if the getter fails, before any dereference.

## Additional observation — State updates despite failed configuration retrieval

In `liblanservices.so` `dhcp_handleServerRelayEnable`, the server-enable path logs a nonzero result from `dhcp_getCfgFromDbObj`, but still assigns `gServerStatus=1` and the pool enable byte to `1`. The error may still be propagated to the caller. This creates an observable partial-state-update condition, but downstream effects and severity are not established.

## Follow-up validation order

1. **Confirm zero-pool rendering behavior**: inspect the exact disassembly of the `FUN_00033f00` `lan_proto` dereference and the getter's `count=0` return path; use an isolated firmware test environment if a dynamic reproduction is possible.
2. **Establish CAL input length controls**: inspect `Pulapi_Common_CheckStr`, CAL schema restrictions, and any other write path for `MinAddress`/`MaxAddress`. Preserve raw instructions for the copy sites in `FUN_0004d544`.
3. **Confirm asynchronous Apply status**: inspect the handler's `fork()` and return paths in disassembly; test only in an isolated setup with explicit observation of child failure and parent response.
4. **Determine SERVD/UCI propagation**: trace `cal_setValue` -> service notification -> `liblanservices.so` -> UCI/dnsmasq; avoid assuming all CAL setters execute the same runtime path.
5. **Correlate with the outage** only if contemporaneous state, logs, or a controlled reproduction can support attribution.

## Publication guidance

- Distinguish **code-level confirmed** behavior from **runtime reproduced** behavior and **externally reachable** vulnerabilities.
- Do not attach a CVE, CVSS score, or exploitability claim without substantiation.
- Preserve firmware image hash, rootfs extraction command, Ghidra project settings (ELF32, MIPS32r2, big-endian), relevant function offsets, and minimal code excerpts in the evidence package.
- Treat this document as an internal draft until each claim has been reviewed against disassembly and the final public wording is approved.
