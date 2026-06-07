---
name: network-tools-helper
description: Orchestrates Dart and Flutter tasks in the network_tools repository, including running tests, running build_runner, resolving analyzer warnings, and applying formatting.
---
# Network Tools Repo Helper Skill

This skill provides comprehensive, step-by-step instructions for managing tasks, testing, static analysis, code formatting, and code generation in the `network_tools` Dart/Flutter repository. Any agent working on this repository MUST follow these steps exactly to ensure no steps are missed.

---

## 🚨 MANDATORY EXECUTION WORKFLOW FOR AGENTS

When assigned any task in this repository (e.g. implementing features, refactoring, or fixing tests), you **MUST** execute the following sequence in order:

### Step 1: Establish Baseline
Before making any changes, run the analyzer and tests to understand the current state:
```bash
dart analyze
dart test
```

### Step 2: Implement Changes
Write the code, test fixes, or feature implementations.

### Step 3: Run Code Generation (If Applicable)
If your changes affect dependencies (`get_it` annotations), database models (`drift`), or JSON serialization, run the code generator:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Step 4: Run Code Formatter
You **MUST** format all files in the repository before verifying or committing. Unformatted code will fail CI:
```bash
dart format .
```

### Step 5: Verify Static Analysis (Zero Warnings Rule)
Run the analyzer again. The repository enforces a **zero analyzer warnings** policy. You must resolve all errors, warnings, and hints:
```bash
dart analyze
```

### Step 6: Verify Tests
Run the test suite to ensure the changes are correct and did not introduce regressions:
```bash
dart test
```
If specific tests fail, rerun only that test file to debug rapidly:
```bash
dart test test/path/to/test_file_test.dart
```

---

## 🛠 COMMON ISSUES & BEST PRACTICES

### 1. Database Locking in Tests
The database is initialized via `configureNetworkTools()`. Parallel test execution on local machines and CI can cause `database is locked` errors if tests share the same database directory.
*   **Rule**: Always use a unique directory for each test file setup:
    ```dart
    final testDbDir = 'build/test_db_mdns_impl_${pid}_${DateTime.now().millisecondsSinceEpoch}';
    await configureNetworkTools(testDbDir);
    ```

### 2. Network & mDNS Unit Tests
Real mDNS lookups (`MDnsClient`) require active network interfaces and support for multicast. On CI runners (like GitHub Actions `macos-latest`), it is common to have no routing for `0.0.0.0:5353`, causing `SocketException: Send failed (OS Error: No route to host)`.
*   **Implementation Rule**: Always wrap the lookup loops and client startups inside `findingMdnsWithAddress` in a `try-catch-finally` block to log errors gracefully and ensure `client.stop()` is called.
*   **Test Rule**: Never let tests trigger real network mDNS lookups. In unit tests for method signatures or configuration, mock the lookup mechanism by subclassing/stubbing `MdnsScannerServiceImpl` to return `[]` immediately:
    ```dart
    class MockMdnsScannerServiceImpl extends MdnsScannerServiceImpl {
      @override
      Future<List<ActiveHost>> findingMdnsWithAddress(String serviceType) async {
        return [];
      }
    }
    ```
*   **Async Rule**: Ensure all async calls (like `searchMdnsDevices()`) are fully awaited (`await expectLater(..., completes)`) in the test. Leaving unawaited futures in tests leads to unhandled exceptions and background socket leakage after the test suite finishes.
