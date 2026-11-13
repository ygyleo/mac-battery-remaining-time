# Native charging bridge verification

Checked on 2026-11-14, Apple Silicon, macOS 27.2.1 (26B131).

The bridge loads the system PowerUI framework only when state is requested. It checks the Objective-C return type, argument count, and every argument type before calling a private selector. Manual Charge Limit is considered only on macOS 26.4 or newer. Missing or incompatible interfaces do not permit a charging request.

A read-only executable compiled directly from `Sources/ChargingBridge/ChargingBridge.m` and its public header called `BTChargingClient.readStateWithError:`. It reported:

```text
optimizedSupported=1 manualSupported=1 optimizedOverrideAllowed=0 manualEnabled=0 manualLimit=100
```

This confirms runtime loading, ABI checks, and native state reads on this machine. The probe did not invoke either charging action. The machine was not in an optimized-charging hold or at a manual charge limit, so actual resumed charging and subsequent limit restoration have not been tested here.

Ten fake-client tests cover state reads without writes, an accepted optimized-charge request, a manual-limit request when the OBC override flag is false, state changes before a request, a manual limit becoming active before an optimized-charge request, unknown manual-limit state, missing or incompatible methods, preserved read/write errors, and the older OBC query shape. The tests never instantiate the system client. The initial stub and the mode-change regression both failed before their fixes; the implemented bridge passed all ten.

The native write paths are `temporarilyEnableCharging:` for optimized charging and `temporarilyDisableMCL:` for a manual limit. Calls are restricted to explicit user actions after a fresh state read. There are no SMC writes, root helper, automatic retries, or charge-limit restoration writes.

These interfaces are private and can change with macOS. Apple's [charging documentation](https://support.apple.com/en-hk/102338) describes the native user action. Independent [macOS 27.2 observations](https://github.com/lingyired/status-trio/blob/main/docs/charge-to-full-now-poc.md) report that the native manual-limit override can leave the setting at 100% after charging finishes or the cable is reconnected. This app does not promise automatic restoration.

Release 1.2.0 verification: all 45 Swift package tests passed (17 battery-core, 18 app/controller/menu, 10 bridge). The arm64 Release build, ad hoc signature verification, and DMG checksum verification passed. The installed settings window retained the user's three preferences. These checks do not establish real charging behavior while protection is active, or runtime compatibility on older macOS versions.
