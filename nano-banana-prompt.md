# Nano Banana Image Generation Prompt for ReceiptBro Empty State

## Prompt for Gemini (Nano Banana)

```
Create a minimalist, flat-style illustration for an iOS app empty state showing no receipts yet.

Style requirements:
- Flat design with simple 2D geometric shapes
- Clean lines, no shadows or complex textures
- Modern iOS aesthetic inspired by Apple's design language
- Minimalist and inviting

Visual elements:
- A simplified paper receipt icon or document with wavy lines representing text
- Optional: A subtle magnifying glass or camera outline nearby to suggest scanning capability
- The receipt should appear empty or faded, clearly conveying "nothing here yet"
- Friendly and approachable design

Color palette:
- Primary: Blue gradient (from light blue #5AC8FA to medium blue #007AFF)
- Secondary: Soft gray or light blue-gray for the receipt paper
- Accent: White or very light gray for contrast
- Use smooth gradients that match iOS design system

Composition:
- Center-focused single icon suitable for empty state
- Square or slightly portrait aspect ratio (1:1 or 4:5)
- Clear focal point with generous white space around it
- Size should work well when displayed at 80-120pt

Mood:
- Friendly and encouraging, not disappointing
- Inviting users to take their first action
- Professional but approachable
- Modern and clean

Technical specifications:
- PNG format with transparent background preferred
- High resolution (at least 512x512px, ideally 1024x1024px)
- Icon-style illustration, not a scene or character-based image
- Should work well on both light and dark backgrounds

Avoid:
- 3D effects, drop shadows, or skeuomorphic design
- Complex scenes or multiple objects
- Text or labels within the illustration
- Overly detailed or busy designs
- Sad or negative emotions
```

## Alternative Prompt Variations

### Option 1: Document-Focused
```
Create a flat, minimalist iOS-style icon of an empty receipt document. Show a simple paper with subtle wavy lines suggesting receipt text, floating slightly with a soft blue gradient. Clean geometric shapes, no shadows, modern iOS aesthetic. Center composition, transparent background, 1024x1024px.
```

### Option 2: Scanning-Focused
```
Create a minimalist iOS-style illustration: a smartphone outline with a receipt paper visible on screen, using blue gradients (#007AFF to #5AC8FA). Flat 2D design, clean lines, simple geometric shapes. Friendly and inviting empty state illustration. Transparent background, 1024x1024px.
```

### Option 3: Folder-Based
```
Create a flat, minimalist iOS-style illustration of an empty folder icon with a receipt symbol. Use blue gradient colors (#007AFF to #5AC8FA), simple 2D shapes, clean lines. Modern iOS design aesthetic, friendly and inviting. Center composition, transparent background, 1024x1024px.
```

## Usage Instructions

1. Go to [Gemini](https://gemini.google.com) or use the Nano Banana interface
2. Copy and paste the main prompt above
3. Review generated image and iterate if needed with refinements like:
   - "Make it more minimalist"
   - "Use softer blue tones"
   - "Remove [specific element] and simplify"
   - "Add more white space around the icon"
4. Download as PNG with transparent background
5. Place in Xcode Assets catalog
6. Update EmptyStateView.swift to use the custom image instead of SF Symbol

## Design Notes

**Current EmptyStateView Context:**
- Uses SF Symbol "doc.text.image" at 80pt
- Blue gradient foregroundStyle
- Text: "No Receipts Yet"
- Description: "Scan your first receipt to get started. We'll digitize it automatically using **onDevice** AI."
- Button: "Scan Receipt" with camera icon

**Why This Design:**
The illustration should complement the existing text and button, creating a cohesive first-use empty state that:
- Clearly communicates "no receipts yet" visually
- Encourages users to take action (scan their first receipt)
- Matches the app's modern, AI-powered brand identity
- Follows iOS Human Interface Guidelines for empty states
- Works harmoniously with the existing blue gradient color scheme

**Integration Options:**

1. **Replace SF Symbol completely:**
```swift
Image("empty-state-receipt")
    .resizable()
    .scaledToFit()
    .frame(width: 120, height: 120)
```

2. **Use as background with SF Symbol overlay:**
```swift
ZStack {
    Image("empty-state-receipt")
        .resizable()
        .scaledToFit()
        .frame(width: 140, height: 140)
        .opacity(0.3)

    Image(systemName: "doc.text.image")
        .font(.system(size: 80))
        .foregroundStyle(.blue.gradient)
}
```

3. **Use alongside existing SF Symbol:**
Keep the SF Symbol but enhance the overall empty state design with the custom illustration used elsewhere (e.g., onboarding, tutorial overlays).

## Post-Generation Checklist

- [ ] Image has transparent background
- [ ] Resolution is at least 1024x1024px
- [ ] Colors match iOS blue gradient theme
- [ ] Design is clearly recognizable at small sizes (80-120pt)
- [ ] Looks good on both light and dark mode backgrounds
- [ ] Conveys "empty receipt list" intuitively
- [ ] Feels friendly and inviting, not negative
- [ ] Matches overall app aesthetic
- [ ] Works well with existing text and button
