# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**perch_care** is a Flutter application with a custom design system and navigation architecture. The project uses go_router for navigation and implements a comprehensive theming system with Material 3.

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
- `flutter analyze` - Run static analysis on Dart code
- `flutter test` - Run all tests
- `flutter test test/widget_test.dart` - Run a specific test file

### Build Commands
- `flutter build apk` - Build Android APK
- `flutter build ios` - Build iOS app (requires macOS)
- `flutter build web` - Build web application
- `flutter build macos` - Build macOS application

### Other Commands
- `flutter clean` - Remove build artifacts and cache
- `flutter doctor` - Check environment status
- `flutter devices` - List all connected devices

## Code Architecture

### Navigation (go_router)
The app uses **go_router** for declarative routing with the following structure:
- **[app_router.dart](lib/src/router/app_router.dart)** - Central router configuration with GoRouter instance
- **[route_names.dart](lib/src/router/route_names.dart)** - Route name constants (used for named navigation)
- **[route_paths.dart](lib/src/router/route_paths.dart)** - Route path constants (URL paths)

Initial route is `/` (splash screen), which auto-navigates to `/login` after animation completes.

### Theme System
Comprehensive design system with Material 3:
- **[app_theme.dart](lib/src/theme/app_theme.dart)** - Main theme configuration (light/dark themes, Material 3 component themes)
- **[colors.dart](lib/src/theme/colors.dart)** - Brand colors (`#FF9A42`), gradients, grayscale palette
- **[typography.dart](lib/src/theme/typography.dart)** - Text styles (h1-h6, body, label variants)
- **[radius.dart](lib/src/theme/radius.dart)** - Border radius constants
- **[spacing.dart](lib/src/theme/spacing.dart)** - Spacing constants
- **[shadows.dart](lib/src/theme/shadows.dart)** - Box shadow definitions
- **[icons.dart](lib/src/theme/icons.dart)** - Icon constants

Access theme values via `Theme.of(context)` or directly via static constants (e.g., `AppColors.brandPrimary`).

### Screen Architecture
Screens are located in `lib/src/screens/` with the following structure:
- **[splash_screen.dart](lib/src/screens/splash/splash_screen.dart)** - Animated splash with concentric circles using `AnimationController` and `Interval` curves, auto-navigates to login
- **[login_screen.dart](lib/src/screens/login/login_screen.dart)** - Login UI with draggable bottom sheet, uses absolute positioning for layout elements

Both screens use `flutter_svg` for SVG assets and implement responsive sizing based on screen dimensions.

### Entry Point
**[main.dart](lib/main.dart)** - App initialization with `MaterialApp.router`, theme configuration, and router setup.

## Key Dependencies
- **go_router: ^14.6.2** - Declarative routing
- **flutter_svg: ^2.0.10+1** - SVG rendering
- **cupertino_icons: ^1.0.8** - iOS-style icons

## Assets
Assets are configured in `pubspec.yaml`:
- `assets/images/` - Main images directory
- `assets/images/login_vector/` - Login screen vectors

SVG files are loaded via `SvgPicture.asset()` and PNG via `Image.asset()`.
