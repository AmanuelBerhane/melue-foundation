# Design Document: IUP Generation System

## 1. System Overview

The IUP Generation System provides a comprehensive workflow for creating, managing, and finalizing Individual Utility Plans (IUPs) for students completing their assessment cycle. The system implements draft persistence, goal assignment with station-based constraints, multi-signature approval, and automated status transitions.

### 1.1 Core Workflows

1. **Draft Creation & Editing**: Program Directors initiate IUPs from completed assessments with auto-populated summaries
2. **Goal Assignment**: Interactive goal selection from goal bank with 2-per-station rule enforcement
3. **Preview & Validation**: Pre-finalization validation with complete IUP preview
4. **Signature Collection**: Sequential Program Director and Guardian signature capture
5. **Finalization**: Automated status transitions (IUP → active, Student → active_therapy, previous IUP → archived)
6. **Library Management**: Search, filter, view, and export IUPs across all students

## 2. Architecture & Components

### 2.1 System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     API Layer (Controllers)                  │
│  IupsController | IupGoalsController | IupSignaturesController│
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────┴──────────────────────────────────────┐
│                   Service Layer (Business Logic)             │
│  Iups::CreateService | Iups::AssignGoalService              │
│  Iups::ValidateService | Iups::FinalizeService              │
│  Iups::SignatureService | Iups::ArchiveService              │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────┴──────────────────────────────────────┐
│                      Domain Models                           │
│  Iup | FormSubmission | IupSignature | StudentGoal          │
│  StudentGoalStep | AssessmentCycle | Student | Goal         │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Data Flow: IUP Creation to Finalization

```
1. Assessment Completed (status: "reviewed")
   ↓
2. Program Director: "Create IUP"
   → Iups::CreateService.call(student:, assessment_cycle:)
   ↓
3. Draft IUP created (status: "draft")
   → FormSubmission created
   → Auto-populated summary from AssessmentCycle
   ↓
4. Goal Assignment (2 per station)
   → Iups::AssignGoalService.call(iup:, goal:, station:)
   → StudentGoal created
   → If task_analysis: StudentGoalStep records created
   ↓
5. Form Section Completion
   → Auto-save every 30 seconds
   → FormSubmission.values updated
   ↓
6. Preview & Validation
   → Iups::ValidateService.call(iup:)
   → Check required fields, goal assignments, assessment status
   ↓
7. Program Director Signature
   → Iups::SignatureService.call(iup:, signer:, role: "program_director")
   → IupSignature created
   ↓
8. Guardian Signature
   → Notification sent to Guardian
   → Iups::SignatureService.call(iup:, signer:, role: "guardian")
   ↓
9. Finalization
   → Iups::FinalizeService.call(iup:)
   → IUP status: draft → active
   → Student status: ready_for_iup → active_therapy
   → Previous active IUP → archived
   → StudentGoals status: → active
```

## 3. Database Schema

### 3.1 New Tables

#### 3.1.1 form_submissions

Stores dynamic form data for IUP content using versioned form definitions.

```ruby
create_table :form_submissions, id: :uuid do |t|
  t.references :form_configuration, null: false, foreign_key: true, type: :bigint
  t.references :submittable, polymorphic: true, null: false, type: :uuid
  t.jsonb :values, null: false, default: {}
  t.string :status, null: false, default: "draft"
  t.datetime :submitted_at
  t.timestamps
  t.datetime :discarded_at

  t.index [:submittable_type, :submittable_id], unique: true
  t.index :values, using: :gin
  t.index :status
  t.index :discarded_at
end
```

- **form_configuration_id**: Links to the form revision used
- **submittable**: Polymorphic association (IUP in this case)
- **values**: JSON storage for all form field values
- **status**: draft, submitted, finalized
- **submitted_at**: Timestamp when form was submitted

#### 3.1.2 iup_signatures

Captures digital signatures for IUP approval.

```ruby
create_table :iup_signatures, id: :uuid do |t|
  t.references :iup, null: false, foreign_key: true, type: :uuid
  t.references :signer_user, null: false, foreign_key: { to_table: :users }, type: :bigint
  t.string :signer_role, null: false
  t.datetime :signed_at, null: false
  t.text :signature_evidence
  t.timestamps

  t.index [:iup_id, :signer_role], unique: true
  t.index :signed_at
  t.check_constraint "signer_role IN ('program_director', 'guardian')"
end
```

- **signer_role**: program_director or guardian
- **signed_at**: Capture timestamp
- **signature_evidence**: Metadata (IP, user agent, or scanned document reference)
- **Unique constraint**: One signature per role per IUP

### 3.2 Schema Modifications

#### 3.2.1 iups table additions

```ruby
add_column :iups, :assessment_cycle_id, :uuid
add_column :iups, :finalized_by_user_id, :bigint
add_column :iups, :finalized_on, :date
add_column :iups, :created_by_user_id, :bigint

add_foreign_key :iups, :assessment_cycles
add_foreign_key :iups, :users, column: :finalized_by_user_id
add_foreign_key :iups, :users, column: :created_by_user_id

add_index :iups, :assessment_cycle_id
add_index :iups, [:student_id, :status], where: "status = 'active'"
```

#### 3.2.2 goals table additions

```ruby
add_column :goals, :suggested_age_range, :string
add_column :goals, :applicable_therapy_groups, :string, array: true, default: []
add_column :goals, :mastery_criteria, :jsonb, default: {}

add_index :goals, :applicable_therapy_groups, using: :gin
```

#### 3.2.3 student_goals table validation

```ruby
add_index :student_goals, [:iup_id, :therapy_station_id]

# Application-level validation: max 2 active goals per (iup_id, therapy_station_id)
```

### 3.3 Entity Relationship Diagram

```
┌─────────────────┐       ┌──────────────────┐
│ AssessmentCycle │       │ FormConfiguration│
│  - status       │       │  - form_type     │
│  - completed_on │       │  - field_schema  │
└────────┬────────┘       └────────┬─────────┘
         │                         │
         │ 1                       │ 1
         │                         │
         │                         │
         ▼ 1                       ▼ *
┌─────────────────┐       ┌──────────────────┐
│      IUP        │◄─────►│ FormSubmission   │
│  - status       │  1:1  │  - values (jsonb)│
│  - finalized_on │       │  - status        │
└────────┬────────┘       └──────────────────┘
         │
         │ 1
         │
         ▼ *
┌─────────────────┐       ┌──────────────────┐
│ IupSignature    │       │  StudentGoal     │
│  - signer_role  │       │  - status        │
│  - signed_at    │       │  - progress_%    │
└─────────────────┘       └────────┬─────────┘
         ▲                         │
         │                         │ 1
         │ 2                       │
         │                         ▼ *
┌─────────────────┐       ┌──────────────────┐
│     User        │       │ StudentGoalStep  │
│  - role         │       │  - step_number   │
└─────────────────┘       │  - independence_%│
                          └──────────────────┘
```

## 4. Service Layer Design

### 4.1 Service Responsibilities

All services inherit from `ApplicationService` and return `ServiceResult` objects.

#### 4.1.1 Iups::CreateService

**Purpose**: Initialize a new draft IUP from a completed assessment cycle.

```ruby
# app/services/iups/create_service.rb
module Iups
  class CreateService < ApplicationService
    def initialize(student:, assessment_cycle:, current_user:)
      @student = student
      @assessment_cycle = assessment_cycle
      @current_user = current_user
    end

    def call
      validate_preconditions
      create_draft_iup
      create_form_submission
      populate_assessment_summary
      success(iup: @iup)
    rescue ValidationError => e
      failure(e.message)
    end

    private

    def validate_preconditions
      unless @assessment_cycle.status_reviewed?
        raise ValidationError, "Assessment cycle must be completed and reviewed"
      end
      
      if Iup.where(student: @student, status: "draft").exists?
        raise ValidationError, "Student already has a draft IUP"
      end
    end

    def create_draft_iup
      @iup = Iup.create!(
        student: @student,
        assessment_cycle: @assessment_cycle,
        status: "draft",
        created_by_user: @current_user
      )
    end

    def create_form_submission
      form_config = FormConfiguration.find_by(form_type: "iup", is_default: true)
      
      FormSubmission.create!(
        submittable: @iup,
        form_configuration: form_config,
        status: "draft",
        values: {}
      )
    end

    def populate_assessment_summary
      summary_data = Iups::AssessmentSummaryBuilder.call(
        assessment_cycle: @assessment_cycle
      )
      
      form_submission = @iup.form_submission
      form_submission.update!(
        values: form_submission.values.merge(
          "assessment_summary" => summary_data
        )
      )
    end
  end
end
```

**Business Rules**:
- Assessment cycle must have status "reviewed"
- Only one draft IUP per student allowed
- Auto-populate summary from assessment data
- Create linked FormSubmission with default IUP form

#### 4.1.2 Iups::AssignGoalService

**Purpose**: Assign a goal from the goal bank to a therapy station with validation.

```ruby
# app/services/iups/assign_goal_service.rb
module Iups
  class AssignGoalService < ApplicationService
    def initialize(iup:, goal:, therapy_station:)
      @iup = iup
      @goal = goal
      @therapy_station = therapy_station
      @student = iup.student
    end

    def call
      validate_goal_eligibility
      validate_station_capacity
      assign_goal
      create_task_analysis_steps if @goal.goal_type_task_analysis?
      success(student_goal: @student_goal)
    rescue ValidationError => e
      failure(e.message)
    end

    private

    def validate_goal_eligibility
      unless @goal.is_active?
        raise ValidationError, "Goal is not active"
      end

      therapy_group = @student.therapy_group
      unless @goal.applicable_therapy_groups.include?(therapy_group)
        raise ValidationError, "Goal '#{@goal.name}' is not applicable to #{therapy_group} therapy group"
      end
    end

    def validate_station_capacity
      existing_count = StudentGoal.where(
        iup: @iup,
        therapy_station: @therapy_station,
        status: "active"
      ).count

      if existing_count >= 2
        raise ValidationError, "Maximum 2 active goals per station - remove or replace existing goals first"
      end
    end

    def assign_goal
      @student_goal = StudentGoal.create!(
        iup: @iup,
        student: @student,
        goal: @goal,
        therapy_station: @therapy_station,
        status: "active",
        progress_percent: 0.0
      )
      
      AuditLog.create!(
        resource_type: "StudentGoal",
        resource_id: @student_goal.id.to_s,
        action: "goal_assigned",
        user_id: Current.user&.id,
        change_data: {
          goal_id: @goal.id,
          goal_name: @goal.name,
          station_id: @therapy_station.id,
          iup_id: @iup.id
        }
      )
    end

    def create_task_analysis_steps
      templates = @goal.task_analysis_step_templates.order(:step_number)
      
      templates.each do |template|
        StudentGoalStep.create!(
          student_goal: @student_goal,
          task_analysis_step_template: template,
          step_number: template.step_number,
          name: template.name,
          description: template.description,
          status: "not_started",
          independence_percent: 0.0
        )
      end
    end
  end
end
```

**Business Rules**:
- Goal must be active (is_active = true)
- Goal's applicable_therapy_groups must include student's therapy_group
- Maximum 2 active StudentGoals per (iup_id, therapy_station_id)
- Task analysis goals automatically create StudentGoalStep records
- All operations logged to audit trail

#### 4.1.3 Iups::ValidateService

**Purpose**: Pre-finalization validation of IUP completeness.

```ruby
# app/services/iups/validate_service.rb
module Iups
  class ValidateService < ApplicationService
    def initialize(iup:)
      @iup = iup
      @errors = []
    end

    def call
      validate_assessment_status
      validate_required_form_fields
      validate_goal_assignments
      validate_goal_station_limits
      
      if @errors.any?
        failure(errors: @errors)
      else
        success(valid: true)
      end
    end

    private

    def validate_assessment_status
      unless @iup.assessment_cycle&.status_reviewed?
        @errors << "Assessment cycle must be reviewed before finalization"
      end
    end

    def validate_required_form_fields
      form_submission = @iup.form_submission
      form_config = form_submission.form_configuration
      
      required_fields = form_config.field_schema.select { |f| f["required"] == true }
      
      required_fields.each do |field|
        field_key = field["key"]
        value = form_submission.values[field_key]
        
        if value.nil? || value.to_s.strip.empty?
          @errors << "Required field: #{field['label']} must be completed"
        end
      end
    end

    def validate_goal_assignments
      applicable_stations = therapy_stations_for_student
      
      applicable_stations.each do |station|
        goal_count = StudentGoal.where(
          iup: @iup,
          therapy_station: station,
          status: "active"
        ).count
        
        if goal_count < 1
          @errors << "Station '#{station.name}' requires at least 1 goal for finalization"
        end
      end
    end

    def validate_goal_station_limits
      applicable_stations = therapy_stations_for_student
      
      applicable_stations.each do |station|
        goal_count = StudentGoal.where(
          iup: @iup,
          therapy_station: station,
          status: "active"
        ).count
        
        if goal_count > 2
          @errors << "Station '#{station.name}' has too many goals (max 2 allowed)"
        end
      end
    end

    def therapy_stations_for_student
      # Logic to determine applicable stations based on student's therapy program
      # For now, return all active stations
      TherapyStation.where(discarded_at: nil)
    end
  end
end
```

**Validation Rules**:
- Assessment cycle status must be "reviewed"
- All required form fields must have non-empty values
- At least 1 goal per applicable therapy station
- Maximum 2 goals per therapy station

#### 4.1.4 Iups::SignatureService

**Purpose**: Capture Program Director or Guardian signature.

```ruby
# app/services/iups/signature_service.rb
module Iups
  class SignatureService < ApplicationService
    def initialize(iup:, signer_user:, signer_role:, signature_evidence: nil)
      @iup = iup
      @signer_user = signer_user
      @signer_role = signer_role
      @signature_evidence = signature_evidence
    end

    def call
      validate_signer_authorization
      capture_signature
      send_guardian_notification if @signer_role == "program_director"
      success(signature: @signature)
    rescue ValidationError => e
      failure(e.message)
    end

    private

    def validate_signer_authorization
      case @signer_role
      when "program_director"
        unless has_program_director_role?
          raise ValidationError, "User must have Program Director role"
        end
      when "guardian"
        unless is_students_guardian?
          raise ValidationError, "User must be associated guardian for this student"
        end
      else
        raise ValidationError, "Invalid signer role: #{@signer_role}"
      end
    end

    def capture_signature
      @signature = IupSignature.find_or_initialize_by(
        iup: @iup,
        signer_role: @signer_role
      )
      
      @signature.update!(
        signer_user: @signer_user,
        signed_at: Time.current,
        signature_evidence: @signature_evidence || build_signature_evidence
      )
      
      AuditLog.create!(
        resource_type: "IupSignature",
        resource_id: @signature.id.to_s,
        action: "signature_captured",
        user_id: @signer_user.id,
        change_data: {
          iup_id: @iup.id,
          signer_role: @signer_role
        }
      )
    end

    def send_guardian_notification
      guardian = @iup.student.student_guardians.find_by(is_primary_contact: true)&.guardian
      
      return unless guardian&.user
      
      NotificationService.notify(
        recipient: guardian.user,
        type: "IupSignatureRequest",
        payload: {
          iup_id: @iup.id,
          student_name: @iup.student.full_name
        }
      )
    end

    def has_program_director_role?
      @signer_user.role_assignments.active.joins(:role).exists?(
        roles: { name: "Program Director" }
      )
    end

    def is_students_guardian?
      Guardian.joins(:student_guardians).exists?(
        user_id: @signer_user.id,
        student_guardians: { student_id: @iup.student_id }
      )
    end

    def build_signature_evidence
      {
        ip_address: Current.request&.remote_ip,
        user_agent: Current.request&.user_agent,
        timestamp: Time.current.iso8601
      }.to_json
    end
  end
end
```

**Business Rules**:
- Program Director signature requires "Program Director" role
- Guardian signature requires Guardian association with student
- Signature evidence captures metadata for audit trail
- Program Director signature triggers guardian notification
- Allow re-signature (update existing signature record)

#### 4.1.5 Iups::FinalizeService

**Purpose**: Execute finalization workflow with status transitions.

```ruby
# app/services/iups/finalize_service.rb
module Iups
  class FinalizeService < ApplicationService
    def initialize(iup:, finalized_by_user:)
      @iup = iup
      @finalized_by_user = finalized_by_user
    end

    def call
      validate_signatures_present
      validate_iup_complete
      
      ActiveRecord::Base.transaction do
        archive_previous_active_iup
        finalize_iup
        activate_student_goals
        transition_student_status
        log_finalization
      end
      
      success(iup: @iup.reload)
    rescue ValidationError => e
      failure(e.message)
    end

    private

    def validate_signatures_present
      pd_signature = IupSignature.find_by(iup: @iup, signer_role: "program_director")
      guardian_signature = IupSignature.find_by(iup: @iup, signer_role: "guardian")
      
      unless pd_signature && guardian_signature
        raise ValidationError, "Both Program Director and Guardian signatures required"
      end
    end

    def validate_iup_complete
      validation_result = Iups::ValidateService.call(iup: @iup)
      
      unless validation_result.success?
        raise ValidationError, "IUP validation failed: #{validation_result.error[:errors].join(', ')}"
      end
    end

    def archive_previous_active_iup
      previous_iup = Iup.find_by(student: @iup.student, status: "active")
      
      return unless previous_iup
      
      previous_iup.update!(status: "archived")
      
      StudentGoal.where(iup: previous_iup, status: "active").update_all(
        status: "archived",
        updated_at: Time.current
      )
    end

    def finalize_iup
      @iup.update!(
        status: "active",
        finalized_on: Date.current,
        finalized_by_user: @finalized_by_user
      )
      
      @iup.form_submission.update!(status: "finalized")
    end

    def activate_student_goals
      StudentGoal.where(iup: @iup).update_all(
        status: "active",
        updated_at: Time.current
      )
    end

    def transition_student_status
      student = @iup.student
      
      if student.status == "ready_for_iup"
        student.update!(status: "active_therapy")
      end
    end

    def log_finalization
      AuditLog.create!(
        resource_type: "Iup",
        resource_id: @iup.id.to_s,
        action: "iup_finalized",
        user_id: @finalized_by_user.id,
        change_data: {
          previous_status: "draft",
          new_status: "active",
          student_id: @iup.student_id,
          finalized_on: @iup.finalized_on
        }
      )
    end
  end
end
```

**Business Rules**:
- Both signatures must exist before finalization
- All validation checks must pass
- Previous active IUP automatically archived
- IUP status: draft → active
- Student status: ready_for_iup → active_therapy
- StudentGoals status: → active
- All operations wrapped in database transaction
- Audit log created for finalization event

### 4.2 Supporting Services

#### 4.2.1 Iups::AssessmentSummaryBuilder

Extracts and formats assessment data for IUP summary section.

```ruby
# app/services/iups/assessment_summary_builder.rb
module Iups
  class AssessmentSummaryBuilder < ApplicationService
    def initialize(assessment_cycle:)
      @assessment_cycle = assessment_cycle
    end

    def call
      {
        skills_findings: extract_skills_findings,
        behavior_findings: extract_behavior_findings,
        preference_findings: extract_preference_findings,
        assessment_dates: extract_assessment_dates
      }
    end

    private

    def extract_skills_findings
      # Extract from Skills Assessment (ABLLS or similar)
      # Future implementation based on skills assessment model
      "Skills assessment data pending implementation"
    end

    def extract_behavior_findings
      # Extract from Behavior Function Analysis
      # Future implementation
      "Behavior assessment data pending implementation"
    end

    def extract_preference_findings
      preference_assessment = @assessment_cycle.preference_assessment
      return "No preference data" unless preference_assessment

      highest_items = preference_assessment.preference_observations
        .where(tier: "highest")
        .order(rank: :asc)
        .limit(5)
        .pluck(:custom_item_name)
        .compact

      "Top preferences: #{highest_items.join(', ')}"
    end

    def extract_assessment_dates
      {
        preference_completed: @assessment_cycle.preference_assessment&.submitted_at,
        cycle_completed: @assessment_cycle.completed_on
      }
    end
  end
end
```

#### 4.2.2 Iups::ReplaceGoalService

Replace an existing goal assignment with a new goal.

```ruby
# app/services/iups/replace_goal_service.rb
module Iups
  class ReplaceGoalService < ApplicationService
    def initialize(student_goal:, new_goal:)
      @student_goal = student_goal
      @new_goal = new_goal
      @iup = student_goal.iup
      @therapy_station = student_goal.therapy_station
    end

    def call
      validate_replacement_goal
      
      ActiveRecord::Base.transaction do
        remove_existing_steps
        update_goal_assignment
        create_new_steps if @new_goal.goal_type_task_analysis?
        log_replacement
      end
      
      success(student_goal: @student_goal.reload)
    rescue ValidationError => e
      failure(e.message)
    end

    private

    def validate_replacement_goal
      unless @new_goal.is_active?
        raise ValidationError, "Replacement goal is not active"
      end

      therapy_group = @iup.student.therapy_group
      unless @new_goal.applicable_therapy_groups.include?(therapy_group)
        raise ValidationError, "Replacement goal not applicable to student's therapy group"
      end
    end

    def remove_existing_steps
      @student_goal.student_goal_steps.destroy_all
    end

    def update_goal_assignment
      old_goal_name = @student_goal.goal.name
      
      @student_goal.update!(
        goal: @new_goal,
        progress_percent: 0.0
      )
      
      @old_goal_name = old_goal_name
    end

    def create_new_steps
      templates = @new_goal.task_analysis_step_templates.order(:step_number)
      
      templates.each do |template|
        StudentGoalStep.create!(
          student_goal: @student_goal,
          task_analysis_step_template: template,
          step_number: template.step_number,
          name: template.name,
          description: template.description,
          status: "not_started",
          independence_percent: 0.0
        )
      end
    end

    def log_replacement
      AuditLog.create!(
        resource_type: "StudentGoal",
        resource_id: @student_goal.id.to_s,
        action: "goal_replaced",
        user_id: Current.user&.id,
        change_data: {
          old_goal_name: @old_goal_name,
          new_goal_id: @new_goal.id,
          new_goal_name: @new_goal.name,
          iup_id: @iup.id
        }
      )
    end
  end
end
```

## 5. API Endpoints

### 5.1 IUP Management

#### POST /api/v1/iups
Create a new draft IUP.

**Request**:
```json
{
  "student_id": "uuid",
  "assessment_cycle_id": "uuid"
}
```

**Response** (201):
```json
{
  "iup": {
    "id": "uuid",
    "student_id": "uuid",
    "assessment_cycle_id": "uuid",
    "status": "draft",
    "created_at": "2026-08-15T10:00:00Z",
    "form_submission": {
      "id": "uuid",
      "values": {
        "assessment_summary": { ... }
      }
    }
  }
}
```

#### GET /api/v1/iups
List IUPs with search and filtering.

**Query Parameters**:
- `status`: draft | active | archived
- `student_name`: partial match (case-insensitive)
- `date_from`: ISO date
- `date_to`: ISO date
- `page`: integer (default: 1)
- `per_page`: integer (default: 50, max: 100)

**Response** (200):
```json
{
  "iups": [
    {
      "id": "uuid",
      "student": { "id": "uuid", "name": "John Doe" },
      "status": "active",
      "finalized_on": "2026-08-01",
      "assessment_cycle_period": "2026-06-01 to 2026-07-15",
      "created_at": "2026-07-20T10:00:00Z"
    }
  ],
  "pagination": {
    "current_page": 1,
    "per_page": 50,
    "total_count": 125,
    "total_pages": 3
  }
}
```

#### GET /api/v1/iups/:id
Retrieve complete IUP details.

**Response** (200):
```json
{
  "iup": {
    "id": "uuid",
    "student": { ... },
    "status": "active",
    "finalized_on": "2026-08-01",
    "form_submission": {
      "values": { ... }
    },
    "student_goals": [
      {
        "id": "uuid",
        "goal": { "id": "uuid", "name": "Identify colors" },
        "therapy_station": { "id": "uuid", "name": "Station 1" },
        "status": "active",
        "progress_percent": 45.5,
        "student_goal_steps": [ ... ]
      }
    ],
    "signatures": [
      {
        "signer_role": "program_director",
        "signer_name": "Dr. Smith",
        "signed_at": "2026-07-30T14:00:00Z"
      }
    ]
  }
}
```

#### PATCH /api/v1/iups/:id
Update draft IUP form values (auto-save).

**Request**:
```json
{
  "form_values": {
    "reinforcement_strategy": "Token economy with visual schedule",
    "crisis_plan": "De-escalation protocol..."
  }
}
```

**Response** (200):
```json
{
  "iup": { ... },
  "saved_at": "2026-08-15T10:05:30Z"
}
```

#### DELETE /api/v1/iups/:id
Delete a draft IUP.

**Response** (204): No content

### 5.2 Goal Assignment

#### POST /api/v1/iups/:iup_id/goals
Assign a goal to a therapy station.

**Request**:
```json
{
  "goal_id": "uuid",
  "therapy_station_id": "uuid"
}
```

**Response** (201):
```json
{
  "student_goal": {
    "id": "uuid",
    "goal": { "id": "uuid", "name": "Count to 10" },
    "therapy_station": { "id": "uuid", "name": "Station 1" },
    "status": "active",
    "progress_percent": 0.0,
    "student_goal_steps": [ ... ]
  }
}
```

#### PATCH /api/v1/iups/:iup_id/goals/:id
Replace an assigned goal.

**Request**:
```json
{
  "new_goal_id": "uuid"
}
```

**Response** (200):
```json
{
  "student_goal": { ... }
}
```

#### DELETE /api/v1/iups/:iup_id/goals/:id
Remove an assigned goal.

**Response** (204): No content

#### GET /api/v1/goals/search
Search goal bank with filters.

**Query Parameters**:
- `q`: search query (name, description)
- `goal_domain_id`: uuid
- `therapy_group`: basic | fls | all
- `page`: integer

**Response** (200):
```json
{
  "goals": [
    {
      "id": "uuid",
      "name": "Identify emotions",
      "description": "Student will identify 5 basic emotions",
      "goal_domain": { "id": "uuid", "name": "Communication" },
      "goal_type": "standard",
      "suggested_age_range": "3-6",
      "applicable_therapy_groups": ["basic"],
      "is_active": true
    }
  ]
}
```

### 5.3 Validation & Preview

#### GET /api/v1/iups/:id/validate
Run pre-finalization validation.

**Response** (200):
```json
{
  "valid": false,
  "errors": [
    "Station 'Station 2' requires at least 1 goal for finalization",
    "Required field: Crisis Plan must be completed"
  ]
}
```

#### GET /api/v1/iups/:id/preview
Generate formatted IUP preview.

**Response** (200):
```json
{
  "preview": {
    "header": {
      "form_name": "Individual Utility Plan",
      "revision": "v2.1",
      "student_name": "John Doe",
      "date_of_birth": "2018-05-15"
    },
    "sections": [ ... ],
    "goals": [ ... ]
  }
}
```

### 5.4 Signature Collection

#### POST /api/v1/iups/:iup_id/signatures
Capture a signature.

**Request**:
```json
{
  "signer_role": "program_director",
  "confirmed": true
}
```

**Response** (201):
```json
{
  "signature": {
    "id": "uuid",
    "iup_id": "uuid",
    "signer_role": "program_director",
    "signer_name": "Dr. Smith",
    "signed_at": "2026-08-15T11:00:00Z"
  }
}
```

### 5.5 Finalization

#### POST /api/v1/iups/:id/finalize
Finalize the IUP (requires both signatures).

**Response** (200):
```json
{
  "iup": {
    "id": "uuid",
    "status": "active",
    "finalized_on": "2026-08-15",
    "student": {
      "id": "uuid",
      "status": "active_therapy"
    }
  },
  "message": "IUP finalized successfully - Student transitioned to Active Therapy"
}
```

### 5.6 PDF Export

#### GET /api/v1/iups/:id/export.pdf
Generate and download IUP as PDF.

**Response** (200):
- Content-Type: application/pdf
- Content-Disposition: attachment; filename="IUP_JohnDoe_2026-08-15.pdf"

## 6. Model Design

### 6.1 Iup Model

```ruby
# app/models/iup.rb
class Iup < ApplicationRecord
  include Discard::Model
  include Auditable

  belongs_to :student
  belongs_to :assessment_cycle
  belongs_to :created_by_user, class_name: "User", foreign_key: :created_by_user_id
  belongs_to :finalized_by_user, class_name: "User", foreign_key: :finalized_by_user_id, optional: true

  has_one :form_submission, as: :submittable, dependent: :destroy
  has_many :student_goals, dependent: :restrict_with_error
  has_many :iup_signatures, dependent: :destroy

  enum :status, { draft: "draft", active: "active", archived: "archived" }, prefix: true

  validates :status, presence: true
  validates :student, presence: true, uniqueness: { scope: :status, conditions: -> { where(status: "draft") } }
  validate :only_one_active_iup_per_student, if: :status_active?

  scope :active, -> { where(status: "active") }
  scope :draft, -> { where(status: "draft") }
  scope :archived, -> { where(status: "archived") }

  delegate :values, to: :form_submission, prefix: true, allow_nil: true

  def program_director_signature
    iup_signatures.find_by(signer_role: "program_director")
  end

  def guardian_signature
    iup_signatures.find_by(signer_role: "guardian")
  end

  def signatures_complete?
    program_director_signature.present? && guardian_signature.present?
  end

  private

  def only_one_active_iup_per_student
    existing = Iup.where(student_id: student_id, status: "active")
    existing = existing.where.not(id: id) if persisted?
    errors.add(:base, "Student already has an active IUP") if existing.exists?
  end
end
```

### 6.2 FormSubmission Model

```ruby
# app/models/form_submission.rb
class FormSubmission < ApplicationRecord
  include Discard::Model

  belongs_to :form_configuration
  belongs_to :submittable, polymorphic: true

  enum :status, { draft: "draft", submitted: "submitted", finalized: "finalized" }, prefix: true

  validates :status, presence: true
  validates :values, presence: true
  validates :submittable, uniqueness: { scope: :submittable_type }

  def update_field(field_key, value)
    new_values = values.dup
    new_values[field_key] = value
    update!(values: new_values)
  end

  def get_field(field_key)
    values[field_key]
  end
end
```

### 6.3 IupSignature Model

```ruby
# app/models/iup_signature.rb
class IupSignature < ApplicationRecord
  belongs_to :iup
  belongs_to :signer_user, class_name: "User", foreign_key: :signer_user_id

  enum :signer_role, { program_director: "program_director", guardian: "guardian" }, prefix: true

  validates :signer_role, presence: true, uniqueness: { scope: :iup_id }
  validates :signed_at, presence: true

  def signer_name
    signer_user&.full_name || "Unknown"
  end
end
```

### 6.4 StudentGoal Model Updates

```ruby
# app/models/student_goal.rb (additions)
class StudentGoal < ApplicationRecord
  # ... existing code ...

  validate :max_two_goals_per_station, on: :create

  private

  def max_two_goals_per_station
    return unless iup && therapy_station

    existing_count = StudentGoal.where(
      iup: iup,
      therapy_station: therapy_station,
      status: "active"
    ).count

    if existing_count >= 2
      errors.add(:base, "Maximum 2 active goals per station")
    end
  end
end
```

### 6.5 Goal Model Updates

```ruby
# app/models/goal.rb (additions)
class Goal < ApplicationRecord
  # ... existing code ...

  def applicable_to_therapy_group?(therapy_group)
    applicable_therapy_groups.empty? || applicable_therapy_groups.include?(therapy_group)
  end

  def self.for_therapy_group(therapy_group)
    where("? = ANY(applicable_therapy_groups) OR applicable_therapy_groups = '{}'", therapy_group)
  end
end
```

## 7. Authorization & Access Control

### 7.1 Role-Based Permissions

| Action | Program Director | Director | Coordinator | Teacher | Guardian |
|--------|-----------------|----------|-------------|---------|----------|
| Create IUP | ✓ | ✓ | ✓ | ✗ | ✗ |
| Edit Draft IUP | ✓ | ✓ | ✓ | ✗ | ✗ |
| Assign Goals | ✓ | ✓ | ✓ | ✗ | ✗ |
| View Active IUP (own students) | ✓ | ✓ | ✓ | ✓ | ✗ |
| View Active IUP (student's) | ✓ | ✓ | ✓ | ✗ | ✓ |
| Finalize IUP | ✓ | ✗ | ✗ | ✗ | ✗ |
| Sign as Program Director | ✓ | ✗ | ✗ | ✗ | ✗ |
| Sign as Guardian | ✗ | ✗ | ✗ | ✗ | ✓ |
| Delete Draft IUP | ✓ | ✓ | ✓ | ✗ | ✗ |
| Export PDF | ✓ | ✓ | ✓ | ✓ | ✓ |
| View IUP Library | ✓ | ✓ | ✓ | ✗ | ✗ |

### 7.2 Controller Authorization

```ruby
# app/controllers/api/v1/iups_controller.rb
class Api::V1::IupsController < Api::V1::BaseController
  include Authorization

  before_action :authenticate_user!
  before_action :authorize_iup_management, only: [:create, :update, :destroy]
  before_action :authorize_finalization, only: [:finalize]
  before_action :set_iup, only: [:show, :update, :destroy, :validate, :preview, :finalize]

  def create
    result = Iups::CreateService.call(
      student: Student.find(params[:student_id]),
      assessment_cycle: AssessmentCycle.find(params[:assessment_cycle_id]),
      current_user: current_user
    )

    if result.success?
      render json: { iup: IupSerializer.new(result.data[:iup]).as_json }, status: :created
    else
      render_error(result.error, :unprocessable_entity)
    end
  end

  def finalize
    result = Iups::FinalizeService.call(
      iup: @iup,
      finalized_by_user: current_user
    )

    if result.success?
      render json: {
        iup: IupSerializer.new(result.data[:iup]).as_json,
        message: "IUP finalized successfully - Student transitioned to Active Therapy"
      }, status: :ok
    else
      render_error(result.error, :unprocessable_entity)
    end
  end

  private

  def authorize_iup_management
    unless current_user.has_any_role?("Program Director", "Director", "Coordinator")
      render_error("Insufficient permissions for this action", :forbidden)
    end
  end

  def authorize_finalization
    unless current_user.has_role?("Program Director")
      render_error("Only Program Directors can finalize IUPs", :forbidden)
    end
  end

  def set_iup
    @iup = Iup.find_by(id: params[:id])
    render_not_found("IUP not found") unless @iup
  end
end
```

## 8. Frontend Integration Considerations

### 8.1 Auto-Save Implementation

```javascript
// Pseudocode for auto-save
const AUTOSAVE_INTERVAL = 30000; // 30 seconds

let autoSaveTimer;
let pendingChanges = {};

function handleFieldChange(fieldKey, value) {
  pendingChanges[fieldKey] = value;
  
  clearTimeout(autoSaveTimer);
  autoSaveTimer = setTimeout(() => {
    saveChanges(pendingChanges);
    pendingChanges = {};
  }, AUTOSAVE_INTERVAL);
}

async function saveChanges(changes) {
  try {
    await api.patch(`/api/v1/iups/${iupId}`, {
      form_values: changes
    });
    showNotification("Draft saved", "success");
  } catch (error) {
    showNotification("Unable to save draft - check connection", "warning");
    // Retry after 60 seconds
    setTimeout(() => saveChanges(changes), 60000);
  }
}
```

### 8.2 Goal Assignment UI Flow

1. Display therapy stations for student's program
2. For each station, show current assigned goals (max 2)
3. "Add Goal" button opens goal search modal
4. Goal search filters by:
   - Student's therapy group (automatic)
   - Goal domain (dropdown)
   - Search text (name, description)
5. Selected goal triggers POST /api/v1/iups/:id/goals
6. Update UI with new goal card
7. Show "Replace" and "Remove" actions on each goal card

### 8.3 Validation Feedback

1. Run validation on "Preview" or "Finalize" button click
2. Display validation errors in grouped format:
   - Form sections with missing required fields
   - Stations missing goals or exceeding limits
3. Allow navigation to specific sections to address errors
4. Re-validate on retry

## 9. Testing Strategy

### 9.1 Unit Tests

**Service Layer**:
- Test each service with valid inputs
- Test validation failures
- Test edge cases (concurrent active IUPs, missing signatures, etc.)
- Mock external dependencies (notifications, audit logs)

**Model Layer**:
- Test validations (uniqueness, presence, custom validators)
- Test associations
- Test scopes
- Test delegation methods

### 9.2 Integration Tests

**API Endpoints**:
- Test complete workflows (create → assign goals → validate → sign → finalize)
- Test authorization (forbidden access, role checks)
- Test error responses (validation errors, not found, etc.)
- Test pagination and filtering

### 9.3 System Tests

**End-to-End Workflows**:
- Complete IUP creation from assessment to finalization
- Goal assignment with validation errors
- Signature collection flow
- IUP library search and filtering
- PDF export

## 10. Performance Considerations

### 10.1 Database Optimization

**Indexes**:
```ruby
add_index :iups, [:student_id, :status], where: "status = 'active'"
add_index :iups, :assessment_cycle_id
add_index :iups, :created_by_user_id
add_index :iups, :finalized_on

add_index :form_submissions, [:submittable_type, :submittable_id], unique: true
add_index :form_submissions, :values, using: :gin

add_index :iup_signatures, [:iup_id, :signer_role], unique: true
add_index :iup_signatures, :signed_at

add_index :student_goals, [:iup_id, :therapy_station_id]
add_index :goals, :applicable_therapy_groups, using: :gin
```

**Eager Loading**:
```ruby
# IUP Library query
Iup.includes(
  :student,
  :assessment_cycle,
  :created_by_user,
  iup_signatures: :signer_user,
  student_goals: [:goal, :therapy_station]
).where(...)
```

### 10.2 Caching Strategy

- Cache goal bank queries (goals rarely change)
- Cache form configurations (versioned, rarely change)
- Cache student therapy station assignments
- Invalidate IUP cache on status transitions

### 10.3 Query Optimization

- Use `pluck` for simple data extraction
- Batch-load associations with `includes`
- Use database-level constraints for uniqueness
- Implement pagination on all list endpoints

## 11. Security Considerations

### 11.1 Data Protection

- **PII Handling**: IUP content contains sensitive student information
- **Audit Trail**: All IUP actions logged with user identity
- **Signature Evidence**: Capture IP, user agent for non-repudiation
- **Access Control**: Strict role-based permissions

### 11.2 Input Validation

- Sanitize all form field inputs
- Validate goal_id and station_id exist before assignment
- Prevent SQL injection via parameterized queries
- Rate limiting on signature endpoints

### 11.3 Signature Security

- Signatures stored with cryptographic evidence
- Timestamp validation (cannot backdate signatures)
- User identity verification before signature capture
- Guardian verification via Student_Guardian association

## 12. Migration Strategy

### 12.1 Migration Order

1. Add columns to existing tables (iups, goals)
2. Create form_submissions table
3. Create iup_signatures table
4. Add indexes
5. Seed default IUP form configuration
6. Run data backfill if needed

### 12.2 Data Seeding

```ruby
# db/seeds.rb (IUP form configuration)
FormConfiguration.create!(
  form_type: "iup",
  form_name: "Individual Utility Plan",
  revision_number: 1,
  revision_date: Date.current,
  is_default: true,
  field_schema: [
    {
      key: "assessment_summary",
      label: "Assessment Summary",
      type: "rich_text",
      required: false,
      section: "Student Summary"
    },
    {
      key: "reinforcement_strategy",
      label: "Reinforcement Strategy",
      type: "long_text",
      required: true,
      max_length: 5000,
      section: "Behavior Management"
    },
    {
      key: "consequence_plan",
      label: "Consequence Plan",
      type: "long_text",
      required: true,
      max_length: 5000,
      section: "Behavior Management"
    },
    {
      key: "family_coordination_plan",
      label: "Family Coordination Plan",
      type: "long_text",
      required: true,
      max_length: 5000,
      section: "Family Support"
    },
    {
      key: "crisis_plan",
      label: "Crisis Management Plan",
      type: "long_text",
      required: true,
      max_length: 5000,
      section: "Crisis Response"
    },
    {
      key: "discharge_plan",
      label: "Discharge Planning",
      type: "long_text",
      required: false,
      max_length: 5000,
      section: "Transition Planning"
    }
  ]
)
```

## 13. Future Enhancements

### 13.1 Phase 2 Features

- **Electronic Signature Integration**: Integrate DocuSign or similar for legally binding signatures
- **IUP Revision History**: Track changes to form values with diff views
- **Goal Progress Tracking**: Visual progress charts on IUP view
- **Automated Goal Recommendations**: ML-based goal suggestions from assessment data
- **Collaborative Editing**: Real-time collaboration on draft IUPs
- **Template Library**: Pre-built IUP templates for common scenarios

### 13.2 Reporting & Analytics

- **IUP Completion Metrics**: Time from assessment to finalization
- **Goal Distribution Analysis**: Most commonly assigned goals by domain
- **Student Outcomes**: Correlation between IUP goals and therapy progress
- **Compliance Reporting**: Signature collection rates, overdue IUPs

## 14. Open Questions

1. **Guardian Signature Collection**: Should we implement email-based signature links or portal-only signatures?
2. **PDF Generation**: Which PDF library should we use (Prawn, WickedPDF, or external service)?
3. **Concurrent Editing**: How should we handle multiple users editing the same draft IUP simultaneously?
4. **IUP Expiration**: Should IUPs have an expiration date requiring renewal?
5. **Assessment Cycle Linking**: Can one assessment cycle generate multiple draft IUPs (e.g., re-drafts)?

## 15. Success Metrics

### 15.1 Functional Metrics

- 100% of validation rules enforced (2 goals per station, required fields, etc.)
- Zero data loss incidents during auto-save
- 100% signature audit trail completeness

### 15.2 Performance Metrics

- IUP creation completes in < 2 seconds
- Goal search returns results in < 500ms
- IUP library list with 1000+ records loads in < 1 second
- PDF export generates in < 5 seconds

### 15.3 User Experience Metrics

- Draft IUPs saved successfully > 99.9% of the time
- Validation errors clearly actionable (user can resolve without support)
- IUP preview matches finalized PDF layout 100%
- Average time from assessment completion to IUP finalization < 7 days
