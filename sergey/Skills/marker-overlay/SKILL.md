---
name: marker-overlay
description: Draw markers (rectangles, text, cursor) on the screen to highlight areas. Supports auto-hide after duration.
parameters:
  rect:
    type: object
    properties:
      x: number
      y: number
      w: number
      h: number
  text:
    type: string
  point:
    type: object
    properties:
      x: number
      y: number
  color:
    type: string
  duration:
    type: number
  clear:
    type: boolean
---

# Marker Overlay Skill

Use this skill to draw visual highlights on the screen. This is useful for pointing out UI elements, errors, or following a sequence of actions.

## Usage

You can draw different types of markers with an optional duration (in seconds) after which they will disappear automatically.

### Draw Rectangle
Highlights a specific area. Use `duration` to make it transient.

**Example Call:**
`marker-overlay(rect: {x: 100, y: 100, w: 200, h: 50}, color: "red", duration: 5)`

### Draw Text
Labels a position on the screen.

**Example Call:**
`marker-overlay(text: "Click here", point: {x: 200, y: 150}, color: "yellow", duration: 3)`

### Move Cursor
Simulates cursor movement by drawing a crosshair at a specific point.

**Example Call:**
`marker-overlay(point: {x: 500, y: 500}, duration: 2)`

### Clear All
To remove all current markers manually.

**Example Call:**
`marker-overlay(clear: true)`
