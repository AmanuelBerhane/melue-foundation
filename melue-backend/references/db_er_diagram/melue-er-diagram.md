# Melue Foundation — Entity Relationship Diagram

> Generated from the domain model and OpenAPI specification.
> Notation: PK = primary key, FK = foreign key, UK = unique key.

```mermaid
erDiagram

    %% =========================================================
    %% 1. IDENTITY, ACCESS & AUDIT
    %% =========================================================

    users {
        uuid id PK
        varchar email UK
        varchar password_digest
        varchar status
        timestamp locked_until
        timestamp created_at
        timestamp updated_at
    }

    staff_members {
        uuid id PK
        uuid user_id FK
        varchar full_name
        varchar staff_number UK
        timestamp created_at
        timestamp updated_at
    }

    guardians {
        uuid id PK
        uuid user_id FK
        varchar full_name
        varchar phone
        timestamp created_at
        timestamp updated_at
    }

    roles {
        uuid id PK
        varchar name UK
        boolean is_system_critical
        boolean is_active
        timestamp created_at
        timestamp updated_at
    }

    role_assignments {
        uuid id PK
        uuid user_id FK
        uuid role_id FK
        timestamp assigned_at
        timestamp revoked_at
    }

    permissions {
        uuid id PK
        uuid role_id FK
        varchar module
        varchar action
    }

    user_sessions {
        uuid id PK
        uuid user_id FK
        varchar device_identifier
        boolean remembered_device
        timestamp expires_at
        timestamp created_at
    }

    password_reset_requests {
        uuid id PK
        uuid user_id FK
        timestamp expires_at
        timestamp used_at
        timestamp created_at
    }

    audit_entries {
        uuid id PK
        uuid actor_user_id FK
        timestamp occurred_at
        varchar action
        varchar target_type
        uuid target_id
        varchar data_classification
    }

    %% =========================================================
    %% 2. CLINICAL CONFIGURATION, FORMS & FACILITIES
    %% =========================================================

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

    %% =========================================================
    %% 3. STUDENTS, ENROLLMENT, CONSENT & DATA RIGHTS
    %% =========================================================

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

    %% =========================================================
    %% 4. SIX-WEEK ASSESSMENT
    %% =========================================================

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

    %% =========================================================
    %% 5. IUP, GOAL BANK & MASTERY GOVERNANCE
    %% =========================================================

    goal_domains {
        uuid id PK
        varchar name UK
        text description
        int display_order
        boolean is_active
        timestamp created_at
        timestamp updated_at
    }

    goals {
        uuid id PK
        uuid goal_domain_id FK
        varchar name
        varchar type
        text description
        jsonb mastery_criteria_template
        jsonb suggested_age_range
        jsonb applicable_therapy_groups
        boolean is_active
        timestamp created_at
        timestamp updated_at
    }

    task_analysis_step_templates {
        uuid id PK
        uuid goal_id FK
        int step_number
        text description
        jsonb mastery_criteria
        timestamp created_at
    }

    iups {
        uuid id PK
        uuid student_id FK
        uuid assessment_cycle_id FK
        uuid form_submission_id FK
        varchar status
        date finalized_on
        timestamp created_at
        timestamp updated_at
    }

    iup_signatures {
        uuid id PK
        uuid iup_id FK
        uuid signer_user_id FK
        varchar signer_role
        timestamp signed_at
        text signature_evidence
    }

    student_goals {
        uuid id PK
        uuid iup_id FK
        uuid student_id FK
        uuid goal_id FK
        uuid station_id FK
        varchar status
        decimal progress_percent
        text clinical_note
        timestamp created_at
        timestamp updated_at
    }

    student_goal_steps {
        uuid id PK
        uuid student_goal_id FK
        uuid task_analysis_step_template_id FK
        int step_number
        decimal independence_percent
        varchar status
        timestamp created_at
        timestamp updated_at
    }

    goal_mastery_checks {
        uuid id PK
        uuid student_goal_id FK
        uuid primary_teacher_id FK
        varchar status
        decimal primary_independence_percent
        timestamp submitted_at
        text rejection_reason
        timestamp created_at
        timestamp updated_at
    }

    mastery_verifications {
        uuid id PK
        uuid mastery_check_id FK
        uuid verifier_id FK
        varchar outcome
        uuid prompt_level_id FK
        text notes
        timestamp verified_at
    }

    %% =========================================================
    %% 6. SCHEDULING, ACTIVE THERAPY & SESSION SUMMARY
    %% =========================================================

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

    %% =========================================================
    %% 7. COMMUNICATION, NOTIFICATIONS & REPORTING
    %% =========================================================

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

    %% =========================================================
    %% RELATIONSHIPS
    %% =========================================================

    %% Identity
    users ||--o| staff_members : "has profile"
    users ||--o| guardians : "portal account"
    users ||--o{ role_assignments : "assigned"
    roles ||--o{ role_assignments : "assigned to"
    roles ||--o{ permissions : "grants"
    users ||--o{ user_sessions : "opens"
    users ||--o{ password_reset_requests : "requests"
    users ||--o{ audit_entries : "actor"

    %% Facilities & Configuration
    therapy_stations ||--o{ therapy_rooms : "contains"
    form_definitions ||--o{ form_revisions : "versions"
    form_revisions ||--o{ form_field_definitions : "defines fields"
    form_revisions ||--o{ form_submissions : "snapshot"

    %% Students & Enrollment
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

    %% Assessment
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

    %% IUP & Goals
    goal_domains ||--o{ goals : "groups"
    goals ||--o{ task_analysis_step_templates : "defines steps"
    students ||--o{ iups : "has"
    assessment_cycles ||--o{ iups : "informs"
    iups }o--|| form_submissions : "uses"
    iups ||--o{ iup_signatures : "signed by"
    users ||--o{ iup_signatures : "signer"
    iups ||--o{ student_goals : "owns"
    goals ||--o{ student_goals : "selected"
    therapy_stations ||--o{ student_goals : "practiced at"
    student_goals ||--o{ student_goal_steps : "instantiates"
    task_analysis_step_templates ||--o{ student_goal_steps : "from template"
    student_goals ||--o{ goal_mastery_checks : "submits"
    staff_members ||--o{ goal_mastery_checks : "primary teacher"
    goal_mastery_checks ||--o{ mastery_verifications : "verified by"
    staff_members ||--o{ mastery_verifications : "verifier"
    prompt_levels ||--o{ mastery_verifications : "prompt level"

    %% Scheduling
    staff_members ||--o{ teacher_student_assignments : "teacher"
    students ||--o{ teacher_student_assignments : "student"
    session_block_definitions ||--o{ teacher_student_assignments : "scheduled in"
    therapy_stations ||--o{ teacher_student_assignments : "at station"
    therapy_rooms ||--o{ teacher_student_assignments : "in room"
    staff_members ||--o{ staff_availability : "marks unavailable"
    session_block_definitions ||--o{ staff_availability : "for block"

    %% Active Therapy
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

    %% Communication
    students ||--o{ parent_communications : "concerns"
    guardians ||--o{ parent_communications : "communicates"
    users ||--o{ parent_communications : "sender"
    students ||--o{ home_observations : "for"
    guardians ||--o{ home_observations : "submitted by"
    users ||--o{ notifications : "recipient"
```
