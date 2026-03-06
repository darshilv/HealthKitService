# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HealthKitService is a Swift package that provides a protocol-based wrapper around Apple's HealthKit framework for iOS and macOS. It simplifies workout tracking and health data management.

- **Languages**: Swift
- **Package Manager**: Swift Package Manager (SPM)
- **Minimum Deployments**: iOS 18, macOS 14
- **Swift Version**: 6.0+

## Building and Testing

### Build the Package

```bash
# Build the library
swift build

# Build with optimizations (release mode)
swift build -c release
```

### Run All Tests

```bash
# Run all tests
swift test

# Run tests with verbose output
swift test --verbose

# Run a specific test target
swift test --filter HealthKitServiceTests
```

### Run Individual Tests

```bash
# Run a specific test class
swift test --filter HealthKitManagerTests

# Run a specific test method
swift test --filter HealthKitManagerTests.testBeginAndEndWorkout_doesNotThrow
```

### Clean Build Artifacts

```bash
# Remove build artifacts
rm -rf .build
```

## Architecture Overview

### Core Design Pattern

The project uses **protocol-based abstraction** to define health kit capabilities:
- `HealthKitWorkoutTracking` protocol in `Sources/Interfaces/` defines the contract for workout operations
- `HealthKitManager` in `Sources/` implements this protocol and wraps Apple's HealthKit APIs

### Project Structure

```
Sources/
├── HealthKitManager.swift          # Main implementation of workout tracking
├── Interfaces/
│   └── HealthKitWorkoutTracking.swift   # Protocol defining workout operations
└── Models/
    └── PracticeSummary.swift       # Data model for workout summaries

Tests/
└── HealthKitServiceTests/
    └── HealthKitManagerTests.swift  # Unit tests for HealthKitManager
```

### Key Components

- **HealthKitManager**: Main public class that handles:
  - Authorization requests for HealthKit access
  - Workout lifecycle management (begin, pause, resume, end)
  - Energy expenditure tracking (kilocalories)
  - Uses `HKWorkoutBuilder` for building and saving workouts to HealthKit

- **HealthKitWorkoutTracking**: Protocol defining the public async interface for workout operations

- **PracticeSummary**: Data model representing a completed workout session with timestamps and energy burned

### Async/Await Pattern

The codebase uses Swift's async/await for asynchronous operations, particularly:
- Authorization requests to HealthKit
- Workout builder operations
- Custom `addSampleAsync` helper that bridges HealthKit's callback-based API to async/await using `withCheckedThrowingContinuation`

### Current Limitations

- Pause/resume functionality is declared but not yet implemented
- Currently hardcoded to yoga activities and indoor location
- No read queries from HealthKit (only write operations)

## Development Notes

- The package uses `@testable` imports for unit testing internal components
- HealthKit authorization must be requested before any workout operations
- The `HKWorkoutBuilder` pattern ensures workouts are properly saved with start/end times and energy data
- New health data types can be added by extending the authorization request and builder sample operations

## Git Conventions

- **Commit messages**: Do NOT include Co-Authored-By or other third-party footers in commits
- Keep commits focused on a single logical change
- Use clear, descriptive commit messages that explain the "why" not just the "what"
