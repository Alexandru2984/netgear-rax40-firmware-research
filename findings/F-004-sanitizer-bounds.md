# F-004 — Oversized UCI input can cause a stack out-of-bounds read

**Component:** `liblanservices.so`  
**Function:** `libucihelper_sanitizeInput()`  
**Status:** Static finding; input reachability and runtime impact unknown  
**Security severity:** Undetermined

## Evidence

The decompiled function allocates `local_42c[1024]`, measures the original input length with `strlen()`, and copies at most `0x3ff` (1,023) bytes with `strncpy()` after zero-initializing the local buffer.

It subsequently loops up to the **original** input length and reads `local_42c[index]`. If the input contains at least **1,025 bytes** before its terminating NUL, this indexing proceeds past the 1,024-byte local buffer.

The function also clears the original mutable input and reconstructs it while omitting characters not on an allowlist. It returns `void` and does not indicate if content was removed.

## Impact and constraints

This is an out-of-bounds **read**, not evidence of an out-of-bounds write or immediate remote code execution. Exact consequences depend on the stack layout and the caller. Many reviewed call sites build UCI strings in buffers capped at roughly 256 bytes, so reachability from a remote/user-controlled interface has **not** been established.

The allowlist includes `@`, `[`, `]`, and `\\`; UCI selectors such as `@host[0]` are not inherently stripped.

## Required validation

- Confirm the indexed read in the MIPS assembly.
- Enumerate callers of `libucihelper_UCISet()` and the maximum input length along each path.
- If an oversized path exists, reproduce in a local isolated test harness rather than against production equipment.

## Suggested remediation

Cap processing at the actual copied length, reject oversized input explicitly, avoid silent character deletion when validation is intended, and return a status that callers must check.
