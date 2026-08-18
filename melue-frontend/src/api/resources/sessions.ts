import { http } from '@/api/http/client';
import type {
  SessionDashboard,
  StartSessionRequest,
  StartSessionResponse,
  TodaySessionResponse,
  UpdateActiveGoalRequest,
  UpdateActiveGoalResponse,
} from '@/types/api';
import type { UUID } from '@/types/common';

export const sessionsApi = {
  today(): Promise<TodaySessionResponse> {
    return http.get<TodaySessionResponse>('/today/session').then((res) => res.data);
  },

  start(payload: StartSessionRequest): Promise<StartSessionResponse> {
    return http.post<StartSessionResponse>('/therapy_sessions/start', payload).then((res) => res.data);
  },

  show(sessionId: UUID): Promise<SessionDashboard> {
    return http.get<SessionDashboard>(`/therapy_sessions/${sessionId}`).then((res) => res.data);
  },

  dashboard(sessionId: UUID): Promise<SessionDashboard> {
    return http.get<SessionDashboard>(`/therapy_sessions/${sessionId}/dashboard`).then((res) => res.data);
  },

  async updateActiveGoal(
    sessionId: UUID,
    participantId: UUID,
    payload: UpdateActiveGoalRequest,
  ): Promise<UpdateActiveGoalResponse> {
    const { data } = await http.patch<UpdateActiveGoalResponse>(
      `/therapy_sessions/${sessionId}/participants/${participantId}/active_goal`,
      payload,
    );
    return data;
  },
};