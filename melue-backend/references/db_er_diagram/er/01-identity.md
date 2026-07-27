---
# Module 01 — Identity, Access & Audit

**Tables owned by this module:** `users`, `staff_members`, `guardians`, `roles`, `role_assignments`, `permissions`, `user_sessions`, `password_reset_requests`, `audit_entries`

**Cross-module stubs shown:** _(none — this is the root identity module referenced by all others)_

```mermaid
erDiagram

    users {
        uuid id PK
        varchar email UK
        varchar password_digest
        varchar status
        timestamp locked_until
        timestamp created_at
        timestamp updated_at
    }

    staff_members {
        uuid id PK
        uuid user_id FK
        varchar full_name
        varchar staff_number UK
        timestamp created_at
        timestamp updated_at
    }

    guardians {
        uuid id PK
        uuid user_id FK
        varchar full_name
        varchar phone
        timestamp created_at
        timestamp updated_at
    }

    roles {
        uuid id PK
        varchar name UK
        boolean is_system_critical
        boolean is_active
        timestamp created_at
        timestamp updated_at
    }

    role_assignments {
        uuid id PK
        uuid user_id FK
        uuid role_id FK
        timestamp assigned_at
        timestamp revoked_at
    }

    permissions {
        uuid id PK
        uuid role_id FK
        varchar module
        varchar action
    }

    user_sessions {
        uuid id PK
        uuid user_id FK
        varchar device_identifier
        boolean remembered_device
        timestamp expires_at
        timestamp created_at
    }

    password_reset_requests {
        uuid id PK
        uuid user_id FK
        timestamp expires_at
        timestamp used_at
        timestamp created_at
    }

    audit_entries {
        uuid id PK
        uuid actor_user_id FK
        timestamp occurred_at
        varchar action
        varchar target_type
        uuid target_id
        varchar data_classification
    }

    users ||--o| staff_members : "staff profile"
    users ||--o| guardians : "portal account"
    users ||--o{ role_assignments : "receives"
    roles ||--o{ role_assignments : "assigned via"
    roles ||--o{ permissions : "grants"
    users ||--o{ user_sessions : "opens"
    users ||--o{ password_reset_requests : "requests"
    users ||--o{ audit_entries : "actor in"
```

**Enum values**

| Column | Values |
|---|---|
| `users.status` | `active`, `inactive`, `locked` |
| `permissions.action` | `view`, `create`, `edit`, `delete`, `approve` |

**Key rules**
- `users.email` is globally unique
- Five failed logins lock the account for 15 minutes (`locked_until`)
- A `staff_member` or `guardian` without a `user` record cannot authenticate
- System-critical roles and roles held by active staff cannot be deleted
- `audit_entries` are append-only; never update or delete rows in this table
