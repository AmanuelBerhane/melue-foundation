import { http } from '@/api/http/client';
import type { LogTrialRequest, LogTrialResponse, TrialStreamParams, TrialStreamResponse } from '@/types/api';
import type { UUID } from '@/types/common';

export const trialsApi = {
  log(sessionId: UUID, payload: LogTrialRequest): Promise<LogTrialResponse> {
    return http
      .post<LogTrialResponse>(`/therapy_sessions/${sessionId}/trials`, payload)
      .then((res) => res.data);
  },

  stream(sessionId: UUID, params: TrialStreamParams): Promise<TrialStreamResponse> {
    const { participant_id, ...query } = params;
    return http
      .get<TrialStreamResponse>(`/therapy_sessions/${sessionId}/participants/${participant_id}/trial_stream`, {
        params: query,
      })
      .then((res) => res.data);
  },
};