# Module 03 — Students, Enrollment, Consent & Data Rights

**Tables owned:** `students`, `student_guardians`, `enrollments`, `student_attachments`, `consent_records`, `data_subject_requests`, `internal_student_notes`

**Cross-module stubs:** `users` (→ 01-identity), `guardians` (→ 01-identity), `form_submissions` (→ 02-configuration)

```mermaid
erDiagram

    %% ── Owned tables ──────────────────────────────────────────

    students {
        uuid id PK
        varchar first_name
        varchar last_name
        varchar middle_name
        date date_of_birth
        varchar diagnosis
        varchar program_type
        varchar therapy_group
        varchar status
        timestamp created_at
        timestamp updated_at
    }

    student_guardians {
        uuid id PK
        uuid student_id FK
        uuid guardian_id FK
        varchar relationship
        boolean is_primary_contact
        timestamp created_at
    }

    enrollments {
        uuid id PK
        uuid student_id FK
        uuid form_submission_id FK
        varchar status
        date enrollment_date
        timestamp created_at
        timestamp updated_at
    }

    student_attachments {
        uuid id PK
        uuid student_id FK
        varchar kind
        varchar media_type
        text secure_uri
        timestamp captured_at
        boolean is_required
        timestamp created_at
    }

    consent_records {
        uuid id PK
        uuid student_id FK
        uuid guardian_id FK
        varchar scope
        timestamp granted_at
        timestamp withdrawn_at
        text consent_wording_snapshot
    }

    data_subject_requests {
        uuid id PK
        uuid student_id FK
        uuid requested_by_guardian_id FK
        varchar type
        varchar status
        uuid approved_by_user_id FK
        timestamp created_at
        timestamp updated_at
    }

    internal_student_notes {
        uuid id PK
        uuid student_id FK
        uuid author_id FK
        text content
        timestamp recorded_at
    }

    %% ── Cross-module stubs ────────────────────────────────────

    guardians {
        uuid id PK
        %% see 01-identity.md
    }

    users {
        uuid id PK
        %% see 01-identity.md
    }

    form_submissions {
        uuid id PK
        %% see 02-configuration.md
    }

    %% ── Relationships ─────────────────────────────────────────

    students ||--o{ student_guardians : "linked to"
    guardians ||--o{ student_guardians : "linked to"
    students ||--|| enrollments : "enrolled through"
    enrollments }o--|| form_submissions : "uses"
    students ||--o{ student_attachments : "owns"
    students ||--o{ consent_records : "has"
    guardians ||--o{ consent_records : "granted by"
    students ||--o{ data_subject_requests : "subject of"
    guardians ||--o{ data_subject_requests : "requested by"
    users ||--o{ data_subject_requests : "approved by"
    students ||--o{ internal_student_notes : "noted in"
    users ||--o{ internal_student_notes : "authored by"
```

**Enum values**

| Column | Values |
|---|---|
| `students.program_type` | `regular`, `pulled_out` |
| `students.therapy_group` | `basic`, `functional_living` |
| `students.status` | `in_assessment`, `assessment_complete`, `ready_for_iup`, `active_therapy`, `withdrawn`, `discharged` |
| `enrollments.status` | `draft`, `confirmed`, `purged` |
| `student_attachments.kind` | `birth_certificate`, `medical_diagnosis`, `agreement`, `headshot`, `baseline_video` |
| `consent_records.scope` | `child_data`, `medical_records`, `photos`, `video`, `audio_recording` |
| `data_subject_requests.type` | `access`, `erasure` |
| `data_subject_requests.status` | `pending`, `approved`, `completed` |
| `student_guardians.relationship` | `parent`, `legal_guardian`, `other` |

**Key rules**
- Enrollment confirmation requires: all required form fields, at least one primary guardian, required consents, and the headshot attachment
- Confirming enrollment transitions `students.status` to `in_assessment`
- Basic Therapy age expectation is 3–12; Functional Living Skills is 13–19 — a mismatch triggers a warning, not a hard rejection
- `internal_student_notes` must never be returned by parent or teacher-facing API endpoints
- Erasure requests require Director approval and must produce an `audit_entries` record
