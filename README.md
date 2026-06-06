# Baseer — بصير

Baseer is a mobile assistant for visually impaired users. It uses the device camera and voice to describe surroundings, read text, detect colors, and estimate distances — all spoken aloud in Arabic.

## Features

| Mode | How it works |
|------|-------------|
| **كشف** — Detect | Object detection — on-device ONNX (YOLOv8) or backend, configurable via `.env`. Colour of each detected object is always added on-device. |
| **نص** — Text | OCR — on-device ONNX model or backend, configurable via `.env` |
| **لون** — Color | Always on-device — K-Means LAB colour classifier, no backend needed |

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
  fields:  command  — "كشف" | "نص"
  files:   file     — JPEG image

Response (كشف):   { "objects": [ { "label": "...", "confidence": 0.9, "bbox": { "x1": 0, "y1": 0, "x2": 100, "y2": 100 } } ] }
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
BASE_URI=https://baseer-backend-crf6g8gscthna7d5.uaenorth-01.azurewebsites.net

# Inference source for object detection (كشف mode)
# ondevice → on-device ONNX model
# remote  → POST /analyze with command "كشف"
DETECTION_SOURCE=ondevice

# On-device model path for object detection 
# assets/ml/yolov8_int8.onnx → on-device optimised YOLOv8n ONNX model
# assets/ml/hybrid_yolov8n_mobilenet.onnx → on-device hybrid YOLOv8n & MobileNetV2 ONNX model
DETECTION_MODEL=assets/ml/yolov8n_int8.onnx

# Inference source for text extraction (نص mode)
# ondevice → on-device OCR ONNX model
# remote  → POST /analyze with command "نص"
TEXT_SOURCE=ondevice

# 'svm' → SVM-based color detection  |  'rulebased' → rule-based (default)
COLOR_SOURCE=rulebased

# Distance estimation method
# 1 → Pinhole Prior
# 2 → Ground-Plan Projection
# 3 → Scaled MiDaS Depth
DISTANCE=1
```

### Run

```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart                          # Entry point — loads .env, runs app
├── app/
│   ├── baseer_app.dart                # Root MaterialApp
│   └── router.dart                    # Named routes: / → /permissions → /camera
├── core/
│   ├── app_settings.dart              # Singleton — locale, TTS/STT language prefs
│   ├── command_router.dart            # Maps STT text to AppCommand enum
│   └── services/
│       ├── tts_narrator.dart          # Singleton TTS wrapper (used by camera page)
│       ├── tts_service.dart           # Singleton TTS wrapper (used by onboarding)
│       └── stt_service.dart           # STT wrapper
└── features/
    ├── camera/
    │   ├── application/
    │   │   └── camera_service.dart    # CameraController lifecycle
    │   └── presentation/
    │       └── camera_page.dart       # Main camera screen
    ├── color_recognition/
    │   └── application/
    │       └── color_detector.dart    # On-device LAB K-Means color classifier
    └── onboarding/
        └── presentation/
            ├── splash_page.dart       # 1.5 s splash with TTS greeting
            └── permissions_page.dart  # Requests camera + microphone permissions
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
