# Neural LoopTests

## Overview
`Neural_LoopTests.swift` holds the test target for the iOS scheme. It currently bundles a single async stub test using the `Testing` package and can be expanded as the feature set grows.

## Current coverage
- `Neural_LoopTests.swift` defines `Neural_LoopTests` with an example `@Test` placeholder. Use `#expect(...)`, numeric assertions, or real expectations against `UnifiedDataModel` + services once more behavior is defined.

## How to add tests
1. Import the same dependencies your production files use (SwiftUI, supabase helpers, etc.).
2. Annotate functions with `@Test` and use `async throws` to interact with the unified data/notification services.
3. Run the `Neural Loop` scheme tests to ensure the new cases are exercised.

## Build & test guidance
- The test target runs as part of the `Neural Loop` scheme. Execute `xcodebuild -scheme "Neural Loop" test` (or run the scheme in Xcode) to get automated results.

## Automation reminder
Tests should only be verified through the automated pipeline described above; manual verification is explicitly outside the current workflow.

