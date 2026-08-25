# Implementation Plan: IUP Generation System

## Overview

This implementation plan builds the complete IUP Generation System for Ruby on Rails, following a service-oriented architecture. The system provides workflows for creating, managing, and finalizing Individual Utility Plans (IUPs) with draft persistence, goal assignment (2-per-station rule), multi-signature approval, and automated status transitions.

The implementation follows this sequence:
1. Database schema and migrations
2. Core models with validations
3. Service layer (business logic)
4. API controllers and endpoints
5. Authorization and access control
6. PDF export functionality
7. Integration tests

## Tasks

- [x] 1. Database Schema and Migrations
  - Create migrations for new tables (form_submissions, iup_signatures)
  - Add columns to existing tables (iups, goals, student_goals)
  - Add database indexes for performance optimization
  - Add database constraints (unique indexes, check constraints)
  - _Requirements: 1.2, 1.4, 9.4, 10.4, 11.3_

- [x] 2. Core Model Layer
  - [x] 2.1 Implement FormSubmission model
    - Create model with polymorphic association to submittable
    - Add status enum (draft, submitted, finalized)
    - Implement update_field and get_field helper methods
    - Add uniqueness validation for submittable
    - _Requirements: 1.4, 2.1_

  - [x] 2.2 Implement IupSignature model
    - Create model with associations to IUP and User
    - Add signer_role enum (program_director, guardian)
    - Add uniqueness constraint for (iup_id, signer_role)
    - Implement signer_name helper method
    - _Requirements: 9.4, 10.4_

  - [x] 2.3 Update Iup model with new associations and validations
    - Add belongs_to associations for assessment_cycle, created_by_user, finalized_by_user
    - Add has_one association to form_submission
    - Add has_many associations to student_goals and iup_signatures
    - Implement only_one_active_iup_per_student validation
    - Add helper methods: program_director_signature, guardian_signature, signatures_complete?
    - Add scopes: active, draft, archived
    - _Requirements: 1.2, 11.1, 12.1_

  - [x] 2.4 Update StudentGoal model with station limit validation
    - Add max_two_goals_per_station validation on create
    - Validate that existing active goals for (iup_id, therapy_station_id) < 2
    - _Requirements: 3.7, 8.4_

  - [x] 2.5 Update Goal model with therapy group filtering
    - Add applicable_to_therapy_group? instance method
    - Add for_therapy_group scope for filtering goals by therapy group
    - _Requirements: 17.1, 17.3_

- [x] 3. Service Layer - IUP Creation and Draft Management
  - [x] 3.1 Implement Iups::CreateService
    - Validate assessment_cycle status is "reviewed"
    - Validate student doesn't already have a draft IUP
    - Create draft IUP record with associations
    - Create linked FormSubmission with default IUP form configuration
    - Call Iups::AssessmentSummaryBuilder to populate summary
    - Return ServiceResult with created IUP
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

  - [x] 3.2 Implement Iups::AssessmentSummaryBuilder service
    - Extract skills findings from assessment cycle
    - Extract behavior findings from behavior function analysis
    - Extract preference findings (top-tier items)
    - Extract assessment completion dates
    - Return formatted summary hash
    - _Requirements: 18.1, 18.2, 18.3, 18.4, 18.7_

  - [ ]* 3.3 Write unit tests for Iups::CreateService
    - Test successful IUP creation with valid assessment cycle
    - Test validation failure when assessment not reviewed
    - Test validation failure when draft IUP already exists
    - Test FormSubmission creation with auto-populated summary
    - _Requirements: 1.1, 1.2, 1.5_

- [x] 4. Service Layer - Goal Assignment
  - [x] 4.1 Implement Iups::AssignGoalService
    - Validate goal is active (is_active = true)
    - Validate goal applicable_therapy_groups includes student's therapy_group
    - Validate station capacity (max 2 active goals per station)
    - Create StudentGoal record with associations
    - If goal type is task_analysis, create StudentGoalStep records from templates
    - Log goal assignment to audit trail
    - Return ServiceResult with student_goal
    - _Requirements: 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 17.1, 17.5_

  - [x] 4.2 Implement Iups::ReplaceGoalService
    - Validate replacement goal is active and applicable to therapy group
    - Remove existing StudentGoalStep records
    - Update StudentGoal with new goal_id and reset progress
    - Create new StudentGoalStep records if task_analysis type
    - Log goal replacement to audit trail
    - _Requirements: 5.3, 5.4, 5.7_

  - [ ]* 4.3 Write unit tests for Iups::AssignGoalService
    - Test successful goal assignment with standard goal
    - Test successful goal assignment with task_analysis goal (creates steps)
    - Test validation failure when goal not active
    - Test validation failure when goal not applicable to therapy group
    - Test validation failure when station already has 2 goals
    - _Requirements: 3.3, 3.7, 17.1_

  - [ ]* 4.4 Write unit tests for Iups::ReplaceGoalService
    - Test successful goal replacement
    - Test StudentGoalStep deletion and recreation
    - Test validation failures for inactive or inapplicable goals
    - _Requirements: 5.3, 5.4_

- [x] 5. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Service Layer - Validation and Preview
  - [x] 6.1 Implement Iups::ValidateService
    - Validate assessment_cycle status is "reviewed"
    - Validate all required form fields have non-empty values
    - Validate at least 1 goal per applicable therapy station
    - Validate at most 2 goals per therapy station
    - Return ServiceResult with validation errors if any
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.7_

  - [ ]* 6.2 Write unit tests for Iups::ValidateService
    - Test validation passes when all criteria met
    - Test validation fails when assessment not reviewed
    - Test validation fails when required fields missing
    - Test validation fails when station has <1 or >2 goals
    - _Requirements: 8.2, 8.3, 8.4_

- [x] 7. Service Layer - Signature Collection
  - [x] 7.1 Implement Iups::SignatureService
    - Validate signer authorization (Program Director role or Guardian association)
    - Create or update IupSignature record with signed_at timestamp
    - Build signature_evidence JSON (IP, user agent, timestamp)
    - If Program Director signature, send notification to guardian
    - Log signature capture to audit trail
    - Return ServiceResult with signature
    - _Requirements: 9.4, 9.5, 9.6, 10.2, 10.4, 10.6_

  - [ ]* 7.2 Write unit tests for Iups::SignatureService
    - Test successful Program Director signature with role validation
    - Test successful Guardian signature with association validation
    - Test validation failure when user lacks required role
    - Test validation failure when guardian not associated with student
    - Test guardian notification triggered after PD signature
    - _Requirements: 9.5, 10.6_

- [x] 8. Service Layer - Finalization
  - [x] 8.1 Implement Iups::FinalizeService
    - Validate both Program Director and Guardian signatures present
    - Run Iups::ValidateService and ensure all checks pass
    - Wrap operations in database transaction:
      - Archive previous active IUP (status → archived)
      - Set previous IUP's StudentGoals to archived
      - Update IUP status from draft → active
      - Set finalized_on and finalized_by_user
      - Update FormSubmission status to finalized
      - Set all StudentGoals to active
      - Transition student status from ready_for_iup → active_therapy
    - Log finalization to audit trail
    - Return ServiceResult with finalized IUP
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 11.7, 11.8_

  - [ ]* 8.2 Write unit tests for Iups::FinalizeService
    - Test successful finalization with all preconditions met
    - Test validation failure when signatures missing
    - Test validation failure when IUP validation fails
    - Test previous active IUP archived correctly
    - Test student status transition
    - Test transaction rollback on errors
    - _Requirements: 11.1, 11.2, 11.5, 11.6_

- [x] 9. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. API Controllers - IUP Management
  - [x] 10.1 Implement IupsController#create endpoint
    - Authenticate user and authorize IUP management permission
    - Parse student_id and assessment_cycle_id from params
    - Call Iups::CreateService
    - Return JSON response with created IUP and form_submission
    - Handle validation errors with 422 status
    - _Requirements: 1.1, 1.2, 20.1_

  - [x] 10.2 Implement IupsController#index endpoint
    - Authenticate user and authorize based on role
    - Parse query parameters: status, student_name, date_from, date_to, page, per_page
    - Filter IUPs by status, student name (case-insensitive partial match), and date range
    - Eager load associations (student, assessment_cycle, signatures)
    - Return paginated JSON response with IUP list and pagination metadata
    - _Requirements: 13.1, 13.2, 14.1, 14.2, 14.3, 14.4, 14.5_

  - [x] 10.3 Implement IupsController#show endpoint
    - Authenticate user and authorize IUP access based on role and student association
    - Eager load all associations (student_goals, iup_signatures, form_submission)
    - Return complete IUP JSON with nested goals, steps, and signatures
    - _Requirements: 13.5, 20.3, 20.4_

  - [x] 10.4 Implement IupsController#update endpoint (auto-save)
    - Authenticate user and authorize IUP editing permission
    - Parse form_values from params
    - Update FormSubmission.values with new field values
    - Return JSON response with saved_at timestamp
    - Handle concurrent update conflicts
    - _Requirements: 2.1, 2.2, 2.4, 6.4_

  - [x] 10.5 Implement IupsController#destroy endpoint
    - Authenticate user and authorize IUP management permission
    - Validate IUP status is "draft" (prevent deletion of active/archived)
    - Delete IUP record (cascades to StudentGoals, StudentGoalSteps, FormSubmission)
    - Log deletion to audit trail
    - Return 204 No Content on success
    - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5_

  - [x] 10.6 Implement IupsController#validate endpoint
    - Call Iups::ValidateService with IUP
    - Return JSON response with valid boolean and errors array
    - _Requirements: 8.1, 8.5_

  - [x] 10.7 Implement IupsController#finalize endpoint
    - Authenticate user and authorize finalization permission (Program Director only)
    - Call Iups::FinalizeService
    - Return JSON response with finalized IUP and success message
    - Handle validation errors with detailed error messages
    - _Requirements: 11.1, 11.8, 20.2_

- [x] 11. API Controllers - Goal Assignment
  - [x] 11.1 Implement IupGoalsController#create endpoint
    - Authenticate user and authorize IUP management permission
    - Parse goal_id and therapy_station_id from params
    - Call Iups::AssignGoalService
    - Return JSON response with created StudentGoal
    - Handle validation errors (goal not active, station full, therapy group mismatch)
    - _Requirements: 3.3, 3.7, 3.8, 17.2_

  - [x] 11.2 Implement IupGoalsController#update endpoint (replace goal)
    - Authenticate user and authorize IUP management permission
    - Parse new_goal_id from params
    - Call Iups::ReplaceGoalService
    - Return JSON response with updated StudentGoal
    - _Requirements: 5.1, 5.2, 5.3_

  - [x] 11.3 Implement IupGoalsController#destroy endpoint
    - Authenticate user and authorize IUP management permission
    - Find StudentGoal by id
    - Delete StudentGoal (cascades to StudentGoalSteps)
    - Log removal to audit trail
    - Return 204 No Content
    - _Requirements: 5.1, 5.5, 5.7_

  - [x] 11.4 Implement GoalsController#search endpoint
    - Authenticate user
    - Parse query parameters: q (search text), goal_domain_id, therapy_group, page
    - Filter goals by is_active = true
    - Filter by goal_domain_id if provided
    - Filter by therapy_group using for_therapy_group scope
    - Search by name/description if query text provided
    - Return paginated JSON response with goal details
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

- [x] 12. API Controllers - Signature Collection
  - [x] 12.1 Implement IupSignaturesController#create endpoint
    - Authenticate user
    - Parse signer_role and confirmed from params
    - Call Iups::SignatureService with current user and role
    - Return JSON response with created signature
    - Handle authorization errors (role validation failures)
    - _Requirements: 9.3, 9.4, 10.3, 10.4_

- [x] 13. Authorization and Access Control
  - [x] 13.1 Implement authorization concern for IUP management
    - Create Authorization concern with helper methods
    - Implement authorize_iup_management (Program Director, Director, Coordinator)
    - Implement authorize_finalization (Program Director only)
    - Implement authorize_iup_view based on role and student association
    - Use in controller before_action callbacks
    - _Requirements: 20.1, 20.2, 20.3, 20.4, 20.5, 20.6_

  - [ ]* 13.2 Write integration tests for authorization
    - Test Program Director can create, edit, finalize IUPs
    - Test Director can create and edit but not finalize
    - Test Teacher can only view IUPs for assigned students
    - Test Guardian can only view IUPs for associated students
    - Test unauthorized users receive 403 Forbidden
    - _Requirements: 20.1, 20.2, 20.3, 20.4, 20.5_

- [x] 14. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 15. PDF Export Functionality
  - [~] 15.1 Implement Iups::PdfGeneratorService
    - Accept IUP as input parameter
    - Use PDF library (Prawn or WickedPDF) to generate formatted PDF
    - Include form metadata in header (form ID, name, revision, organization)
    - Include all FormSubmission field values in sections
    - Include StudentGoals grouped by TherapyStation with goal details
    - Include StudentGoalSteps for task_analysis goals
    - Include signature information (signer names, signed_at timestamps)
    - Add page numbers in footer (Page X of Y)
    - Return PDF binary data
    - _Requirements: 16.2, 16.3, 16.4, 16.5, 16.6_

  - [~] 15.2 Implement IupsController#export endpoint
    - Authenticate user and authorize PDF export permission
    - Call Iups::PdfGeneratorService
    - Set response headers: Content-Type: application/pdf, Content-Disposition: attachment
    - Generate filename: IUP_[StudentName]_[FinalizedDate].pdf
    - Stream PDF binary to response
    - _Requirements: 16.1, 16.7_

  - [ ]* 15.3 Write unit tests for PDF generation
    - Test PDF includes all form sections
    - Test PDF includes all goals and steps
    - Test PDF includes signature information
    - Test PDF filename format is correct
    - _Requirements: 16.3, 16.4, 16.5, 16.6, 16.7_

- [x] 16. Audit Logging Integration
  - [x] 16.1 Add audit logging to all IUP services
    - Log IUP create, update, finalize, archive, delete events
    - Log goal assignment, replacement, removal events
    - Log IUP signature creation events
    - Log IUP status transitions with previous and new status
    - Include actor_user_id, occurred_at, action type, target_id, and change_data
    - _Requirements: 19.1, 19.2, 19.3, 19.4, 19.5, 19.7_

  - [x] 16.2 Add audit logging for authorization failures
    - Log all 403 Forbidden responses with attempted action and user_id
    - _Requirements: 20.7_

- [x] 17. Data Seeding and Migrations
  - [x] 17.1 Create seed file for IUP form configuration
    - Seed FormConfiguration with form_type "iup"
    - Define field_schema for all IUP sections (assessment_summary, reinforcement_strategy, consequence_plan, family_coordination_plan, crisis_plan, discharge_plan)
    - Mark required fields (reinforcement, consequence, family plan, crisis plan)
    - Set max_length 5000 for long_text fields
    - Set is_default true for initial revision
    - _Requirements: 1.4, 6.1, 6.2, 6.6_

  - [x] 17.2 Run all migrations and verify schema
    - Run migrations in correct order
    - Verify foreign key constraints are added
    - Verify indexes are created
    - Verify check constraints are enforced
    - Seed form configuration data
    - _Requirements: 1.2, 1.4, 9.4, 10.4_

- [ ]* 18. Integration Tests - End-to-End Workflows
  - [ ]* 18.1 Write integration test for complete IUP creation workflow
    - Test: Assessment reviewed → Create IUP → Assign goals → Validate → Sign (PD and Guardian) → Finalize
    - Verify IUP status transitions
    - Verify Student status transition to active_therapy
    - Verify previous active IUP archived
    - _Requirements: 1.1, 3.3, 8.1, 9.4, 10.4, 11.1, 11.4_

  - [ ]* 18.2 Write integration test for goal assignment validation
    - Test: Assign 2 goals to station → Attempt to assign 3rd goal → Verify error
    - Test: Assign goal not applicable to therapy group → Verify error
    - Test: Assign inactive goal → Verify error
    - _Requirements: 3.7, 3.8, 17.1, 17.2_

  - [ ]* 18.3 Write integration test for IUP library search and filtering
    - Create multiple IUPs with different statuses and students
    - Test: Filter by status → Verify correct IUPs returned
    - Test: Search by student name → Verify partial match works
    - Test: Filter by date range → Verify correct IUPs returned
    - _Requirements: 13.2, 14.2, 14.3, 14.4, 14.5_

  - [ ]* 18.4 Write integration test for draft deletion
    - Test: Delete draft IUP → Verify cascading deletion of goals, steps, form_submission
    - Test: Attempt to delete active IUP → Verify error
    - _Requirements: 15.3, 15.4_

  - [ ]* 18.5 Write integration test for auto-save behavior
    - Test: Update form fields → Wait for auto-save → Verify values persisted
    - Test: Navigate away from draft → Return → Verify most recent state loaded
    - _Requirements: 2.1, 2.2, 2.3_

- [x] 19. Final Checkpoint - Ensure all tests pass
  - Run complete test suite
  - Verify all requirements mapped to implementation
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional test tasks and can be skipped for faster MVP
- Each task references specific requirements for traceability
- The implementation uses Ruby on Rails with a service-oriented architecture
- Services inherit from ApplicationService and return ServiceResult objects
- All operations use database transactions where appropriate
- Audit logging is integrated throughout for compliance
- Authorization uses role-based access control (RBAC)
- The system enforces business rules at both model and service layers
- PDF generation can use Prawn (recommended) or WickedPDF
- Auto-save implementation should be handled on the frontend (JavaScript) calling the update endpoint
