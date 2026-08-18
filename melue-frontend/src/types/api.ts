import type { ISODateString, ISODateTimeString, TimeString, UUID } from './common';
import type { PromptLevel } from './facilities';
import type { GoalType, StudentGoalStatus } from './iup';
import type { TherapyGroup } from './student';
import type {
  AssignmentStatus,
  SessionCardPosition,
  TherapySessionStatus,
  Trial,
  TrialOutcome,
} from './therapy';

export interface BlockContext {
  id: UUID;
  name: string;
  start_time: TimeString;
  end_time: TimeString;
  seconds_remaining: number;
}

export interface StationSummary {
  id: UUID;
  name: string;
}

export interface RoomSummary {
  id: UUID;
  name: string;
}

export interface AssignmentContext {
  id: UUID;
  scheduled_date: ISODateString;
  status: AssignmentStatus;
  block: BlockContext;
  station: StationSummary;
  room: RoomSummary;
}

export interface SessionState {
  id: UUID;
  status: TherapySessionStatus;
  started_at: ISODateTimeString;
  ended_at: ISODateTimeString | null;
}

export interface TodaySessionResponse {
  assignment: AssignmentContext;
  session: SessionState | null;
  prompt_levels: PromptLevel[];
}

export interface StartSessionRequest {
  assignment_id: UUID;
}

export interface StartSessionResponse {
  session: SessionState;
}

export interface GoalPill {
  id: UUID;
  name: string;
  goal_type: GoalType;
  status: StudentGoalStatus;
  progress_percent: number;
}

export interface StudentSummary {
  id: UUID;
  full_name: string;
  therapy_group: TherapyGroup;
}

export interface StudentCard {
  id: UUID;
  card_position: SessionCardPosition;
  student: StudentSummary;
  current_focus_student_goal_id: UUID | null;
  goals: GoalPill[];
  recent_trials: Trial[];
}

export interface SessionDashboard {
  id: UUID;
  status: TherapySessionStatus;
  started_at: ISODateTimeString;
  ended_at: ISODateTimeString | null;
  station: StationSummary;
  room: RoomSummary;
  block: BlockContext;
  participants: [StudentCard, StudentCard];
  prompt_levels: PromptLevel[];
}

export interface LogTrialRequest {
  participation_id: UUID;
  student_goal_id: UUID;
  prompt_level_id: UUID;
  outcome: TrialOutcome;
  client_event_id: UUID;
  logged_at?: ISODateTimeString;
}

export interface LogTrialResponse {
  trial: Trial;
}

export interface TrialStreamParams {
  participant_id: UUID;
  student_goal_id?: UUID;
  limit?: number;
}

export interface TrialStreamResponse {
  trials: Trial[];
}

export interface UpdateActiveGoalRequest {
  student_goal_id: UUID;
}

export interface UpdateActiveGoalResponse {
  participant_id: UUID;
  current_focus_student_goal_id: UUID;
}