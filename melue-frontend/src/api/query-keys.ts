import type { UUID } from '@/types/common';

export const queryKeys = {
  sessions: {
    all: ['sessions'] as const,
    today: () => [...queryKeys.sessions.all, 'today'] as const,
    detail: (id: UUID) => [...queryKeys.sessions.all, id] as const,
    dashboard: (id: UUID) => [...queryKeys.sessions.detail(id), 'dashboard'] as const,
    trialStream: (sessionId: UUID, params: { participant_id: UUID; student_goal_id?: UUID }) =>
      [...queryKeys.sessions.detail(sessionId), 'trials', params.participant_id, params.student_goal_id].filter(
        (value) => typeof value !== 'undefined',
      ) as string[],
  },
} as const;