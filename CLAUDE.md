# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter application named `perch_care`. The project is currently in its initial setup phase with the default Flutter template structure.

## Development Commands

### Package Management
- `flutter pub get` - Install dependencies
- `flutter pub upgrade` - Upgrade dependencies to latest compatible versions
- `flutter pub outdated` - Check for newer versions of dependencies

### Running the Application
- `flutter run` - Run the app in debug mode on connected device/emulator
- `flutter run -d <device_id>` - Run on specific device
- `flutter run --release` - Run in release mode

### Development Tools
- `flutter analyze` - Run static analysis on Dart code (uses `analysis_options.yaml`)
- `flutter test` - Run all tests in `test/` directory
- `flutter test test/widget_test.dart` - Run a specific test file

### Build Commands
- `flutter build apk` - Build Android APK
- `flutter build ios` - Build iOS app (requires macOS)
- `flutter build web` - Build web application
- `flutter build macos` - Build macOS application

### Other Useful Commands
- `flutter clean` - Remove build artifacts and cache
- `flutter doctor` - Check environment and display report of Flutter installation
- `flutter devices` - List all connected devices

## Code Architecture

### Current Structure
- **lib/main.dart** - Application entry point with `MyApp` root widget and `MyHomePage` stateful widget (basic counter demo)
- **test/widget_test.dart** - Widget tests for the main application

### Flutter Specifics
- SDK: `^3.8.1`
- Linting: Uses `flutter_lints: ^5.0.0` with configuration in `analysis_options.yaml`
- Material Design is enabled via `uses-material-design: true`
- Icons: Cupertino Icons package included

### Platform Support
The project is configured for multi-platform deployment:
- iOS (`ios/`)
- Android (inferred from Flutter project structure)
- macOS (`macos/`)
- Web (`web/`)

## Testing

Widget tests use the `flutter_test` package. The test pattern follows:
1. Build widget with `tester.pumpWidget()`
2. Verify initial state with `expect()` and `find` matchers
3. Trigger interactions with `tester.tap()` or similar
4. Pump frames with `tester.pump()` to apply changes
5. Verify updated state
