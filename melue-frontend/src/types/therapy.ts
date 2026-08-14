import type { ISODateString, ISODateTimeString, UUID } from './common';

export type AssignmentStatus = 'scheduled' | 'cancelled' | 'completed';

export type TherapySessionStatus = 'in_progress' | 'completed';

export type SessionCardPosition = 'active' | 'secondary';

export type TrialOutcome = 'correct' | 'incorrect' | 'no_response';

export type SessionSummaryStatus = 'draft' | 'submitted' | 'reviewed';

export interface TeacherStudentAssignment {
  id: UUID;
  teacher_id: UUID;
  student_id: UUID;
  session_block_definition_id: UUID;
  station_id: UUID;
  room_id: UUID;
  scheduled_date: ISODateString;
  status: AssignmentStatus;
}

export interface StaffAvailability {
  id: UUID;
  staff_member_id: UUID;
  session_block_definition_id: UUID;
  unavailable_date: ISODateString;
  reason: string | null;
}

export interface TherapySession {
  id: UUID;
  teacher_id: UUID;
  session_block_definition_id: UUID;
  station_id: UUID;
  room_id: UUID;
  started_at: ISODateTimeString;
  ended_at: ISODateTimeString | null;
  status: TherapySessionStatus;
}

export interface SessionParticipant {
  id: UUID;
  therapy_session_id: UUID;
  student_id: UUID;
  teacher_student_assignment_id: UUID;
  card_position: SessionCardPosition;
  current_focus_student_goal_id: UUID | null;
}

export interface Trial {
  id: UUID;
  therapy_session_id: UUID;
  session_participant_id: UUID;
  student_goal_id: UUID;
  student_goal_step_id: UUID | null;
  prompt_level_id: UUID;
  outcome: TrialOutcome;
  logged_at: ISODateTimeString;
  client_event_id: UUID;
  prompt_label_snapshot: string | null;
}

export interface BehaviorIncident {
  id: UUID;
  therapy_session_id: UUID;
  session_participant_id: UUID;
  active_student_goal_id: UUID;
  recorded_by_user_id: UUID;
  occurred_at: ISODateTimeString;
  behavior_name_snapshot: string;
  behavior_definition_snapshot: string;
  frequency_snapshot: string;
  intensity_snapshot: string;
  category_snapshot: string;
  location_snapshot: string;
  antecedent_snapshot: string;
  consequence_snapshot: string;
  antecedent_other_text: string | null;
  consequence_other_text: string | null;
  notes: string | null;
}

export interface SessionSummary {
  id: UUID;
  therapy_session_id: UUID;
  qualitative_notes: string;
  status: SessionSummaryStatus;
  reviewed_by_user_id: UUID | null;
  reviewed_at: ISODateTimeString | null;
}