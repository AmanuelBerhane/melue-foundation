# Module 07 — Communication & Notifications

**Tables owned:** `parent_communications`, `home_observations`, `notifications`

**Cross-module stubs:** `students` (→ 03-students), `guardians` (→ 01-identity), `users` (→ 01-identity)

```mermaid
erDiagram

    %% ── Owned tables ──────────────────────────────────────────

    parent_communications {
        uuid id PK
        uuid student_id FK
        uuid guardian_id FK
        uuid sender_user_id FK
        varchar direction
        varchar kind
        text content
        timestamp sent_at
        timestamp read_at
    }

    home_observations {
        uuid id PK
        uuid student_id FK
        uuid guardian_id FK
        text content
        date observed_on
        timestamp submitted_at
    }

    notifications {
        uuid id PK
        uuid recipient_user_id FK
        varchar type
        text payload_reference
        timestamp read_at
        timestamp created_at
    }

    %% ── Cross-module stubs ────────────────────────────────────

    students {
        uuid id PK
        %% see 03-students.md
    }

    guardians {
        uuid id PK
        %% see 01-identity.md
    }

    users {
        uuid id PK
        %% see 01-identity.md
    }

    %% ── Relationships ─────────────────────────────────────────

    students ||--o{ parent_communications : "concerns"
    guardians ||--o{ parent_communications : "communicates"
    users ||--o{ parent_communications : "sender"

    students ||--o{ home_observations : "for"
    guardians ||--o{ home_observations : "submitted by"

    users ||--o{ notifications : "recipient"
```

**Enum values**

| Column | Values |
|---|---|
| `parent_communications.direction` | `inbound`, `outbound` |
| `parent_communications.kind` | `progress_update`, `general`, `alert` |
| `notifications.type` | `stale_draft`, `mastery_decision`, `session_review`, `communication` |

**Key rules**
- `home_observations` are read-only from the therapy side — a guardian submission cannot alter any clinical record
- `parent_communications.direction` is `outbound` when staff send to guardian, `inbound` when guardian initiates
- `notifications.payload_reference` is a JSON pointer to the resource that triggered the notification (e.g. `{"type":"mastery_check","id":"..."}`)
- Threading, attachments, and multi-participant rules are not yet specified — do not add columns for them until the business defines the requirement
