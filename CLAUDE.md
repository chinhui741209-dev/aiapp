# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**AnswerChecker** (對答案小工具) is an iOS app for teachers to check student answer sheets. It supports up to 100 multiple-choice questions and open-ended "writing" questions. The teacher enters an answer key, pastes the student's answers in a structured text format, and the app produces a correction summary.

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
| Step 1 | Teacher manages **multiple named answer sets** and enters each set's answer key (up to 100 choice answers in a grid) |
| Step 2 | Teacher picks which answer set to check against, then pastes one student's raw answer text |
| Step 3 | App shows corrections (wrong + missing questions) |

### Key Data Structures

- **`AnswerSet`** — `Identifiable/Codable/Equatable` struct: `id: UUID`, `name: String`, `choiceKey: [String]` (100-element array, index 0 = Q1, normalized values e.g. `"AC"`). The app holds `answerSets: [AnswerSet]` and a `selectedSetID: UUID` for the currently active set (edited in Step 1, checked against in Step 2/3). Always keeps at least one set.
- **`StudentSubmission`** — transient struct: `headerLine: String` (first line = student name/subject), `answers: [Int: String]` (question number → answer).
- **`AnswerLogic`** — top-level enum holding the pure, testable parsing/comparison statics (`parseStudentSubmission`, `parseAnswerLine`, `buildResultText`, `normalizeAnswer`, etc.). No UI/state dependencies, so unit tests call it directly via `@testable import`.

### Persistence

Answer key data persists across launches via `@AppStorage`:
- `AnswerChecker.answerSetsJSON` — JSON-encoded `[AnswerSet]`
- `AnswerChecker.selectedSetID` — UUID string of the active set
- `AnswerChecker.choiceKeyJSON` — legacy single-key JSON, **read only for one-time migration** into a set named "預設"

Loaded `onAppear` (migrates legacy key, or seeds one empty set if nothing stored) and saved `onChange(of: answerSets)` automatically. In Step 1, "清空" clears the current set's grid; the "⋯" menu renames or deletes the set (deleting the last set re-seeds an empty one).

### Answer Normalization

`AnswerLogic.normalizeAnswer(_:)` strips non-ABCD characters, deduplicates, and sorts alphabetically. All comparisons use normalized values, so `"CA"` == `"AC"`.

### Student Answer Parser (`AnswerLogic.parseStudentSubmission` / `parseAnswerLine`)

Handles several text formats in a single paste:
- First line is always treated as the student header (name/subject).
- Subsequent lines may start with a question number (any value, not just Q1), followed by answers as space-separated tokens, slash-separated, or concatenated letter strings; lines with only A–D + spaces continue from the previous question (`autoQ`).
- **Key-guided splitting**: a concatenated letter run is consumed per question using the *active answer set's* expected letter count for each question (single-choice → 1 letter, multi-choice → N letters, unfilled key → defaults to 1). This makes parsing correct regardless of the starting question number or gaps in the key — there is no special-casing for "starts at Q1".
- `tokenizeNumberAndLetters` splits a line into numeric and alphabetic tokens using regex.

### OCR (Step 1 Camera Import)

Uses Apple's Vision framework (`VNRecognizeTextRequest`) to read handwritten answer keys from a photo. `parseHandwrittenKeyLines` handles the specific format expected from photographed answer sheets (e.g. `"1- BCCD"`, `"11- BACCC ABDAB"`, `"05 BD"`). OCR runs on a background thread; results are dispatched back to main.

### UI Components

- **`ChoiceBoxCellCompact`** — custom `TextField` subview for each answer cell in the grid; supports dark mode, shows focus highlight.
- **`ImagePicker`** — `UIViewControllerRepresentable` wrapping `UIImagePickerController` for camera access.

## Camera Permission

`Info.plist` declares `NSCameraUsageDescription` for camera access (required for OCR import).
