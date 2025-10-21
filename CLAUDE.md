# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ReceiptBro is an iOS receipt scanning and management app built with SwiftUI. It uses Apple's Vision framework for OCR and Foundation Models (on-device LLM) for structured data extraction from receipt images.

## Build & Development

### Building the Project
```bash
# Open in Xcode (required for iOS development)
open ReceiptBro.xcodeproj

# Build from command line (requires xcodebuild)
xcodebuild -project ReceiptBro.xcodeproj -scheme ReceiptBro -destination 'platform=iOS Simulator,name=iPhone 15' build
```

### Running Tests
```bash
# Run tests via xcodebuild
xcodebuild test -project ReceiptBro.xcodeproj -scheme ReceiptBro -destination 'platform=iOS Simulator,name=iPhone 15'
```

Note: This is a pure iOS project using Xcode. No package managers (CocoaPods, SPM, etc.) are currently configured.

## Architecture

### Data Flow Pipeline

The app follows a three-stage pipeline for receipt processing:

1. **Scanning** → 2. **Extraction** → 3. **Review & Storage**

#### 1. Scanning Stage (Scanning/)
- `ScanningFlowView`: Orchestrates the complete scan workflow (tips → camera → review)
- `DocumentCameraView`: UIKit wrapper for VNDocumentCameraViewController
- `ScanTipsView`: Onboarding tips shown before scanning
- Flow: User sees tips → captures with camera OR selects from photo library → moves to review

#### 2. Extraction Stage (Extraction/)
- `OCRService`: Uses Vision framework (VNRecognizeTextRequest) to extract raw text from images
- `ReceiptExtractor`: Coordinates OCR + Foundation Models streaming extraction
  - First performs OCR via `OCRService`
  - Then streams structured data extraction using Apple's on-device FoundationModels framework
  - Uses `@Observable` macro for real-time UI updates during streaming
  - Implements one-shot prompting with example receipts for better accuracy

**Key architectural detail**: The extractor uses `ReceiptData.PartiallyGenerated` during streaming, which allows progressive UI updates as the LLM generates structured data. Call `finalizeReceipt()` to convert partial data to concrete `ReceiptData`.

#### 3. Review & Storage (Review/, Models/)
- `ReviewView`: Shows streaming extraction progress and allows final review before save
- `VirtualReceiptView`: Displays the extracted receipt data in a receipt-like format
- Data is saved to SwiftData with CloudKit sync enabled

### Data Models

Two parallel model hierarchies exist:

**Foundation Models Schema** (for LLM extraction):
- `ReceiptData`: Marked with `@Generable` for Foundation Models structured output
- `LineItemData`: Line items in the extraction schema
- Uses `@Guide` attributes to provide extraction hints to the LLM
- See `ReceiptData.exampleGroceryReceipt` for the one-shot prompting example

**SwiftData Schema** (for persistence):
- `Receipt`: `@Model` class with SwiftData persistence
- `LineItem`: `@Model` class with inverse relationship to Receipt
- Convenience initializers (`init(from:)`) convert between the two schemas
- Relationships: Receipt ↔ LineItem (cascade delete)

### Key Components

**ContentView**: Root view with navigation
- Shows `EmptyStateView` when no receipts exist
- Shows `ReceiptListView` when receipts are present
- Presents `ScanningFlowView` as a sheet

**ReceiptListView**: Main list with search functionality
- Filtered search across merchant name, address, and transaction ID
- Swipe-to-delete support

**ReceiptDetailView**: Individual receipt details

### Logging

Structured logging via OSLog with categorized loggers in `Utilities/Logging.swift`:
- `Logger.ocr`: OCR processing events
- `Logger.extraction`: Foundation Models extraction
- `Logger.scanning`: Camera/scanning flow
- `Logger.storage`: SwiftData persistence
- `Logger.ui`: UI-related events

## Foundation Models Integration

The app uses Apple's on-device Foundation Models (requires iOS 18.2+):

```swift
// Session initialization with instructions
let session = LanguageModelSession(instructions: "...")

// Streaming structured output
let stream = session.streamResponse(
    to: prompt,
    generating: ReceiptData.self
)

// Progressive updates
for try await partialResponse in stream {
    self.receiptData = partialResponse.content
}
```

**Important**: Foundation Models availability should be checked before use:
```swift
let model = SystemLanguageModel.default
guard case .available = model.availability else { ... }
```

## SwiftData & CloudKit

The app uses SwiftData with CloudKit sync:
- Container configured in `ReceiptBroApp.swift` with explicit store URL (`ReceiptBro.sqlite`)
- Application Support directory is pre-created to avoid CoreData initialization errors
- Models: `Receipt` and `LineItem`
- CloudKit sync is automatic via `cloudKitDatabase: .automatic`
- Autosave is enabled on the main context
- All receipts include optional JPEG image data (70% quality compression)

## Permissions

Required permissions (configured in Info.plist):
- `NSCameraUsageDescription`: For scanning receipts with camera
- `NSPhotoLibraryUsageDescription`: For importing existing receipt photos

## Common Workflows

### Adding a New Extraction Field

1. Add to `ReceiptData` struct with `@Guide` description
2. Add to SwiftData `Receipt` model
3. Update convenience initializer in `Receipt` to map the field
4. Update UI in `VirtualReceiptView` to display the field
5. Consider updating `ReceiptData.exampleGroceryReceipt` if it helps extraction accuracy

### Modifying OCR Behavior

OCR configuration is in `OCRService.extractText()`:
- `recognitionLevel`: Set to `.accurate` for receipts
- `recognitionLanguages`: Currently `["en-US"]`
- `usesLanguageCorrection`: Enabled for better accuracy
- `automaticallyDetectsLanguage`: Enabled

### Improving Extraction Accuracy

The Foundation Models prompt is in `ReceiptExtractor.extractStructuredData()`:
- Modify system instructions in the initializer
- Update the extraction prompt with better examples or constraints
- Adjust the one-shot example in `ReceiptData.exampleGroceryReceipt`

## File Organization

```
ReceiptBro/
├── ReceiptBroApp.swift          # App entry point, SwiftData container setup
├── ContentView.swift             # Root navigation view
├── Info.plist                    # Camera/Photos permissions
├── Models/
│   ├── ReceiptData.swift        # Foundation Models schema (@Generable)
│   ├── Receipt.swift            # SwiftData model (@Model)
│   └── LineItem.swift           # SwiftData line item model
├── Extraction/
│   ├── OCRService.swift         # Vision framework text extraction
│   └── ReceiptExtractor.swift   # Foundation Models streaming extraction
├── Scanning/
│   ├── ScanningFlowView.swift   # Main scan orchestrator
│   ├── DocumentCameraView.swift # Camera UIKit wrapper
│   └── ScanTipsView.swift       # Pre-scan tips screen
├── Review/
│   ├── ReviewView.swift         # Review & save interface
│   └── VirtualReceiptView.swift # Receipt-style data display
├── ReceiptList/
│   ├── ReceiptListView.swift    # Main list view
│   ├── ReceiptDetailView.swift  # Individual receipt detail
│   └── EmptyStateView.swift     # Empty state when no receipts
└── Utilities/
    └── Logging.swift            # Categorized OSLog loggers
```

## iOS Version Requirements

- Minimum: iOS 17.0 (for SwiftData)
- Foundation Models: iOS 18.2+ (gracefully degrades if unavailable)
- Vision OCR: Works on all recent iOS versions
