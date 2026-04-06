# Baseer

Baseer is an assistant application built to support visually impaired users.

The goal is to provide practical, accessible assistance through a simple and reliable mobile experience.

## Tech Stack

- Flutter (cross-platform app framework)
- Dart

## Getting Started

### Prerequisites

- Flutter SDK installed (recommended: 3.41.6, stable)
- Dart SDK 3.11.4 (included with Flutter 3.41.6)
- A configured device or emulator
- Android Studio, VS Code, or another Flutter-compatible IDE

### Run Locally

```bash
flutter pub get
flutter run
```

## Project Structure

```text
baseer/
|- lib/
|  |- main.dart                              # Entry point
|  |- app/
|  |  \- baseer_app.dart                     # Root app widget
|  \- features/
|     \- camera/
|        |- application/
|        |  \- camera_initializer.dart       # Camera setup logic
|        \- presentation/
|           \- pages/
|              \- camera_launcher_page.dart  # Launch-time camera screen
|- test/                 # Unit and widget tests
|- android/              # Android-specific project files
|- ios/                  # iOS-specific project files
|- web/                  # Web-specific project files
|- windows/              # Windows desktop files
|- linux/                # Linux desktop files
|- macos/                # macOS desktop files
|- pubspec.yaml          # Dependencies and project metadata
\- README.md             # Project documentation
```

## Git Workflow

### Branch Naming

Use this format:

```text
<type>/<short-description>
```

Examples:

- `feature/voice-guidance-foundation`
- `fix/navigation-state-bug`
- `docs/update-readme-structure`
- `chore/setup-ci`

Recommended branch types:

- `feature` - new functionality
- `fix` - bug fixes
- `docs` - documentation only
- `refactor` - code cleanup without behavior changes
- `test` - test-related work
- `chore` - tooling, config, or maintenance tasks

### Commit Message Format

Follow a Conventional Commits style:

```text
<type>(optional-scope): <short summary>
```

Examples:

- `feat(auth): add basic login screen layout`
- `fix(camera): handle permission denial gracefully`
- `docs(readme): add branch and commit conventions`
- `chore(deps): upgrade flutter packages`

Recommended commit types:

- `feat` - introduces a new feature
- `fix` - fixes a bug
- `docs` - documentation changes
- `refactor` - code restructuring with no behavior change
- `test` - adds or updates tests
- `chore` - maintenance and tooling

