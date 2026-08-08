# Guided Workout Progression — UX Flow

## Experience goal

The active workout behaves like an explainable training copilot. It keeps the routine target, previous performance, suggested progression, and today's entered values separate. A suggestion never becomes today's value until the user explicitly chooses **Use**, **Apply All**, or types a value themselves.

## End-to-end workout flow

```mermaid
flowchart TD
    A["Open a workout routine"] --> B{"Saved draft exists?"}
    B -- "Yes" --> C["Resume the draft with its original history and suggestions"]
    B -- "No" --> D["Create empty warm-up and working sets from routine targets"]
    D --> E["Load launch history"]
    E --> F{"History available?"}
    F -- "Yes" --> G["Prefer latest use in this routine"]
    G --> H{"Same-routine history found?"}
    H -- "No" --> I["Fall back to latest global use of the exercise"]
    H -- "Yes" --> J["Match sets by type and ordinal"]
    I --> J
    J --> K["Show previous values, source/date, suggestion, and reason"]
    F -- "No" --> L["Show History unavailable; workout remains usable"]
    C --> M["Active workout"]
    K --> M
    L --> M

    M --> N{"Choose how to fill a set"}
    N -- "Use" --> O["Copy one suggestion into today's fields"]
    N -- "Apply All" --> P["Copy all available suggestions for this exercise"]
    N -- "Type values" --> Q["Keep the user's values"]
    O --> R["Complete the set"]
    P --> R
    Q --> R
    R --> S{"More work?"}
    S -- "Yes" --> M
    S -- "Add exercise" --> T["Add empty exercise and load its global history"]
    T --> U["Refresh the iPhone and Watch snapshot"]
    U --> M
    S -- "No" --> V["Finish workout"]
    V --> W["Save the session, strength sets, and cardio logs atomically"]
    W --> X["Completed workout detail"]
```

## What appears on an exercise card

```mermaid
flowchart LR
    subgraph Card["Exercise card"]
        A["Routine target<br/>3 working + 2 warm-up<br/>8–12 reps · 2.5 kg increment"]
        B["History context<br/>Same routine or global<br/>Source workout date"]
        C["Per-set context<br/>Previous: 60 kg × 12<br/>Suggested: 62.5 kg × 8<br/>Reason: range ceiling reached"]
        D["Today's values<br/>Empty until accepted or entered"]
        E["Actions<br/>Use · Apply All · Add Set · Done"]
        A --> B --> C --> D --> E
    end
```

Warm-up rows use `W1`, `W2`, and so on. Their suggestions repeat previous warm-up values and never influence working-set progression. Working sets use their normal ordinal. A set's **Done** control stays disabled while its required current values are empty.

## Strength suggestion rules

```mermaid
flowchart TD
    A["Matched previous working sets"] --> B{"Every set reached the rep-range ceiling?"}
    B -- "Yes" --> C{"Reps-only or bodyweight?"}
    C -- "No" --> D["Add configured load increment<br/>Reset reps to range minimum"]
    C -- "Yes" --> E["Keep reps at ceiling<br/>Suggest added load or a harder variation"]
    B -- "No" --> F{"Every set reached at least the range minimum?"}
    F -- "Yes" --> G["Keep load<br/>Add one rep per set, capped at ceiling"]
    F -- "No" --> H["Repeat previous load and reps"]

    D --> I["Display as a suggestion only"]
    E --> I
    G --> I
    H --> I
```

Historical sets are matched within their own type by set number. If today's workout has extra sets, the final corresponding historical set is reused; a missing historical match leaves the set without a suggestion.

## Cardio behavior

```mermaid
flowchart LR
    A["Previous cardio entry"] --> B["Show duration, distance, and calories"]
    B --> C["Suggest the same values"]
    C --> D{"User accepts?"}
    D -- "Use" --> E["Copy into today's fields"]
    D -- "No" --> F["Leave today's fields empty or user-entered"]
```

Cardio history is guidance only in this release; it does not apply automated progression.

## iPhone and Apple Watch interaction

```mermaid
sequenceDiagram
    participant P as iPhone
    participant W as Apple Watch
    participant U as User

    P->>W: Sync target, previous values, suggestion, and reason
    U->>W: Open a set
    W-->>U: Show current values separately from suggestion
    alt Accept suggestion
        U->>W: Use Suggestion
        W->>W: Copy suggestion into current values
    else Enter manually
        U->>W: Adjust values with the Digital Crown
    end
    U->>W: Complete set
    W->>P: Send updated values and completion state
    P->>W: Resync authoritative workout snapshot
```

Both devices follow the same explicit-acceptance rule. Completing a strength or cardio set without required current values is blocked.

## Data ownership through the flow

| Information | Meaning | Can it change today's saved result automatically? |
|---|---|---|
| Routine target | Planned sets, rep range, rest, and load increment | No |
| Previous values | What was performed in the selected history session | No |
| Suggested values | A calculated next attempt with an explanation | No |
| Current values | What the user accepted or entered today | Yes; these are saved on completion |

Finishing the workout sends one finalization payload. The database creates the workout session and all child strength/cardio records in one transaction, preventing partially saved workout history.
