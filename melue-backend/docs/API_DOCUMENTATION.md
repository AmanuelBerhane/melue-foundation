# Melue Foundation Therapy Management API Documentation

Welcome to the API Documentation for the **Melue Foundation Therapy Management System**.

> **Interactive API Reference**: When running the server locally (`rails s`), interactively test and view OpenAPI documentation at:  
> 📍 **`http://localhost:3000/docs`**

---

## Base URL

* **Development:** `http://localhost:3000/api/v1`
* **Production:** `https://api.melue.foundation/api/v1`

---

## Authentication & Authorization

All authenticated endpoints expect a JSON Web Token (JWT) in the standard HTTP `Authorization` header:

```http
Authorization: Bearer <YOUR_JWT_TOKEN>
```

---

## 1. Authentication Endpoints

### `POST /api/v1/auth/login`
Authenticates staff or parent accounts and returns a JWT access token.

**Request Body:**
```json
{
  "email": "teacher1@melue.foundation",
  "password": "Password123!"
}
```

**Response (200 OK):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

---

### `POST /api/v1/auth/create-account`
Registers a new staff or user account across the system. Validates that the email address is unique (**FR-009**).

**Request Body:**
```json
{
  "email": "new.staff@melue.foundation",
  "password": "Password123!"
}
```

---

### `POST /api/v1/auth/reset-password`
Initiates a password reset workflow (**FR-005**, **FR-010**) by dispatching a reset email via ActionMailer.

---

## 2. Active Therapy & Session Endpoints

### `GET /api/v1/today/session`
Fetches the currently scheduled session assignment context for the logged-in teacher for today.

**Response (200 OK):**
```json
{
  "assignment_id": "uuid",
  "scheduled_date": "2026-08-03",
  "teacher_name": "Teacher A",
  "station": "Station 1",
  "room": "Room 101",
  "prompt_levels": [
    { "id": "uuid", "label": "FP", "color": "#EF4444" },
    { "id": "uuid", "label": "PP", "color": "#F59E0B" },
    { "id": "uuid", "label": "G",  "color": "#3B82F6" },
    { "id": "uuid", "label": "+",  "color": "#10B981" }
  ]
}
```

---

### `POST /api/v1/therapy_sessions/start`
Starts an active therapy session block for an assigned room and station (**FR-088**).

**Request Body:**
```json
{
  "teacher_student_assignment_id": "uuid"
}
```

**Response (201 Created):**
```json
{
  "id": "therapy-session-uuid",
  "status": "in_progress",
  "started_at": "2026-08-03T09:00:00Z"
}
```

---

### `GET /api/v1/therapy_sessions/:id/dashboard`
Returns full real-time dashboard data (**FR-088–FR-094**), including station context, remaining session timer, student cards (Active & Secondary), assigned goals, and recent trial stream.

---

### `PATCH /api/v1/therapy_sessions/:id/participants/:participant_id/active_goal`
Switches the active goal tab for a student participant during a session (**FR-092**).

**Request Body:**
```json
{
  "student_goal_id": "uuid"
}
```

---

### `POST /api/v1/therapy_sessions/:therapy_session_id/trials`
Logs a trial entry (FP, PP, G, or + prompt tap) in real-time (**FR-094**, **NFR-001** latency < 500ms).

**Request Body:**
```json
{
  "session_participant_id": "uuid",
  "student_goal_id": "uuid",
  "prompt_level_id": "uuid",
  "outcome": "correct",
  "client_event_id": "unique-client-uuid"
}
```

---

### `GET /api/v1/therapy_sessions/:therapy_session_id/trials/stream`
Returns chronological trial stream results for the active goal.

---

## 3. File Attachments & Object Storage (Active Storage)

Student records support direct document and media uploads stored via Rails Active Storage (`:local` storage for $0 cost in development/test):
* `headshot_photo`: Headshot photo of the student (**FR-024a**).
* `baseline_video`: Optional baseline video of the student (**FR-024b**).
* `documents`: Uploaded PDF/JPEG medical diagnoses, birth certificates, and agreement documents (**FR-023**).

---

## 4. Notifications & External Services

* **Email Service**: ActionMailer sends transactional emails (`account_created`, `password_reset_requested`, `system_alert`).
* **Push Notification Service**: `PushNotificationService` dispatches push alerts to mobile/tablet clients for draft expiry and goal mastery reviews (**FR-105a**).
