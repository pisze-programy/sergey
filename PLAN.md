# Plan: Marker Overlay Implementation

## Goal
Implement a new transparent overlay for drawing markers (rectangles, text, fake cursor movement) on the screen, designed as a precursor to an Agent Skill.

## Steps

### 1. Data Models & State Management
- [ ] Create `MarkerElement.swift`: Define `MarkerElement` enum (e.g., `.rect(CGRect, Color)`, `.text(String, CGPoint)`, `.cursor(CGPoint)`).
- [ ] Create `MarkerState.swift`: Implement `@ObservableObject` to hold an array of `[MarkerElement]` and provide mutation methods (`add`, `remove`, `clear`).

### 2. UI Layer (SwiftUI)
- [ ] Create `MarkerOverlayView.swift`: A transparent SwiftUI view that renders `MarkerElement` items using a `Canvas` or `ZStack`.
- [ ] Implement rendering logic for each element type in the view.

### 3. Window Management (AppKit)
- [ ] Create `MarkerOverlayManager.swift`:
    - [ ] Manage an `NSWindow` covering the full screen/visible frame.
    - [ ] Configure window properties: `.borderless`, `.nonactivatingPanel`, `ignoresMouseEvents = true`, `isOpaque = false`.
    - [ ] Implement methods to update the state (e.g., `drawRect(...)`, `moveCursor(...)`, `clear()`).

### 4. Integration & Verification
- [ ] Add a way to trigger/test the overlay from existing app flow or a temporary debug button.
- [ ] Verify that mouse clicks pass through the overlay to applications underneath.
