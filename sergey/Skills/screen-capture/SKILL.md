---
name: screen-capture
description: Captures the primary display or a specific region of the screen to provide visual context. Use when the user asks "what is this?", "look at my screen", "analyze what I see", "is there something on my screen", or "take a screenshot".
---

# Screen Capture Skill

## Overview
Provides the ability to capture visual content from the user's display so the Agent can "see" the context requested.

## Instructions

### 1. Determine Mode
Decide if you need the **Primary Display** (full screen) or a specific **Region**.
- Use **Primary Display** for general questions about the current workspace.
- Use **Region** only if the user specifies an area or coordinates.

### 2. Execution via Executor
The Agent must invoke the `executor.swift` associated with this skill.

#### Parameters to pass:
- `mode`: `"primary"` or `"region"`.
- `rect` (Optional): If mode is `"region"`, provide a JSON object representing the area: `{"x": 0, "y": 0, "width": 1920, "height": 1080}`.

### 3. Processing Result
Once the `executor` returns a `ToolResult`:
- If `success` is **true**: The result contains `png` data. You can now analyze this image or use it to answer user queries.
- If `success` is **false**: Report the error message provided in the result back to the user using a clear, helpful tone.

## Example usage (Implicit)
**User:** "What is that window on my screen?"
**Agent Action:** Invokes `screen-capture` with `mode: "primary"`. 
**Agent Result:** Analyzes returned image and answers.
