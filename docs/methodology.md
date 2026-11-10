# Research methodology

## Firmware provenance

Firmware under examination: `RAX40-V1.0.6.106_1.0.1.zip`, obtained from the vendor's firmware distribution. Recorded archive SHA-256 during the investigation:

`e91470e1d264536edaf06732de8c552753908e247c03f98f769faf9a5eb016cf`

Verify any newly downloaded archive independently. This hash is provided only to identify the investigated archive, not as an authenticity guarantee.

## Extraction notes

The firmware image was unpacked locally. Binwalk reported a SquashFS (XZ) filesystem at offset `209` (`0xD1`). One successful local extraction procedure was:

```bash
unsquashfs -o 209 -d extracted/rootfs \
  firmware/unpacked/RAX40-V1.0.6.106_1.0.1.img
```

The root filesystem contained MIPS32r2 big-endian userland binaries. Stripped ELF shared objects often lack useful section headers; `readelf -D -sW` and `readelf -D -rW` were useful for dynamic symbols and relocations.

## Analysis workflow

1. Verify downloaded firmware and retain the original privately.
2. Extract the root filesystem locally without altering any connected router.
3. Examine service configuration and scripts before investigating native binaries.
4. Import relevant binaries into Ghidra; record both ELF addresses and Ghidra load bases.
5. Identify candidate code paths through dynamic symbols, string references, and surrounding disassembly.
6. Validate decompiler interpretations in assembly where the result is security-sensitive.
7. Record reachability and runtime reproduction separately from static observations.

## Evidence tiers

- **Observed:** Directly captured on the local network or read from the firmware image.
- **Static finding:** Supported by a specific decompiled control flow; may still require assembly confirmation.
- **Hypothesis:** Plausible interpretation lacking a demonstrated trigger or runtime trace.
- **Validated:** Reproduced under controlled conditions with recorded inputs, outputs, and impact.

## Limitations

Ghidra decompilation can misidentify types, buffers, branches, and calling conventions. Dynamic link references may not appear in ordinary string cross-reference searches on position-independent MIPS binaries. Avoid deriving exploitability from an individual function without reviewing callers and input constraints.
