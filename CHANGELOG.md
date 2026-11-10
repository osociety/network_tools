# Change Log

## 6.0.18
1. **Vendor table ships inside the package**: `hook/build.dart` and the `vendor_map.dart` stub are replaced by `vendor_index.data.dart` — the same 49,533 assignments as a packed binary index, gzipped into a Dart string literal. The first lookup decodes it, about 10 ms and 1.4 MB, and every lookup after that is a binary search. Nothing is generated while you build, so the 6.0.17 failure mode where a cold build raced the hook and compiled the empty stub is gone: vendor data needs no network access at build time and the first build of an app resolves vendors.
2. **Smaller app binaries**: on a Vernet macOS release build carrying the same data, the Dart AOT snapshot drops from 13.6 MB to 10.1 MB and the `.app` bundle from 32.6 MB to 29.2 MB. Against 6.0.16 the snapshot is 2.0 MB smaller while covering a third more assignments.
3. **Bigger install**: the published archive grows from 50 KB to 612 KB — the same trade, moved from build time to download time. The `hooks` dependency is dropped, and `configureNetworkTools(buildVendorTable: false)` now only skips the warm-up in isolates that never look a vendor up.
4. **One generator, drift-checked**: `tool/build_vendor_index.dart` replaces `tool/generate_vendor_map.dart` and the hook, and `test/vendor_index_parity_test.dart` rebuilds the index from the bundled IEEE CSV and compares it byte for byte, so the committed index cannot silently go stale. Replace the CSV, run the tool, commit both files.

## 6.0.17
1. **Longest-prefix vendor matching**: `ActiveHost.vendor` now resolves MA-M, MA-S and IAB blocks as well as MA-L. Lookups probe the most specific block first (9 hex digits, then 7, then 6), so a device in a sub-block is attributed to its own assignee instead of the `IEEE Registration Authority` entry registered for the parent block. Fixes #303.
2. **Smaller package, fuller table**: the generated table is no longer committed. `hook/build.dart` builds it at compile time from the IEEE CSV, and it now covers 49,533 assignments instead of 34,451. The published archive drops from 749 KB to 49 KB. Vendor data therefore needs network access at build time: a build that cannot fetch the CSV compiles against an empty table and resolves no vendors.

## 6.0.16
1. **IPv6 port scanning**: Port scanner now resolves and scans IPv6 addresses. Removed the IPv4-only DNS filter so both IPv4 and IPv6 hosts work.

## 6.0.15
1. **Device type inference**: Discovered devices now include an inferred type (Router, Printer, Switch, etc.) based on open port patterns. The `ActiveHost.deviceType` field is populated during TCP probing by analyzing which common service ports responded.
2. **CI/CD pipeline**: Releasing a new version now creates the git tag and GitHub release, then publishes to pub.dev automatically with tag-based OIDC authentication.

## 6.0.14
1. **TCP-connect sweep for cross-platform consistency**: Host discovery now uses TCP-connect probes to 14 common ports (21, 22, 23, 53, 80, 161, 443, 445, 631, 3389, 5900, 8080, 8443, 9100) instead of ICMP ping on all platforms. This ensures Android, iOS, macOS, Windows, and Linux discover the same devices.
2. **Bounded concurrency with platform-specific tuning**: Mobile platforms use 56 concurrent connections, desktop uses 96. Prevents network stack overload on mobile while maintaining fast scans on desktop.
3. **Smooth progress reporting**: Progress bar updates continuously from 0% to 100%. TCP phase covers 0-95%, ping fallback (if needed) covers 95-100%. Reports 0% immediately when scan starts to prevent frozen UI feeling.
4. **Two-phase discovery**: TCP-connect sweep runs first with bounded concurrency, then ICMP ping fallback for hosts that didn't respond to TCP. Both phases use the same concurrency limits.
5. **14-port TCP probe**: Discovers more device types by probing common service ports (FTP, SSH, Telnet, DNS, HTTP, SNMP, HTTPS, SMB, IPP, RDP, VNC, HTTP-Alt, HTTPS-Alt, Printer).
6. **Removed dead ARP code**: Cleaned up unused ARP table reading methods and simplified the discovery pipeline.
7. **Default timeout increased to 2s**: Catches slow-responding devices that were missed with the previous 1s timeout.
8. **mDNS merge by IP**: Devices found via mDNS are merged with TCP-discovered hosts by IP address, enriching device information.
9. **Unit tests added**: Tests for concurrency settings, progress callback behavior, and cross-platform consistency.

## 6.0.13
1. Build hook refined: removed unused `data_assets` dependency, added comprehensive tests for generated vendor map (6 new tests verifying structure, count, and known entries).
2. Hybrid approach for vendor map: committed minimal stub file that build hook replaces with full 34,451-entry map during `dart pub get`. Reduces repository size while ensuring package works immediately after cloning.

## 6.0.12
1. Isolate failures no longer hang a scan: `getAllPingableDevicesAsync` and `customDiscover(async: true)` spawn their isolate with error and exit ports, so an uncaught error or an early isolate exit surfaces to the caller instead of leaving the stream open forever.
2. Both isolate entry points now catch failures and report them, so a bad database directory or an unresolvable target arrives as an exception rather than a silent isolate death.
3. Added regression coverage for the async port scan failing on an unresolvable target.
4. MAC vendor lookup moved from runtime CSV download to compile-time generation: build hook downloads the vendor CSV during `dart pub get` and generates a const map with 34,451 entries, providing O(1) lookups without runtime network dependency. Removed SQLite vendor table and unused dependencies (csv, http, data_assets). SDK constraint upgraded to >=3.10.0 for build hooks support.

## 6.0.11
1. Much faster host discovery on Linux, macOS and Windows: the scanner primes the neighbour cache with UDP and reads the numeric ARP table once (`arp -an`, `/proc/net/arp`, numeric `arp -a`) instead of spawning a `ping` process per address. Hosts that ignore ICMP are still found, the device the scan runs on is included when it falls in the range, broadcast and multicast MAC rows are filtered out, and mobile platforms or non-local subnets fall back to the ICMP sweep.
2. Host names now resolve concurrently for the discovered hosts (250 ms budget during the scan, plus a lazy retry on first access) instead of relying on the serial reverse lookups `arp -a` performs. Networks without reverse DNS return no name, and `deviceName` falls back to mDNS, the ARP entry, then `Generic Device`.
3. `getAllPingableDevicesAsync` no longer builds the vendor table inside its isolate, removing a multi-second first-use vendor CSV download from the start of a scan. `configureNetworkTools` gained a `buildVendorTable` option for worker isolates.
4. Scan progress now reports 100 when discovery completes, including on the async API.
5. MAC vendor and ARP table failures are non-fatal: vendor CSV download/parse errors are logged and skipped, ARP command errors no longer abort host discovery, and MAC prefixes are normalized before lookup.
6. Faster scans: host details (hostname, MAC vendor, mDNS) resolve lazily, port scans use bounded concurrency (`maxConcurrency`, default 128), and subnet scans run in a single isolate.
7. Added database indexes for vendor and ARP lookups.
8. README updated with the current API, a working example (`example/main.dart`), the discovery and hostname behavior, mobile permission notes, and corrected Vernet repository and support/donate links.
9. Improved hostname and MAC vendor resolution for `vernet` issues #119 and #121.
10. Added regression tests, raising line coverage to 92%.

## 6.0.10
Bug fixes and improvements.

## 6.0.9
Bug fixes and improvements.

## 6.0.8
Fix for missing example tab.

## 6.0.7
Csv upgrade and downgrade fix.

## 6.0.6
Dependency update, bug fixes, example tab fix.

## 6.0.5
Bug fixes and improvements

## 6.0.4
Performance improvements

## 6.0.3
Bug fixes and performance improvements

## 6.0.2
Database error fix

## 6.0.1
Bug fix for windows

## 6.0.0
Performance improvement using drift database

## 5.0.6
mDNS search improvements

## 5.0.5
Fixed compatibility for web

## 5.0.4
Updated dependencies, added tests, and updated GHA.

## 5.0.3
Updated dependencies

## 5.0.2
1. Bug for other languages on Windows fixed by codepage.
2. Added mac address option to ActiveHost constractor.

## 5.0.1
1. Bug fixes and improvements

## 5.0.0
1. Added hostIds list parameter to restrict scan to only these ids.
2. Breaking changes on calling static methods. You have to use instance of service now.

**Breaking change** Replace these occurences in your project

    * HostScanner to HostScannerService.instance
    * PortScanner to PortScannerService.instance

## 4.0.4
1. Bug fix for sync runs when async flag is true

## 4.0.3
1. scanPortsForSingleDevice and customDiscover supports async mode now.

## 4.0.2
1. Separated logs for example and library

## 4.0.1
1. Fixed path problem for dart and flutter sdk

## 4.0.0
### Breaking changes

1. Call configureNetworkTools in your main function


## 3.2.7

1. Removed example folder and added pubignore.
2. Added vendor details but database looks old. 
3. More results are added using ARP on Lin/Mac/Win.

## 3.2.6

1. Added mac address support on Desktop (Linux, macOS, and Windows)

## 3.2.5

1. Bug fix for iOS listing all results in HostScanner

## 3.2.4

1. Bug fixes and improvements. Better code coverage reports.

## 3.2.3

1. Upgraded dependencies and improved pub score, moved network_tools_flutter to new repo

## 3.2.2

1. Supporting changes for network_tools_flutter

## 3.2.1

1. Now GHA runs tests against 3 platforms windows, ubuntu, macos
2. Code coverage is fixed so that it's visible in codecov portal.

## 3.2.0

1. getAllPingableDevicesAsync runs inside isolate to find all devices in a network.
2. Bug fixes and improvements

## 3.1.0

Web Support and bug fixes for mDns devices giving error in getting IP

## 3.0.0+3

Refactoring for field names

## 3.0.0+2

This release is only meant to test Github Actions for Dart Package publishing. It's same as v3.0.0. Nothing changed.

## 3.0.0+1

This release is only meant to test Github Actions for Dart Package publishing. It's same as v3.0.0. Nothing changed.

## 3.0.0

**Breaking change** Change most of the methods names

    * HostScanner.discover to HostScanner.getAllPingableDevices
    * HostScanner.discoverPort to HostScanner.scanDevicesForSinglePort
    * PortScanner.discover to PortScanner.scanPortsForSingleDevice

Ip field in ActiveHost is now InternetAddress type instead of string which improve handling of IPv6.

ActiveHost now contains host name of the address if exist.

Better naming of methods

Bug fixes and improvements

## 2.1.0

Added partly support for searching mdns devices.

## 2.0.0

**Breaking change** Bump minimum dart version to 2.17.0.

Updated dart_ping package version to 7.0.1.

Updated test package version to 1.21.4.

## 1.0.8

Fixes

Add logs using logging package #13.

Even more points in pub.dev page #20.

## 1.0.7

Fixed

Saving the response time from each device #9.

Example crash on Windows #14.

Bump package version #15.

## 0.0.6

Resolved issue #9 and #10.

## 0.0.5

Resolved issue #1.

## 0.0.4

Single and Custom Port Scan added.

## 0.0.3

Subnet and Port range added.

## 0.0.2

Added example and followed pub conventions.

## 0.0.1

PortScanner and HostScanner.
