# Project Plan: Agentic Orchestrator (ReAct Implementation)

## Goal
Transform "Sergey" from a linear pipeline (STT $\to$ LLM $\to$ Response) into an autonomous **Orchestrator Agent** using the **ReAct** (Reasoning + Acting) framework and a modular **Skill-based architecture**.

## Core Architecture: The Three-Level Skill Model
To ensure scalability and prevent context bloat, all capabilities will follow the progressive disclosure pattern:
- **Level 1 (Metadata)**: YAML frontmatter in `SKILL.md`. Contains name, description (triggers), and parameter schema. Always loaded at startup via `SkillRegistry`.
- **Level 2 (Instructions)**: The body of `SKILL.md`. Detailed runbooks/steps. Loaded only when the Agent decides to trigger the skill.
- **Level 3 (Execution/Assets)**: `executor.swift` and external files (`references/`). Executed via the `SkillExecutor` protocol.

## Implementation Phases

### Phase 1: The Discovery Engine (`SkillRegistry`)
**Objective**: Automate skill awareness for the Agent.
- **Implementation**: Create `sergey/Core/SkillRegistry.swift`.
- **Functionality**:
    - Scan `sergey/Skills/` directory recursively.
    - Parse YAML headers from each `SKILL.md`.
    - Map Skill Names $\to$ Implementation Path $\to$ Metadata.
    - Produce a "System Inventory" (a compact list of all available skills and their triggers).
- **Scaling**: Add support for parameter schema parsing (e.g., identifying that `screen-capture` expects `mode: string`).

### Phase 2: The ReAct Loop (The Orchestrator)
**Objective**: Implement the "Reasoning $\to$ Acting $\to$ Observing" logic in `Agent.swift`.
- **Mechanism**:
    1.  **Input**: User prompt is augmented with the `SkillRegistry` inventory.
    2.  **Reasoning & Validation (The Decision Gate)**: Agent analyzes the request.
        - **Path A (Clarification)**: If input is unintelligible, ambiguous, or lacks context $\to$ Generate brief follow-up question ("Did you mean X?" / "Please clarify...") $\to$ **End Loop**.
        - **Path B (Direct Answer)**: Intent clear, no skill needed $\to$ Final Response $\to$ **End Loop**.
        - **Path C (Action Extraction)**: Intent matches a Skill $\to$ Continue to Action.
    3.  **Action**: Agent extracts parameters and dispatches the action to the corresponding `SkillExecutor`.
    4.  **Observation**: The `SkillResult` is fed back into the conversation as an "OBSERVATION" block.
    5.  **Final Response**: LLM synthesizes observations into a natural language answer.

### Phase 3: Scaling & Ecosystem
**Objective**: Enable complex, multi-step capabilities.
- **Advanced Skills**: Implement skills that orchestrate multiple other skills (e.g., `FileReviewer` $\to$ calls `FileSearch` then `CodeAnalyzer`).
- **Context Management**: Ensure the Agent knows when to "stop" and ask for user input (Level 2 instructions will guide this).

## Technical Constraints & Rules
- **No extra compilation needed for Discovery**: The Registry must only read text files.
- **Type Safety**: All skill parameters must be passed via `[String: Any]` to maintain protocol stability.
- **Error Handling**: Every execution failure must be caught and returned as a `SkillResult(success: false, error: ...)` to allow the Agent to "self-correct" (the 'R' in ReAct).
