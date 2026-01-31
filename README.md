# ReceiptBro

**Digital Invoice** -- iOS App zur Rechnungserfassung mit OCR und On-Device AI

Projekt Nr. 9 | Michael Luegmayer | Matrikelnummer 2410838005

---

## Was macht die App?

ReceiptBro scannt physische Rechnungen (Kassabons etc.) per Kamera oder Foto-Import, liest den Text per OCR aus und extrahiert daraus automatisch strukturierte Daten -- Händlername, Datum, Einzelposten, Steuern, Gesamtbetrag. Die extrahierten Daten werden lokal in SwiftData gespeichert und per CloudKit synchronisiert.

Der Ablauf in der App:

1. Rechnung scannen (Kamera oder Foto-Bibliothek)
2. OCR-Texterkennung + KI-Extraktion laufen automatisch
3. Ergebnis wird als visuelle Rechnung angezeigt und kann bearbeitet werden
4. Speichern in SwiftData

## Anforderungen laut Aufgabenstellung

| Anforderung | Umsetzung |
|---|---|
| Invoice scanning mit OCR Texterkennung | Vision Framework (`VNRecognizeTextRequest` + `RecognizeDocumentsRequest`) |
| AI Model Verarbeitung | Apple Foundation Models (On-Device LLM, ab iOS 26) |
| Uebersicht ueber Rechnungen | `ReceiptListView` mit Suchfunktion |
| Visuelle Darstellung der Rechnung | `ScrollViewReceiptEditorView` zeigt Rechnung als Bon-Ansicht |
| Extraktion strukturierter Daten | `ReceiptExtractor` streamt LLM-Output in `ReceiptData` Struct |
| Speichern der Daten in SwiftData | `Receipt` und `LineItem` als `@Model`, CloudKit Sync |

## Technologie-Stack

- **SwiftUI** -- gesamte UI
- **SwiftData** -- lokale Persistenz mit CloudKit Sync
- **Vision Framework** -- OCR, Tabellenerkennung, Adress-/Datumserkennung
- **Apple Foundation Models** -- On-Device LLM fuer strukturierte Datenextraktion (`@Generable`)
- **OSLog** -- Logging mit kategorisierten Loggern

## Projektstruktur

```
ReceiptBro/
├── ReceiptBroApp.swift              App-Einstiegspunkt, SwiftData Container
├── ContentView.swift                Root Navigation
├── Models/
│   ├── DTO/ReceiptData.swift        LLM-Schema (@Generable)
│   └── Domain/
│       ├── Receipt.swift            SwiftData Model
│       └── LineItem.swift           SwiftData Model (Einzelposten)
├── Services/
│   ├── OCRService.swift             Vision OCR + Dokumentenerkennung
│   └── ReceiptExtractor.swift       Foundation Models Streaming-Extraktion
├── Features/
│   ├── Scanning/
│   │   ├── ScanView.swift           Scan-Workflow (Tips -> Kamera -> Review)
│   │   └── ScanTipsView.swift       Tipps vor dem Scannen
│   ├── Review/
│   │   ├── ReviewView.swift         Streaming-Anzeige + Review vor Speichern
│   │   └── ScrollViewReceiptEditorView.swift  Bon-Darstellung mit Edit
│   └── ReceiptList/
│       ├── ReceiptListView.swift    Rechnungsliste mit Suche
│       ├── ReceiptDetailView.swift  Detailansicht
│       └── EmptyStateView.swift     Leerer Zustand
└── Shared/
    ├── Extensions/
    │   ├── Logger+Extensions.swift  Kategorisierte Logger
    │   └── View+Extension.swift     View-Hilfsfunktionen
    └── Utilities/
        └── ReceiptValidator.swift   Duplikaterkennung etc.
```

## Wie die OCR funktioniert

`OCRService` versucht zuerst `RecognizeDocumentsRequest` (iOS 18+), das Tabellen auf Kassabons erkennt. Wenn keine Tabellen gefunden werden, faellt es auf `VNRecognizeTextRequest` zurueck. Die Texterkennung laeuft auf Deutsch und Englisch (`de-DE`, `en-US`).

Ein Nachbearbeitungsschritt merged Mengenzeilen (z.B. "2 x 0.99") mit der darauffolgenden Produktzeile, weil OCR diese oft als getrennte Zeilen erkennt.

## Wie die KI-Extraktion funktioniert

`ReceiptExtractor` nutzt Apple's On-Device Foundation Models mit Streaming. Das heisst die Rechnung baut sich in Echtzeit auf waehrend das LLM die Daten generiert.

Das LLM bekommt den OCR-Text als Input und gibt ein `ReceiptData` Struct zurueck (markiert mit `@Generable`). Waehrend des Streamings arbeiten wir mit `ReceiptData.PartiallyGenerated`, nach Abschluss wird mit `finalizeReceipt()` in ein vollstaendiges Objekt konvertiert.

Die System-Instructions enthalten Regeln fuer Mengenberechnung, Preisextraktion und Rabatterkennung. Greedy Sampling wird verwendet damit die Ergebnisse deterministisch sind.

## Systemvoraussetzungen

- iOS 26+ (fuer Foundation Models)
- iPhone mit Apple Intelligence Support (A17 Pro oder neuer)
- Xcode 26+

## Build

```bash
open ReceiptBro.xcodeproj
# Dann in Xcode: Cmd+R
```

Oder per Commandline:
```bash
xcodebuild -project ReceiptBro.xcodeproj -scheme ReceiptBro \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Keine externen Dependencies. Alles Apple-eigene Frameworks.

## Datenmodell

Zwei getrennte Modell-Hierarchien:

**Fuer LLM-Extraktion** (`ReceiptData`, `LineItemData`): Mit `@Generable` und `@Guide` Attributen versehen, damit das Foundation Model weiss was es extrahieren soll.

**Fuer Persistenz** (`Receipt`, `LineItem`): SwiftData `@Model` Klassen mit Relationship (cascade delete). Convenience-Initializer konvertiert von `ReceiptData` nach `Receipt`.

Die Rechnungsbilder werden als JPEG (70% Qualitaet) im `imageData` Property gespeichert.

## Berechtigungen

- Kamera (`NSCameraUsageDescription`) -- zum Scannen
- Foto-Bibliothek (`NSPhotoLibraryUsageDescription`) -- fuer Foto-Import
