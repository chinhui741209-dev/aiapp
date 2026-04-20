# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**AnswerChecker** (對答案小工具) is an iOS app for teachers to check student answer sheets. It supports up to 70 multiple-choice questions and open-ended "writing" questions. The teacher enters an answer key, pastes the student's answers in a structured text format, and the app produces a correction summary.

## Build & Run

Open `AnswerChecker.xcodeproj` in Xcode, select a simulator or device, and press `Cmd+R`. There is no separate build script.

Run tests: `Cmd+U` in Xcode, or via CLI:
```
xcodebuild test -project AnswerChecker.xcodeproj -scheme AnswerChecker -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Architecture

Everything lives in a single `ContentView.swift` file organized by `// MARK:` sections. The app has no backend and no external dependencies.

### 3-Step Flow

| Step | Purpose |
|------|---------|
| Step 1 | Teacher enters answer key: 70 choice answers (grid) + writing question answers (list) |
| Step 2 | Teacher pastes one student's raw answer text |
| Step 3 | App shows corrections (wrong + missing questions) |

### Key Data Structures

- **`choiceKey: [String]`** — 70-element array, index 0 = Q1. Values are normalized answer strings (e.g. `"AC"`).
- **`WritingKeyItem`** — `Identifiable/Codable` struct: `question: Int`, `answer: String`. Stored as `writingKeyItems: [WritingKeyItem]`.
- **`StudentSubmission`** — transient struct: `headerLine: String` (first line = student name/subject), `answers: [Int: String]` (question number → answer).

### Persistence

Answer key data persists across launches via `@AppStorage`:
- `AnswerChecker.choiceKeyJSON` — JSON-encoded `[String]`
- `AnswerChecker.writingKeyJSON` — JSON-encoded `[WritingKeyItem]`

Data is loaded `onAppear` (only when current state is empty) and saved `onChange` automatically. Tapping "清空" is the only way to erase persisted data.

### Answer Normalization

`normalizeAnswer(_:)` strips non-ABCD characters, deduplicates, and sorts alphabetically. All comparisons use normalized values, so `"CA"` == `"AC"`.

### Student Answer Parser (`parseStudentSubmission` / `parseAnswerLine`)

Handles several text formats in a single paste:
- First line is always treated as the student header (name/subject).
- Subsequent lines start with a 2-digit question number, followed by answers in various formats: space-separated tokens, slash-separated, or concatenated letter strings.
- `tokenizeNumberAndLetters` splits a line into numeric and alphabetic tokens using regex.

### OCR (Step 1 Camera Import)

Uses Apple's Vision framework (`VNRecognizeTextRequest`) to read handwritten answer keys from a photo. `parseHandwrittenKeyLines` handles the specific format expected from photographed answer sheets (e.g. `"1- BCCD"`, `"11- BACCC ABDAB"`, `"05 BD"`). OCR runs on a background thread; results are dispatched back to main.

### UI Components

- **`ChoiceBoxCellCompact`** — custom `TextField` subview for each answer cell in the grid; supports dark mode, shows focus highlight.
- **`ImagePicker`** — `UIViewControllerRepresentable` wrapping `UIImagePickerController` for camera access.

## Camera Permission

`Info.plist` declares `NSCameraUsageDescription` for camera access (required for OCR import).
