# F-001 — Aggregate UCI commit may report success after partial failure

**Component:** `liblanservices.so`  
**Function:** `libucihelper_UCICommit()`  
**Status:** Static finding; runtime reproduction pending  
**Security severity:** Undetermined

## Evidence

For a null or `all` argument, the wrapper enumerates UCI configurations, initializes an aggregate status to `-1`, and sets it to `0` whenever **any** individual `uci_commit()` succeeds. The code does not reset it after a later failure.

```c
status = -1;
for (each_config) {
    if (uci_lookup_ptr(...) == 0) {
        if (uci_commit(...) == 0)
            status = 0;
    }
}
return status;
```

This is an explanatory simplification, not verbatim firmware source.

## Consequence

A successful commit of one package can mask the failure of another. For example, success for `network` followed by failure for `dhcp` can still produce an overall success status.

The DHCP configuration writer uses `libucihelper_UCICommit(NULL)` and does not inspect the return value in the reviewed paths, further reducing error visibility.

## Verification needed

- Cross-check the branches and status assignments in MIPS assembly.
- Reproduce with isolated or stubbed UCI operations and a controlled mix of success and failure.
- Determine whether and how such partial failure could affect DHCP in practice.

## Suggested remediation

Preserve the first failure or aggregate all failures; return success only if every required commit succeeds. Check the result at call sites.
