# Melue Backend API

Ruby on Rails 8 API backend for the Melue application.

> [!NOTE]
> **Getting Started & Developer Freedom**
>
> This repository and foundational setup are provided simply to get you up and running quickly, and nothing more.
>
> All documentation, domain models, and API specifications in `references/` serve as a reference for anyone looking for guidance on where to start. By no means are they intended to restrict you or stop you from approaching and implementing things in your own way. Feel free to adapt, refine, and innovate as needed!

---

## Technical Stack

* **Ruby**: 3.3+ (see `.ruby-version`)
* **Framework**: Rails 8.1 (API Mode)
* **Database**: PostgreSQL
* **Authentication**: Rodauth (JWT Token Auth)
* **Testing**: RSpec, FactoryBot, Faker, Shoulda Matchers, DatabaseCleaner
* **Code Style**: RuboCop (Omakase style)
* **Security Scanners**: Brakeman, Bundler Audit

---

## Local Development Setup

### 1. Prerequisites
Ensure you have the following installed:
* Ruby (`.ruby-version`)
* PostgreSQL 14+
* Bundler (`gem install bundler`)

### 2. Clone & Install Dependencies
```bash
cd melue-backend
bundle install
```

### 3. Environment Configuration
Copy the example environment file:
```bash
cp .env.example .env
```
Update `.env` with your local PostgreSQL user/password if needed.

### 4. Database Setup
Create, migrate, and seed the database:
```bash
bin/rails db:prepare
```

### 5. Start Development Server
```bash
bin/rails server
```
The API server will run at `http://localhost:3000`.

---

## Architecture & Service Layer Pattern

Keep controllers and database models thin by offloading business logic to single-purpose **Service Objects**.

### Service Object Conventions
* Inherit from `ApplicationService`.
* Expose a standard `.call(...)` class method.
* Return a `ServiceResult` object containing `success?`, `data`, and `error`.

```ruby
class EnrollmentService < ApplicationService
  def initialize(student, course)
    @student = student
    @course = course
  end

  def call
    return failure("Invalid student record") unless @student.valid?
    return failure("Student already enrolled") if already_enrolled?

    enrollment = Enrollment.create!(student: @student, course: @course)
    success(enrollment)
  rescue StandardError => e
    failure(e.message)
  end

  private

  def already_enrolled?
    Enrollment.exists?(student: @student, course: @course)
  end
end
```

---

## Authentication Endpoints

All authentication endpoints are handled via Rodauth under `/api/v1/auth`:

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/v1/auth/create-account` | Register a new account |
| `POST` | `/api/v1/auth/login` | Authenticate & receive JWT in `Authorization` header |
| `POST` | `/api/v1/auth/logout` | Invalidate active session / token |
| `POST` | `/api/v1/auth/reset-password` | Request password reset |

### Authenticating API Requests in Controllers
Inherit your controller from `Api::V1::BaseController`:

```ruby
class Api::V1::ExampleController < Api::V1::BaseController
  before_action :authenticate_user! # Returns 401 if unauthenticated

  def index
    render json: { user: current_user }
  end
end
```

---

## Git Workflow & Trunk-Based Development (TBD)

We maintain a clean, linear git history by practicing **Trunk-Based Development**:

```plain
main (trunk)
  │
  ├─── REG-101-feat/student-enrollment (1-2 days max)
  │         ├─ commit 1
  │         ├─ commit 2
  │         └─ PR (Squash & Merge)
  │
  └─── main continues (linear history)
```

### Key Workflow Rules
1. **Main is Always Deployable**: Code on `main` must always build cleanly and pass all tests.
2. **Short-Lived Feature Branches**: Keep feature branches focused (1 to 2 days max). Break large tasks into small PRs.
3. **Branch Naming Standard**: `<MODULE_CODE>-<TICKET_NUMBER>-<type>/<description>`
   * *Examples*: `REG-101-feat/add-course-filtering`, `IAM-12-fix/token-expiration`
   * *Allowed types*: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`
4. **Rebase & Squash Merge**: Rebase on `main` before opening PRs (`git pull --rebase origin main`). Always use **Squash and Merge** on GitHub.

---

## Pre-Push Checklist for Developers

Before pushing code or opening a Pull Request, run the automated local pre-flight script:

```bash
bin/ci
```

This single command automatically runs all 5 quality gates:
1. **RuboCop Linter**: `bundle exec rubocop`
2. **Brakeman Security Scanner**: `bin/brakeman --no-pager`
3. **Bundler Audit CVE Scanner**: `bin/bundler-audit`
4. **Database Migration Check**: `bin/rails db:test:prepare`
5. **RSpec Test Suite**: `bundle exec rspec`

Ensure `bin/ci` reports **`✅ All Pre-Flight Checks Passed Cleanly!`** and verify your commit message follows [COMMIT_CONVENTION.md](../COMMIT_CONVENTION.md) (e.g., `git commit -m "feat(be/scope): message"`).

---

## Commit Conventions

All commits **must** follow Conventional Commits with a layer prefix (`be/` for backend):

```bash
git commit -m "feat(be/auth): add user login endpoint"
```

Refer to [COMMIT_CONVENTION.md](../COMMIT_CONVENTION.md) at the repository root for full guidelines.
