# Module 02 — Clinical Configuration, Forms & Facilities

**Tables owned:** `therapy_stations`, `therapy_rooms`, `session_block_definitions`, `scheduling_policy`, `trial_logging_configuration`, `mastery_policy`, `prompt_levels`, `abc_options`, `form_definitions`, `form_revisions`, `form_field_definitions`, `form_submissions`, `item_subscale_mappings`

**Cross-module stubs:** _(none — configuration tables are referenced by other modules, not the reverse)_

```mermaid
erDiagram

    therapy_stations {
        uuid id PK
        varchar name UK
        timestamp created_at
        timestamp updated_at
    }

    therapy_rooms {
        uuid id PK
        uuid station_id FK
        varchar name
        timestamp created_at
        timestamp updated_at
    }

    session_block_definitions {
        uuid id PK
        varchar name
        time start_time
        time end_time
        varchar round
        boolean is_active
        timestamp created_at
        timestamp updated_at
    }

    scheduling_policy {
        uuid id PK
        int staff_student_capacity
        int draft_expiry_days
        int pre_therapy_duration_minutes
        int station1_duration_minutes
        int station2_duration_minutes
        timestamp updated_at
    }

    trial_logging_configuration {
        uuid id PK
        varchar layout
        int stream_count
        timestamp updated_at
    }

    mastery_policy {
        uuid id PK
        int consecutive_trials_required
        decimal percentage_threshold
        boolean automatic_suggestion_enabled
        varchar final_approver_role
        timestamp updated_at
    }

    prompt_levels {
        uuid id PK
        varchar label UK
        varchar color
        int display_order
        boolean is_active
        timestamp created_at
        timestamp updated_at
    }

    abc_options {
        uuid id PK
        varchar option_type
        varchar label
        int display_order
        boolean is_active
        boolean is_other
        text definition
        timestamp created_at
        timestamp updated_at
    }

    form_definitions {
        uuid id PK
        varchar purpose
        varchar name
        timestamp created_at
        timestamp updated_at
    }

    form_revisions {
        uuid id PK
        uuid form_definition_id FK
        varchar revision_number
        date revision_date
        varchar form_name
        varchar organization_name
        boolean is_active
        timestamp created_at
    }

    form_field_definitions {
        uuid id PK
        uuid form_revision_id FK
        varchar field_key
        varchar label
        varchar field_type
        boolean required
        boolean visible
        int display_order
        text validation_rules
    }

    form_submissions {
        uuid id PK
        uuid form_revision_id FK
        varchar status
        jsonb values
        timestamp created_at
        timestamp updated_at
    }

    item_subscale_mappings {
        uuid id PK
        varchar behavior_instrument
        int item_number
        varchar subscale
        timestamp created_at
    }

    therapy_stations ||--o{ therapy_rooms : "contains"
    form_definitions ||--o{ form_revisions : "versions"
    form_revisions ||--o{ form_field_definitions : "defines fields"
    form_revisions ||--o{ form_submissions : "snapshot"
```

**Enum values**

| Column | Values |
|---|---|
| `trial_logging_configuration.layout` | `horizontal`, `vertical`, `card_grid` |
| `form_definitions.purpose` | `enrollment`, `iup`, `ablls`, `social_skills_questionnaire` |
| `form_submissions.status` | `draft`, `submitted` |
| `abc_options.option_type` | `behavior`, `antecedent`, `consequence`, `location`, `frequency`, `intensity`, `category` |

**Key rules**
- `scheduling_policy` is a singleton — one row per organisation; use PUT to update, never POST a second row
- `trial_logging_configuration.stream_count` must be between 3 and 20
- A submitted `form_submission` is permanently linked to its `form_revision`; its `values` column is immutable after submission
- `item_subscale_mappings` seeds the MAS-II scoring key: 16 rows mapping `question_number` 1–16 to subscales Sensory, Escape, Attention, Tangible
- `session_block_definitions.end_time` must be later than `start_time`
