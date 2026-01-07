# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**perch_care** is a Flutter application for pet health management with AI-powered health checks and weight tracking. The project uses go_router for navigation, implements a comprehensive Material 3 design system, and integrates with Supabase for backend services.

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

### Backend Integration (Supabase)
The app uses Supabase for authentication and backend services:

#### Environment Configuration
- **[environment.dart](lib/src/config/environment.dart)** - Environment variable accessor that reads from `.env`
- **[app_config.dart](lib/src/config/app_config.dart)** - App-wide configuration constants
- Environment variables are loaded in `main()` using `flutter_dotenv`
- Required environment variables: `SUPABASE_URL`, `SUPABASE_ANON_KEY`

#### Setup Requirements
1. Copy `.env.example` to `.env` and fill in Supabase credentials
2. Supabase is initialized in `main()` before app starts
3. Missing environment variables will throw `StateError` at runtime
4. See [docs/backend/setup_supabase.md](docs/backend/setup_supabase.md) for detailed setup instructions

#### Authentication
- **[auth_service.dart](lib/src/services/auth/auth_service.dart)** - Wrapper around Supabase auth APIs
- Supports email/password signup and OAuth (Google, Apple)
- Deep link scheme: `perchcare://auth-callback` (configured for all auth methods)
- Platform-specific deep link configuration required in iOS/Android manifests

### Screen Architecture
Screens are located in `lib/src/screens/` with the following structure:

#### Authentication Flow
- **[splash_screen.dart](lib/src/screens/splash/splash_screen.dart)** - Animated splash with concentric circles using `AnimationController` and `Interval` curves, auto-navigates to login
- **[login_screen.dart](lib/src/screens/login/login_screen.dart)** - Login UI with draggable bottom sheet, uses absolute positioning for layout elements
- **[signup_screen.dart](lib/src/screens/signup/signup_screen.dart)** - User registration screen

#### Main App Flow
- **[home_screen.dart](lib/src/screens/home/home_screen.dart)** - Dashboard with pet selector, AI camera banner, calendar widget, and health tracking cards
- **[weight_detail_screen.dart](lib/src/screens/weight/weight_detail_screen.dart)** - Weight tracking with fl_chart visualizations (weekly/monthly/yearly views)

All screens use `flutter_svg` for SVG assets and implement responsive sizing based on screen dimensions.

### Data Models
- **[weight_record.dart](lib/src/models/weight_record.dart)** - Weight record model with dummy data generators
  - `WeightRecord` - Single weight measurement (date, weight in grams)
  - `WeightData` - Static class with helper methods for dummy data generation (monthly/weekly/yearly)

### Entry Point
**[main.dart](lib/main.dart)** - App initialization:
1. Loads `.env` file with `flutter_dotenv`
2. Initializes Supabase with environment variables
3. Launches app with `MaterialApp.router`, theme configuration, and router setup

## Key Dependencies
- **go_router: ^14.6.2** - Declarative routing
- **flutter_svg: ^2.0.10+1** - SVG rendering
- **fl_chart: ^0.68.0** - Chart visualization (used in weight tracking)
- **supabase_flutter: ^2.5.3** - Supabase backend integration
- **flutter_dotenv: ^5.1.0** - Environment variable management
- **cupertino_icons: ^1.0.8** - iOS-style icons

## Assets
Assets are configured in `pubspec.yaml`:
- `assets/images/` - Main images directory
- `assets/images/login_vector/` - Login screen vectors
- `assets/images/btn_google/` - Google sign-in button assets
- `assets/images/btn_apple/` - Apple sign-in button assets
- `assets/images/btn_naver/` - Naver sign-in button assets
- `assets/images/btn_kakao/` - Kakao sign-in button assets
- `.env` - Environment variables file (must be created from `.env.example`)

SVG files are loaded via `SvgPicture.asset()` and PNG via `Image.asset()`.

## Development Notes

### Authentication Setup
For OAuth providers (Google/Apple), additional platform-specific configuration is required:
- **Google**: Configure OAuth consent screen and client in Google Cloud Console
- **Apple**: Set up "Sign in with Apple" in Apple Developer account
- See [docs/backend/setup_supabase.md](docs/backend/setup_supabase.md) for detailed OAuth setup instructions

### Deep Linking
The app uses the custom URL scheme `perchcare://auth-callback` for authentication callbacks. Configure in:
- iOS: `ios/Runner/Info.plist`
- macOS: `macos/Runner/Info.plist`
- Android: `android/app/src/main/AndroidManifest.xml`

## Design Implementation Guidelines

### What NOT to Implement from Figma Designs

When implementing designs from Figma, **DO NOT** implement the following elements as they are mockup/presentation artifacts only:

1. **Status Bar Elements** - DO NOT implement:
   - Clock/time display (9:41, etc.)
   - Battery indicator
   - WiFi/cellular signal icons
   - Any iOS/Android status bar elements
   - These are handled automatically by the device's system UI

2. **Home Indicator Bar** - DO NOT implement:
   - The horizontal bar at the bottom of iPhone designs (Home Indicator)
   - This is an iOS system UI element, not part of the app
   - Use `SafeArea` widget to respect system safe areas automatically

3. **Device Frames** - DO NOT implement:
   - Phone bezels or device frames shown in mockups
   - Notches or camera cutouts
   - These are presentation elements only

### What TO Implement from Figma Designs

Focus on implementing the actual app UI:
- Navigation bars and tabs (app-level UI)
- Content sections and cards
- Buttons and interactive elements
- Custom icons and illustrations
- Typography and spacing
- Colors and gradients
- Shadows and visual effects

### Example: Bottom Navigation Bar

**Correct Implementation:**
```dart
SafeArea(
  child: Row(
    children: [
      // Navigation items only
    ],
  ),
)
```

**Incorrect Implementation (DO NOT DO THIS):**
```dart
Column(
  children: [
    Row(/* navigation items */),
    Container(/* fake home indicator bar */), // ❌ Don't implement this
  ],
)
```

### Safe Area Usage

Always use `SafeArea` or `MediaQuery.padding` to handle device-specific insets:
- Status bar height
- Home indicator area
- Notch/camera cutout areas
- Keyboard insets

This ensures the app works correctly across all devices without hardcoding system UI elements.
