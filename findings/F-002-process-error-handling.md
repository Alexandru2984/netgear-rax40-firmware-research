# F-002 — Process-management error reporting inconsistencies

**Components:** `libscapi.so`, `libnetwork.so`, `liblanservices.so`  
**Functions:** `scapi_spawn()`, `dnsmasq_start()`, `dnsmasq_stop()`  
**Status:** Static finding; runtime reproduction pending  
**Security severity:** Undetermined

## Evidence

`scapi_spawn(command, 1, &exit_status)` forks, runs a command via `execl()` in the child, and waits using `waitpid()` in the parent. On normal child exit, it writes the normalized exit code to the supplied pointer.

The reviewed `dnsmasq_start()` and `dnsmasq_stop()` wrappers treat `scapi_spawn(...) == 0` with `exit_status <= 127` as success. Consequently, a command exiting normally with status `1` through `127` can be reported as successful.

Both wrappers also return success when opening `/etc/init.d/dnsmasq` fails, without attempting the command.

In the decompiled `scapi_spawn()` implementation, a failed `waitpid()` may be followed by a check of the zero-initialized status, overwriting the error with success. After `execl()` failure, the child appears to `return` instead of calling `_exit()`. The latter requires assembly and call-context validation.

## Limitations

The dnsmasq init script may itself mask internal errors. These code paths do not prove they caused the observed DHCP incident or represent remotely exploitable vulnerabilities.

## Suggested remediation

- Require a zero exit status for success.
- Treat `waitpid()` failure and signal termination as failures.
- Have the forked child exit explicitly if `execl()` fails.
- Preserve and propagate failures when init scripts cannot be accessed.
