export const env = {
  apiUrl: process.env.EXPO_PUBLIC_API_URL ?? 'http://localhost:3000',
  apiVersion: 'v1',
  authMock: process.env.EXPO_PUBLIC_AUTH_MOCK === 'true',
} as const;

export const apiBaseUrl = `${env.apiUrl}/api/${env.apiVersion}`;