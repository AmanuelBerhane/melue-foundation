# Requirements Document

## Introduction

The IUP (Individual Utility Plan) Generation feature enables Program Directors and authorized clinical staff to create, manage, and finalize individualized therapy plans for students who have completed their six-week assessment cycle. The system provides guided workflows for draft creation, goal assignment (2 goals per therapy station), preview, validation, signature collection, and finalization that transitions students to "Active Therapy" status.

This feature encompasses the complete IUP lifecycle from assessment review through finalization, including an IUP library for viewing and managing all student IUPs across draft, active, and archived states.

## Glossary

- **IUP**: Individual Utility Plan - A comprehensive therapy plan documenting goals, behavior strategies, reinforcement approaches, and family coordination
- **IUP_System**: The backend system managing IUP creation, validation, signatures, and status transitions
- **Assessment_Cycle**: A six-week evaluation period capturing Skills, Behavior, Preference, and optional Sensory assessments
- **Student_Goal**: A specific therapeutic goal assigned to a student for practice at a designated therapy station
- **Therapy_Station**: A physical location where therapy activities occur (e.g., Station 1, Station 2)
- **Goal_Bank**: Repository of reusable therapeutic goals organized by domain (Communication, Social Skills, etc.)
- **Program_Director**: Staff role authorized to finalize IUPs and provide required signatures
- **Guardian**: Parent or legal guardian who must provide signature consent for IUP finalization
- **Draft_IUP**: An IUP with status "draft" that can be edited, saved, and modified before finalization
- **Active_IUP**: An IUP with status "active" that is finalized, signed, and governing current therapy
- **Archived_IUP**: A previously active IUP that has been superseded by a new active IUP
- **Form_Submission**: A dynamic form instance capturing IUP content using a versioned form definition
- **IUP_Library**: Administrative interface for viewing, searching, and managing all IUPs across students
- **Auto_Summary**: Auto-populated assessment summary generated from completed Assessment_Cycle data
- **Goal_Assignment_Rule**: Business rule requiring 2 goals per therapy station for optimal therapeutic coverage

## Requirements

### Requirement 1: Assessment Review and IUP Initialization

**User Story:** As a Program Director, I want to review completed assessments and initiate IUP creation, so that I can begin developing an individualized therapy plan based on assessment findings.

#### Acceptance Criteria

1. WHEN a Program Director accesses a student with Assessment_Cycle status "reviewed", THE IUP_System SHALL display an option to "Create IUP"
2. WHEN the "Create IUP" action is triggered, THE IUP_System SHALL create a new Draft_IUP record with student_id, assessment_cycle_id, and status "draft"
3. THE IUP_System SHALL auto-populate the IUP summary section with data from the completed Assessment_Cycle (skills assessment need analysis, behavior function analysis, preference tiers)
4. THE IUP_System SHALL retrieve the active IUP form revision and create a new Form_Submission linked to the Draft_IUP
5. WHEN no completed Assessment_Cycle exists for a student, THE IUP_System SHALL prevent IUP creation and display an error message "Assessment cycle must be completed and reviewed before creating IUP"

### Requirement 2: Draft IUP Persistence and Auto-Save

**User Story:** As a Program Director, I want my IUP draft to automatically save as I work, so that I don't lose progress if interrupted or disconnected.

#### Acceptance Criteria

1. WHILE a user is editing a Draft_IUP, THE IUP_System SHALL save form field changes to Form_Submission.values every 30 seconds
2. WHEN a user navigates away from the IUP draft form, THE IUP_System SHALL save all pending changes before navigation
3. WHEN a user returns to an existing Draft_IUP, THE IUP_System SHALL load the most recent saved state from Form_Submission.values
4. THE IUP_System SHALL preserve Draft_IUP records indefinitely until explicitly finalized or deleted by authorized staff
5. WHEN auto-save fails due to network or validation errors, THE IUP_System SHALL display a warning notification "Unable to save draft - check connection" and retry every 60 seconds

### Requirement 3: Goal Assignment Interface

**User Story:** As a Program Director, I want to assign goals to therapy stations from the goal bank, so that each student has appropriate therapeutic targets for their assigned stations.

#### Acceptance Criteria

1. WHEN viewing a Draft_IUP, THE IUP_System SHALL display a goal assignment interface showing each applicable Therapy_Station for the student's therapy program
2. FOR each Therapy_Station, THE IUP_System SHALL allow selection of goals from the Goal_Bank filtered by the student's therapy group
3. WHEN a goal is selected, THE IUP_System SHALL create a Student_Goal record with iup_id, student_id, goal_id, therapy_station_id, and status "active"
4. THE IUP_System SHALL validate that Student_Goal.student_id matches IUP.student_id before creation
5. IF a selected goal has Goal.type "task_analysis", THE IUP_System SHALL create Student_Goal_Step records from Task_Analysis_Step_Template entries preserving step_number and description
6. WHEN Student_Goal_Step records are created, THE IUP_System SHALL initialize independence_percent to 0 and status to "not_started"
7. THE IUP_System SHALL allow at most 2 active Student_Goals per Therapy_Station for a given IUP
8. WHEN more than 2 goals are assigned to a station, THE IUP_System SHALL prevent assignment and display error "Maximum 2 active goals per station - remove or replace existing goals first"

### Requirement 4: Goal Search and Filtering

**User Story:** As a Program Director, I want to search and filter goals by domain, age range, and therapy group, so that I can quickly find appropriate goals for each student.

#### Acceptance Criteria

1. WHEN the goal assignment interface is displayed, THE IUP_System SHALL show Goal_Domain categories as filter options
2. WHEN a Goal_Domain filter is selected, THE IUP_System SHALL display only goals where Goal.goal_domain_id matches the selected domain
3. THE IUP_System SHALL display goal details including name, description, suggested_age_range, and applicable_therapy_groups
4. THE IUP_System SHALL automatically filter goals where the student's therapy group is not in Goal.applicable_therapy_groups
5. WHEN a search query is entered, THE IUP_System SHALL filter goals by matching text in Goal.name or Goal.description (case-insensitive)
6. THE IUP_System SHALL display only goals where Goal.is_active equals true in the assignment interface
7. WHEN a goal is already assigned to the current IUP at any station, THE IUP_System SHALL visually indicate the goal as "Already Assigned" but allow re-assignment to different stations

### Requirement 5: Goal Replacement and Removal

**User Story:** As a Program Director, I want to replace or remove assigned goals before finalization, so that I can refine the IUP as clinical judgment evolves.

#### Acceptance Criteria

1. WHEN viewing assigned Student_Goals in a Draft_IUP, THE IUP_System SHALL display "Replace" and "Remove" actions for each goal
2. WHEN "Replace" is triggered, THE IUP_System SHALL present the goal selection interface filtered to the current station
3. WHEN a replacement goal is selected, THE IUP_System SHALL update the existing Student_Goal record with the new goal_id and preserve the station assignment
4. IF the replacement goal has type "task_analysis", THE IUP_System SHALL replace Student_Goal_Step records with steps from the new goal's template
5. WHEN "Remove" is triggered, THE IUP_System SHALL delete the Student_Goal record and any associated Student_Goal_Step records
6. IF removal reduces a station's goal count below 2, THE IUP_System SHALL display a warning "Station requires 2 goals for finalization" but allow the removal
7. THE IUP_System SHALL log goal assignment, replacement, and removal actions to the audit trail with user_id, timestamp, and goal details

### Requirement 6: IUP Form Section Completion

**User Story:** As a Program Director, I want to complete all required IUP form sections including behavior strategies, reinforcement, family plan, and crisis plan, so that the IUP provides comprehensive guidance for therapy staff.

#### Acceptance Criteria

1. THE IUP_System SHALL display form sections defined in the active IUP Form_Revision including student summary, reinforcement, consequence, family plan, behavior reduction, replacement goals, antecedent manipulation, crisis plan, care coordination, and discharge plan
2. WHEN a form field is marked required in Form_Field_Definition, THE IUP_System SHALL validate the field is not empty before allowing finalization
3. THE IUP_System SHALL store all form field values in Form_Submission.values as JSON
4. WHEN a user updates a form field, THE IUP_System SHALL include the change in the next auto-save cycle
5. THE IUP_System SHALL preserve the auto-populated assessment summary in a read-only section with an "Edit" option to allow manual adjustments
6. FOR multi-line text fields (behavior reduction, crisis plan, family plan), THE IUP_System SHALL allow up to 5000 characters per field
7. WHEN a required field is empty during finalization attempt, THE IUP_System SHALL display validation error "Required field: [Field Label] must be completed"

### Requirement 7: IUP Preview Functionality

**User Story:** As a Program Director, I want to preview the IUP in its final formatted layout before finalization, so that I can verify content accuracy and completeness.

#### Acceptance Criteria

1. WHEN viewing a Draft_IUP, THE IUP_System SHALL display a "Preview IUP" action
2. WHEN "Preview IUP" is triggered, THE IUP_System SHALL generate a read-only formatted view of the complete IUP including all form sections and assigned goals
3. THE preview SHALL display Form_Submission metadata including form ID, form name, revision number, and revision date in the header
4. THE preview SHALL display all assigned Student_Goals grouped by Therapy_Station with goal name, description, and mastery criteria
5. FOR goals with type "task_analysis", THE preview SHALL display all Student_Goal_Step entries with step number and description
6. THE preview SHALL display auto-populated assessment summary content
7. WHEN the IUP contains validation errors, THE preview SHALL display error indicators with messages but still allow viewing the draft content
8. THE IUP_System SHALL allow navigation from preview back to edit mode without data loss

### Requirement 8: Pre-Finalization Validation

**User Story:** As a Program Director, I want the system to validate IUP completeness before finalization, so that I can address any gaps or errors before submitting for signatures.

#### Acceptance Criteria

1. WHEN a user triggers "Finalize IUP", THE IUP_System SHALL execute validation checks before proceeding to signature collection
2. THE IUP_System SHALL validate that at least one Student_Goal exists per applicable Therapy_Station for the student's therapy program
3. THE IUP_System SHALL validate that all required form fields defined in Form_Field_Definition with required=true have non-empty values in Form_Submission.values
4. THE IUP_System SHALL validate that at most 2 Student_Goals are assigned per applicable Therapy_Station
5. IF any validation check fails, THE IUP_System SHALL prevent finalization and display a list of validation errors with field names and missing requirements
6. WHEN all validation checks pass, THE IUP_System SHALL proceed to the signature collection step
7. THE IUP_System SHALL validate that the student's Assessment_Cycle status is "reviewed" before allowing finalization

### Requirement 9: Program Director Signature Capture

**User Story:** As a Program Director, I want to provide my digital signature to approve the IUP, so that I can formally authorize the therapy plan.

#### Acceptance Criteria

1. WHEN pre-finalization validation passes, THE IUP_System SHALL present a signature interface to the Program_Director
2. THE signature interface SHALL display the complete IUP content in read-only format for final review
3. THE signature interface SHALL require the Program_Director to confirm "I approve this IUP for implementation" via checkbox
4. WHEN the Program_Director confirms approval, THE IUP_System SHALL create an IUP_Signature record with iup_id, signer_user_id, signer_role "program_director", signed_at timestamp, and signature_evidence
5. THE IUP_System SHALL validate that the signing user has the Program_Director role before creating the signature
6. IF the Program_Director already signed the current Draft_IUP, THE IUP_System SHALL display existing signature timestamp and allow re-signature to update the timestamp
7. WHEN Program_Director signature is captured, THE IUP_System SHALL transition to guardian signature collection

### Requirement 10: Guardian Signature Request and Capture

**User Story:** As a Program Director, I want to request guardian signature for IUP approval, so that the parent or legal guardian can consent to the therapy plan.

#### Acceptance Criteria

1. WHEN Program_Director signature is captured, THE IUP_System SHALL identify the primary Guardian associated with the student via Student_Guardian relationship
2. THE IUP_System SHALL send a notification to the Guardian's contact (email or portal notification) with a secure link to review and sign the IUP
3. WHEN the Guardian accesses the signature link, THE IUP_System SHALL display the complete IUP in read-only format
4. THE signature interface SHALL require the Guardian to confirm "I consent to this IUP for my child" via checkbox
5. WHEN the Guardian confirms consent, THE IUP_System SHALL create an IUP_Signature record with iup_id, signer_user_id, signer_role "guardian", signed_at timestamp, and signature_evidence
6. THE IUP_System SHALL validate that the signing user is linked to a Guardian record associated with the IUP's student before creating the signature
7. IF the Guardian does not have a portal account, THE IUP_System SHALL allow manual signature capture by Program_Director with witnessed signature evidence (e.g., scanned document reference)

### Requirement 11: IUP Finalization and Status Transition

**User Story:** As a Program Director, I want the IUP to automatically finalize once both required signatures are captured, so that the student can transition to active therapy.

#### Acceptance Criteria

1. WHEN both Program_Director and Guardian IUP_Signature records exist for an IUP, THE IUP_System SHALL provide a "Finalize IUP" command endpoint
2. WHEN the finalize command is executed, THE IUP_System SHALL transition the IUP status from "draft" to "active"
3. THE IUP_System SHALL set IUP.finalized_on to the current date when status changes to "active"
4. THE IUP_System SHALL transition the student's status from "ready_for_iup" to "active_therapy"
5. IF another IUP exists for the same student with status "active", THE IUP_System SHALL change that IUP's status to "archived" before activating the new IUP
6. THE IUP_System SHALL update all Student_Goals associated with the finalized IUP to status "active"
7. THE IUP_System SHALL log the finalization event to the audit trail with user_id, timestamp, IUP id, and status transition
8. WHEN finalization completes, THE IUP_System SHALL display a success notification "IUP finalized successfully - Student transitioned to Active Therapy"

### Requirement 12: Single Active IUP Enforcement

**User Story:** As the system, I want to enforce that only one IUP per student has status "active" at any time, so that therapy staff always work with the current approved plan.

#### Acceptance Criteria

1. THE IUP_System SHALL enforce that at most one IUP per student has status "active" at any given time
2. WHEN a new IUP is finalized for a student, THE IUP_System SHALL automatically change any existing active IUP for that student to status "archived"
3. THE IUP_System SHALL preserve archived IUP records with all associated Student_Goals, IUP_Signatures, and Form_Submission data for historical reference
4. IF an attempt is made to manually set multiple IUPs to "active" for one student, THE IUP_System SHALL reject the operation and display error "Student already has an active IUP"
5. THE IUP_System SHALL validate single active IUP constraint at the database level via unique partial index or application validation
6. WHEN an IUP is archived, THE IUP_System SHALL update associated Student_Goals to status "archived" but preserve progress_percent and clinical_note data

### Requirement 13: IUP Library View

**User Story:** As a Program Director, I want to view a library of all IUPs across all students, so that I can quickly access any student's current or historical therapy plans.

#### Acceptance Criteria

1. THE IUP_System SHALL provide an IUP Library interface accessible to Program Directors, Directors, and Coordinators
2. THE IUP Library SHALL display a list of all IUP records with columns: student name, IUP status, finalized_on date, assessment_cycle period, and action buttons
3. THE IUP_System SHALL allow filtering IUPs by status (draft, active, archived)
4. THE IUP_System SHALL allow searching IUPs by student name (case-insensitive partial match)
5. WHEN an IUP is selected, THE IUP_System SHALL display the complete IUP details including form sections, assigned goals, and signature status
6. FOR Draft_IUPs, THE library SHALL display "Edit" action to resume draft editing
7. FOR Active and Archived IUPs, THE library SHALL display "View" action to open read-only IUP details with PDF export option

### Requirement 14: IUP Search and Filtering

**User Story:** As a Program Director, I want to search and filter IUPs by student, status, and date range, so that I can quickly locate specific therapy plans.

#### Acceptance Criteria

1. WHEN the IUP Library is displayed, THE IUP_System SHALL provide search and filter controls
2. THE IUP_System SHALL allow text search by student name matching Student.name (case-insensitive, partial match)
3. THE IUP_System SHALL allow filtering by IUP status with options "Draft", "Active", "Archived", and "All"
4. THE IUP_System SHALL allow filtering by finalization date range with "From Date" and "To Date" inputs
5. WHEN multiple filters are applied, THE IUP_System SHALL apply all filters as logical AND (intersection)
6. THE IUP_System SHALL display search result count "Showing X of Y IUPs"
7. WHEN no IUPs match the search criteria, THE IUP_System SHALL display message "No IUPs found matching your criteria"

### Requirement 15: Draft IUP Deletion

**User Story:** As a Program Director, I want to delete a draft IUP that is no longer needed, so that I can remove incomplete or incorrect plans before finalization.

#### Acceptance Criteria

1. WHEN viewing a Draft_IUP in the IUP Library, THE IUP_System SHALL display a "Delete Draft" action
2. WHEN "Delete Draft" is triggered, THE IUP_System SHALL display a confirmation dialog "Are you sure you want to delete this draft IUP? This action cannot be undone."
3. WHEN deletion is confirmed, THE IUP_System SHALL delete the IUP record, all associated Student_Goal records, Student_Goal_Step records, and the linked Form_Submission
4. THE IUP_System SHALL prevent deletion of IUPs with status "active" or "archived" and display error "Only draft IUPs can be deleted"
5. THE IUP_System SHALL log the deletion to the audit trail with user_id, timestamp, deleted IUP id, and student_id
6. WHEN deletion completes, THE IUP_System SHALL remove the IUP from the library view and display success notification "Draft IUP deleted successfully"

### Requirement 16: IUP PDF Export

**User Story:** As a Program Director, I want to export a finalized IUP as PDF, so that I can print or share the therapy plan with staff, guardians, or external providers.

#### Acceptance Criteria

1. WHEN viewing an Active or Archived IUP, THE IUP_System SHALL display an "Export PDF" action
2. WHEN "Export PDF" is triggered, THE IUP_System SHALL generate a PDF document containing all IUP form sections, assigned goals, and signatures
3. THE PDF SHALL include Form_Submission metadata in the header: form ID, form name, revision number, revision date, organization name
4. THE PDF SHALL include auto-calculated page numbers in format "Page X of Y" in the footer
5. THE PDF SHALL display all Student_Goals grouped by Therapy_Station with goal name, description, and task analysis steps if applicable
6. THE PDF SHALL display signature information for Program_Director and Guardian including signer name and signed_at timestamp
7. WHEN PDF generation completes, THE IUP_System SHALL initiate browser download of the PDF file with filename format "IUP_[StudentName]_[FinalizedDate].pdf"

### Requirement 17: Goal Assignment Validation by Therapy Group

**User Story:** As the system, I want to validate that assigned goals are applicable to the student's therapy group, so that only clinically appropriate goals are used.

#### Acceptance Criteria

1. WHEN a goal is selected for assignment, THE IUP_System SHALL validate that the student's Student.therapy_group value is included in Goal.applicable_therapy_groups
2. IF the validation fails, THE IUP_System SHALL prevent goal assignment and display error "Goal '[Goal Name]' is not applicable to [Therapy Group] therapy group"
3. THE IUP_System SHALL automatically filter the goal selection interface to show only goals where the student's therapy_group matches Goal.applicable_therapy_groups
4. THE validation SHALL apply to both initial assignment and goal replacement operations
5. THE IUP_System SHALL perform this validation before creating the Student_Goal record

### Requirement 18: Assessment Summary Auto-Population

**User Story:** As a Program Director, I want the IUP summary section to auto-populate with assessment findings, so that I can quickly review key clinical data without manual data entry.

#### Acceptance Criteria

1. WHEN creating a new Draft_IUP, THE IUP_System SHALL retrieve the linked Assessment_Cycle data
2. THE IUP_System SHALL extract the Skills_Assessment.need_analysis_summary and populate it into the IUP summary "Skills Assessment Findings" section
3. THE IUP_System SHALL extract behavior descriptions from Behavior_Function_Analysis records and populate them into "Behavior Assessment Findings" section
4. THE IUP_System SHALL extract top-tier items from Preference_Observation records (tier "highest") and populate them into "Preference Assessment Findings" section
5. THE auto-populated content SHALL be editable by the Program_Director after initial population
6. WHEN the Assessment_Cycle has incomplete assessments, THE IUP_System SHALL display warning "Some assessments incomplete - summary may be partial" but allow IUP creation
7. THE auto-populated summary SHALL include assessment completion dates for Skills, Behavior, and Preference assessments

### Requirement 19: IUP Audit Trail

**User Story:** As a compliance officer, I want all IUP actions to be logged with user identity and timestamps, so that I can audit the IUP creation and approval process.

#### Acceptance Criteria

1. THE IUP_System SHALL log all IUP create, update, finalize, archive, and delete actions to the Audit_Entry table
2. EACH audit entry SHALL include actor_user_id, occurred_at timestamp, action type, target_type "IUP", target_id (IUP id), and data_classification
3. THE IUP_System SHALL log goal assignment, replacement, and removal actions with Student_Goal id and goal name
4. THE IUP_System SHALL log IUP_Signature creation events with signer_user_id, signer_role, and signed_at timestamp
5. THE IUP_System SHALL log IUP status transitions (draft → active, active → archived) with previous and new status values
6. THE IUP_System SHALL log form field changes with field key, previous value, and new value for required fields
7. AUDIT entries SHALL be append-only and immutable after creation

### Requirement 20: Authorization and Access Control

**User Story:** As a system administrator, I want IUP access to be restricted by role, so that only authorized clinical staff can create, edit, or finalize IUPs.

#### Acceptance Criteria

1. THE IUP_System SHALL allow Program Directors, Directors, and Coordinators to create and edit Draft_IUPs
2. THE IUP_System SHALL allow only Program Directors to finalize IUPs and provide Program_Director signatures
3. THE IUP_System SHALL allow Teachers to view Active IUPs for their assigned students in read-only mode
4. THE IUP_System SHALL allow Guardians to view IUPs for their associated students and provide Guardian signatures
5. WHEN an unauthorized user attempts IUP operations, THE IUP_System SHALL return HTTP 403 Forbidden with error message "Insufficient permissions for this action"
6. THE IUP_System SHALL validate user role via Role_Assignment records before allowing IUP operations
7. THE IUP_System SHALL log all authorization failures to the audit trail with attempted action and user_id
