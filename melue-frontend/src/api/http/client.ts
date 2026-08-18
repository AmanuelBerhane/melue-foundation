import axios from 'axios';

import { apiBaseUrl } from '@/config/env';
import { getAccessToken } from '@/api/token';
import { toApiError } from './errors';

export const http = axios.create({
  baseURL: apiBaseUrl,
  timeout: 15_000,
  headers: {
    Accept: 'application/json',
    'Content-Type': 'application/json',
  },
});

http.interceptors.request.use((config) => {
  const token = getAccessToken();
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

http.interceptors.response.use(
  (response) => response,
  (error) => Promise.reject(toApiError(error)),
);