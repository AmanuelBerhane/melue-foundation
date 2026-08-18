import type { AccessAction, AccountStatus, ISODateTimeString, UUID } from './common';

export interface User {
  id: UUID;
  email: string;
  status: AccountStatus;
  locked_until: ISODateTimeString | null;
  created_at: ISODateTimeString;
  updated_at: ISODateTimeString;
}

export interface StaffMember {
  id: UUID;
  user_id: UUID;
  full_name: string;
  staff_number: string;
  is_active: boolean;
  user?: User;
}

export interface Guardian {
  id: UUID;
  user_id: UUID | null;
  full_name: string;
  phone: string;
  user?: User;
}

export interface Permission {
  id: UUID;
  module: string;
  action: AccessAction;
}

export interface Role {
  id: UUID;
  name: string;
  is_system_critical: boolean;
  is_active: boolean;
  permissions?: Permission[];
}

export interface RoleAssignment {
  id: UUID;
  user_id: UUID;
  role_id: UUID;
  assigned_at: ISODateTimeString;
  revoked_at: ISODateTimeString | null;
}

export interface UserSession {
  id: UUID;
  user_id: UUID;
  device_identifier: string;
  remembered_device: boolean;
  expires_at: ISODateTimeString;
}

export interface PasswordResetRequest {
  id: UUID;
  user_id: UUID;
  expires_at: ISODateTimeString;
  used_at: ISODateTimeString | null;
}

export type AuditDataClassification = 'public' | 'internal' | 'confidential' | 'restricted';

export interface AuditEntry {
  id: UUID;
  actor_user_id: UUID | null;
  occurred_at: ISODateTimeString;
  action: string;
  target_type: string | null;
  target_id: UUID | null;
  data_classification: AuditDataClassification;
  metadata?: Record<string, unknown>;
}