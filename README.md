# Baseer — بصير

Baseer is a mobile assistant for visually impaired users. It uses the device camera and voice to describe surroundings, read text, detect colors, and estimate distances — all spoken aloud in Arabic.

## Features

| Mode | How it works |
|------|-------------|
| **كشف** — Detect | Object detection — on-device ONNX (YOLOv8). Colour of each detected object is always added on-device. |
| **نص** — Text | OCR — backend. |
| **لون** — Color | K-Means LAB colour classifier - on-device |

### Gestures (camera screen)
- **Double tap** anywhere → activate voice command (STT)
- **Long press** anywhere → capture and analyze
- **Swipe left / right** → cycle through modes
- **Top bar chips** → tap to switch mode directly

## Tech Stack

- Flutter / Dart
- [`camera`](https://pub.dev/packages/camera) — live preview and capture
- [`speech_to_text`](https://pub.dev/packages/speech_to_text) — on-device STT
- [`flutter_tts`](https://pub.dev/packages/flutter_tts) — Arabic TTS narration
- [`image`](https://pub.dev/packages/image) — on-device image decoding for color detection
- [`http`](https://pub.dev/packages/http) — backend communication
- [`flutter_dotenv`](https://pub.dev/packages/flutter_dotenv) — environment config
- [`permission_handler`](https://pub.dev/packages/permission_handler) — runtime permissions

## Backend

The app talks to a Python FastAPI backend via one endpoint:

```
POST /analyze
  fields:  command  — "نص"
  files:   file     — JPEG image

Response (نص):    { "description": "النص المستخرج" }
Response (error): { "error": "رسالة الخطأ" }
```

Colour detection (`لون` mode) is always on-device and never hits the backend.

## Getting Started

### Prerequisites

- Flutter SDK (recommended: 3.41.6 stable)
- Dart SDK 3.11.4 (bundled with Flutter 3.41.6)
- Android device or emulator (primary target)
- Camera and Microphone permissions granted at runtime

### Setup

```bash
flutter pub get
```

Create a `.env` file in the project root:

```env
BASE_URI=https://khalidali44-baseer-backend.hf.space
GROQ_API_KEY=your_api_key
```

### Run

```bash
flutter run
```

## Git Workflow

### Branch Naming

```
<type>/<short-description>
```

Examples: `feature/color-mode`, `fix/camera-init-hang`, `docs/update-readme`

Types: `feature` · `fix` · `docs` · `refactor` · `test` · `chore`

### Commit Format

```
<type>(scope): <summary>
```

Examples: `feat(camera): add on-device color detection`, `fix(tts): early setState after camera init`
