# Module 04 — Six-Week Assessment

**Tables owned:** `assessment_cycles`, `skills_assessments`, `ablls_skill_definitions`, `ablls_scores`, `behavior_assessments`, `behavior_function_analyses`, `motivation_assessment_scales`, `mas_responses`, `fast_screenings`, `fast_responses`, `assessment_abc_observations`, `preference_assessments`, `preference_inventory_items`, `preference_observations`, `sensory_time_assessments`, `sensory_activity_definitions`, `sensory_activity_results`, `social_skills_questionnaires`

**Cross-module stubs:** `students` (→ 03-students), `users` (→ 01-identity), `abc_options` (→ 02-configuration), `form_submissions` (→ 02-configuration)

```mermaid
erDiagram

    %% ── Owned tables ──────────────────────────────────────────

    assessment_cycles {
        uuid id PK
        uuid student_id FK
        varchar status
        date started_on
        date completed_on
        timestamp created_at
        timestamp updated_at
    }

    skills_assessments {
        uuid id PK
        uuid assessment_cycle_id FK
        uuid form_submission_id FK
        varchar status
        text need_analysis_summary
        timestamp created_at
        timestamp updated_at
    }

    ablls_skill_definitions {
        uuid id PK
        varchar code UK
        varchar domain
        text description
        boolean is_active
        timestamp created_at
        timestamp updated_at
    }

    ablls_scores {
        uuid id PK
        uuid skills_assessment_id FK
        uuid skill_definition_id FK
        varchar value
        text notes
        timestamp created_at
    }

    behavior_assessments {
        uuid id PK
        uuid assessment_cycle_id FK
        varchar status
        timestamp created_at
        timestamp updated_at
    }

    behavior_function_analyses {
        uuid id PK
        uuid behavior_assessment_id FK
        uuid behavior_definition_id FK
        text operational_definition
        varchar status
        timestamp created_at
        timestamp updated_at
    }

    motivation_assessment_scales {
        uuid id PK
        uuid behavior_function_analysis_id FK
        varchar rater_name
        text setting_description
        varchar frequency_unit
        jsonb subscale_scores
        timestamp created_at
        timestamp updated_at
    }

    mas_responses {
        uuid id PK
        uuid motivation_assessment_scale_id FK
        int question_number
        int likert_score
        timestamp created_at
    }

    fast_screenings {
        uuid id PK
        uuid behavior_function_analysis_id FK
        varchar informant_name
        varchar informant_relationship
        varchar interviewer_name
        int years_known
        int months_known
        boolean daily_interaction
        decimal hours_per_day
        decimal hours_per_week
        jsonb observation_contexts
        jsonb maintaining_variable_scores
        timestamp created_at
        timestamp updated_at
    }

    fast_responses {
        uuid id PK
        uuid fast_screening_id FK
        int question_number
        boolean answer
        timestamp created_at
    }

    assessment_abc_observations {
        uuid id PK
        uuid behavior_function_analysis_id FK
        date occurred_on
        time occurred_at
        varchar location
        text antecedent
        text consequence
        text notes
        uuid recorded_by_user_id FK
        timestamp created_at
    }

    preference_assessments {
        uuid id PK
        uuid assessment_cycle_id FK
        varchar status
        timestamp created_at
        timestamp updated_at
    }

    preference_inventory_items {
        uuid id PK
        varchar name
        varchar category
        boolean is_active
        timestamp created_at
        timestamp updated_at
    }

    preference_observations {
        uuid id PK
        uuid preference_assessment_id FK
        uuid preference_inventory_item_id FK
        varchar context
        boolean approached
        int duration_seconds
        int frequency_count
        decimal combined_score
        varchar tier
        int rank
        text notes
        timestamp created_at
    }

    sensory_time_assessments {
        uuid id PK
        uuid assessment_cycle_id FK
        uuid conducted_by_user_id FK
        varchar status
        timestamp created_at
        timestamp updated_at
    }

    sensory_activity_definitions {
        uuid id PK
        varchar code UK
        varchar name
        text description
        boolean is_active
        timestamp created_at
        timestamp updated_at
    }

    sensory_activity_results {
        uuid id PK
        uuid sensory_time_assessment_id FK
        uuid activity_definition_id FK
        varchar engagement_level
        varchar reaction
        text remark
        timestamp created_at
    }

    social_skills_questionnaires {
        uuid id PK
        uuid assessment_cycle_id FK
        uuid form_submission_id FK
        varchar status
        timestamp created_at
        timestamp updated_at
    }

    %% ── Cross-module stubs ────────────────────────────────────

    students {
        uuid id PK
        %% see 03-students.md
    }

    users {
        uuid id PK
        %% see 01-identity.md
    }

    abc_options {
        uuid id PK
        %% see 02-configuration.md
    }

    form_submissions {
        uuid id PK
        %% see 02-configuration.md
    }

    %% ── Relationships ─────────────────────────────────────────

    students ||--o{ assessment_cycles : "undergoes"

    assessment_cycles ||--o| skills_assessments : "requires"
    assessment_cycles ||--o| behavior_assessments : "requires"
    assessment_cycles ||--o| preference_assessments : "requires"
    assessment_cycles ||--o| sensory_time_assessments : "includes"
    assessment_cycles ||--o| social_skills_questionnaires : "includes"

    skills_assessments }o--|| form_submissions : "uses"
    skills_assessments ||--o{ ablls_scores : "records"
    ablls_skill_definitions ||--o{ ablls_scores : "scored in"

    behavior_assessments ||--o{ behavior_function_analyses : "screens"
    abc_options ||--o{ behavior_function_analyses : "behavior def"
    behavior_function_analyses ||--o| motivation_assessment_scales : "administers"
    motivation_assessment_scales ||--o{ mas_responses : "has"
    behavior_function_analyses ||--o| fast_screenings : "administers"
    fast_screenings ||--o{ fast_responses : "has"
    behavior_function_analyses ||--o{ assessment_abc_observations : "tracks"
    users ||--o{ assessment_abc_observations : "recorded by"

    preference_assessments ||--o{ preference_observations : "observes"
    preference_inventory_items ||--o{ preference_observations : "item"

    sensory_time_assessments ||--o{ sensory_activity_results : "records"
    sensory_activity_definitions ||--o{ sensory_activity_results : "activity"
    users ||--o| sensory_time_assessments : "conducted by"

    social_skills_questionnaires }o--|| form_submissions : "uses"
```

**Enum values**

| Column | Values |
|---|---|
| `assessment_cycles.status` | `in_progress`, `complete`, `reviewed` |
| `skills_assessments.status` | `draft`, `submitted` |
| `ablls_scores.value` | `0`, `1`, `2`, `not_applicable` |
| `behavior_function_analyses.status` | `in_progress`, `complete` |
| `motivation_assessment_scales.frequency_unit` | `year`, `month`, `week`, `day`, `hour` |
| `mas_responses.likert_score` | `0`–`6` |
| `fast_screenings.informant_relationship` | `parent`, `teacher_instructor`, `residential_staff`, `other` |
| `preference_observations.context` | `sensory_time`, `circle_time`, `play_time` |
| `preference_observations.tier` | `highest`, `moderate`, `low` |
| `sensory_activity_results.engagement_level` | `high`, `moderate`, `low`, `none` |
| `sensory_activity_results.reaction` | `positive`, `neutral`, `negative` |

**Key rules**
- An `assessment_cycle` cannot be marked `complete` until `skills_assessments`, `behavior_assessments`, and `preference_assessments` are all submitted
- Marking a cycle `reviewed` transitions the student to `ready_for_iup`
- A `behavior_assessment` is complete only when every child `behavior_function_analyses` row is complete
- `mas_responses` requires all 16 rows (items 1–16) before the MAS scale can be marked complete — no partial saves
- `fast_responses` items 1–3 and 19–27 are always required; items 4–18 are required only if any of items 1–3 is `true`
- `social_skills_questionnaires` uses the same `form_submissions` snapshot pattern — submitted values are immutable
