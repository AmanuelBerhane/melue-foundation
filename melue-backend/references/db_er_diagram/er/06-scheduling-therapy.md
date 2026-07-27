# Module 06 — Scheduling & Active Therapy

**Tables owned:** `teacher_student_assignments`, `staff_availability`, `therapy_sessions`, `session_participants`, `trials`, `behavior_incidents`, `session_summaries`

**Cross-module stubs:** `staff_members` (→ 01-identity), `students` (→ 03-students), `users` (→ 01-identity), `session_block_definitions` (→ 02-configuration), `therapy_stations` (→ 02-configuration), `therapy_rooms` (→ 02-configuration), `prompt_levels` (→ 02-configuration), `student_goals` (→ 05-iup-goals), `student_goal_steps` (→ 05-iup-goals)

```mermaid
erDiagram

    %% ── Owned tables ──────────────────────────────────────────

    teacher_student_assignments {
        uuid id PK
        uuid teacher_id FK
        uuid student_id FK
        uuid session_block_definition_id FK
        uuid station_id FK
        uuid room_id FK
        date scheduled_date
        varchar status
        timestamp created_at
        timestamp updated_at
    }

    staff_availability {
        uuid id PK
        uuid staff_member_id FK
        uuid session_block_definition_id FK
        date unavailable_date
        varchar reason
        timestamp created_at
    }

    therapy_sessions {
        uuid id PK
        uuid teacher_id FK
        uuid session_block_definition_id FK
        uuid station_id FK
        uuid room_id FK
        timestamp started_at
        timestamp ended_at
        varchar status
        timestamp created_at
        timestamp updated_at
    }

    session_participants {
        uuid id PK
        uuid therapy_session_id FK
        uuid student_id FK
        uuid teacher_student_assignment_id FK
        varchar card_position
        timestamp created_at
    }

    trials {
        uuid id PK "client-assigned"
        uuid therapy_session_id FK
        uuid session_participant_id FK
        uuid student_goal_id FK
        uuid student_goal_step_id FK
        uuid prompt_level_id FK
        varchar outcome
        timestamp logged_at
    }

    behavior_incidents {
        uuid id PK "client-assigned"
        uuid therapy_session_id FK
        uuid session_participant_id FK
        uuid active_student_goal_id FK
        uuid recorded_by_user_id FK
        timestamp occurred_at
        varchar behavior_name_snapshot
        text behavior_definition_snapshot
        varchar frequency_snapshot
        varchar intensity_snapshot
        varchar category_snapshot
        varchar location_snapshot
        text antecedent_snapshot
        text consequence_snapshot
        text antecedent_other_text
        text consequence_other_text
        text notes
    }

    session_summaries {
        uuid id PK
        uuid therapy_session_id FK
        text qualitative_notes
        varchar status
        uuid reviewed_by_user_id FK
        timestamp reviewed_at
        timestamp created_at
        timestamp updated_at
    }

    %% ── Cross-module stubs ────────────────────────────────────

    staff_members {
        uuid id PK
        %% see 01-identity.md
    }

    students {
        uuid id PK
        %% see 03-students.md
    }

    users {
        uuid id PK
        %% see 01-identity.md
    }

    session_block_definitions {
        uuid id PK
        %% see 02-configuration.md
    }

    therapy_stations {
        uuid id PK
        %% see 02-configuration.md
    }

    therapy_rooms {
        uuid id PK
        %% see 02-configuration.md
    }

    prompt_levels {
        uuid id PK
        %% see 02-configuration.md
    }

    student_goals {
        uuid id PK
        %% see 05-iup-goals.md
    }

    student_goal_steps {
        uuid id PK
        %% see 05-iup-goals.md
    }

    %% ── Relationships ─────────────────────────────────────────

    staff_members ||--o{ teacher_student_assignments : "teacher"
    students ||--o{ teacher_student_assignments : "student"
    session_block_definitions ||--o{ teacher_student_assignments : "scheduled in"
    therapy_stations ||--o{ teacher_student_assignments : "at station"
    therapy_rooms ||--o{ teacher_student_assignments : "in room"

    staff_members ||--o{ staff_availability : "marks unavailable"
    session_block_definitions ||--o{ staff_availability : "for block"

    staff_members ||--o{ therapy_sessions : "teacher"
    session_block_definitions ||--o{ therapy_sessions : "block"
    therapy_stations ||--o{ therapy_sessions : "at station"
    therapy_rooms ||--o{ therapy_sessions : "in room"

    therapy_sessions ||--o{ session_participants : "includes"
    students ||--o{ session_participants : "participates"
    teacher_student_assignments ||--o{ session_participants : "fulfills"

    therapy_sessions ||--o{ trials : "records"
    session_participants ||--o{ trials : "for participant"
    student_goals ||--o{ trials : "against goal"
    student_goal_steps ||--o{ trials : "step"
    prompt_levels ||--o{ trials : "prompt"

    therapy_sessions ||--o{ behavior_incidents : "records"
    session_participants ||--o{ behavior_incidents : "for participant"
    student_goals ||--o{ behavior_incidents : "active goal"
    users ||--o{ behavior_incidents : "recorded by"

    therapy_sessions ||--o| session_summaries : "summarized by"
    users ||--o{ session_summaries : "reviewed by"
```

**Enum values**

| Column | Values |
|---|---|
| `teacher_student_assignments.status` | `scheduled`, `cancelled`, `completed` |
| `therapy_sessions.status` | `in_progress`, `submitted`, `reviewed` |
| `session_participants.card_position` | `active`, `secondary` |
| `trials.outcome` | `correct`, `incorrect`, `no_response` |
| `session_summaries.status` | `draft`, `submitted`, `reviewed` |

**Key rules**
- A student cannot be assigned to more than one teacher in the same `session_block_definition` / `scheduled_date` combination
- A teacher cannot exceed `scheduling_policy.staff_student_capacity` assignments per block per date
- `trials.id` and `behavior_incidents.id` are **client-assigned UUIDs** — the server stores them as-is; a duplicate submission of the same UUID is a no-op, not a duplicate record
- `trials.student_goal_step_id` is required when the goal type is `task_analysis`; it must be absent for `standard` goals
- Every `behavior_incident` must reference a `session_participant`, an active `student_goal`, and a `recorded_by_user_id`
- All `behavior_incident` snapshot columns preserve the label/definition values at the time of recording — configuration changes cannot rewrite clinical history
- A `session_summary` transitions to `submitted` via the `/therapy-sessions/{id}/submit` command endpoint, not via a direct status write
