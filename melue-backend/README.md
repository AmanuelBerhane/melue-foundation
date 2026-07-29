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
* **API Documentation**: OasRails (OpenAPI 3.1 with RapiDoc)
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

### 2. First-Time Project Setup (Recommended)
Run the automated setup script to install dependencies, prepare the database, clear old logs, and configure pre-push git hooks in one command:
```bash
cd melue-backend
bin/setup
```

### 3. Environment Configuration
Copy the example environment file:
```bash
cp .env.example .env
```
Update `.env` with your local PostgreSQL user/password if needed.

### 4. Database Setup
Create, migrate, and seed the database (if not using `bin/setup`):
```bash
bin/rails db:prepare
```

### 5. Start Development Server
```bash
bin/rails server
```
The API server will run at `http://localhost:3000`.

### 6. Access API Documentation
Once the server is running, access the interactive API documentation at:
```
http://localhost:3000/docs
```

This provides a **live, interactive view** of all documented API endpoints using RapiDoc. See the [API Documentation](#api-documentation) section below for how to document your endpoints.

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

## API Documentation

We use **OasRails** to generate interactive OpenAPI 3.1 documentation automatically from your code and YARD comments.

### Viewing Documentation

Access the interactive API documentation at:
```
http://localhost:3000/docs
```

This shows all documented endpoints with the ability to test them directly in the browser.

### Documenting Your Endpoints

To include an endpoint in the documentation, add YARD tags to your controller methods:

```ruby
class Api::V1::UsersController < Api::V1::BaseController
  # @oas_include
  # @summary Returns a list of users
  # @tags Users
  # @auth [bearer_jwt]
  #
  # @parameter limit(query) [Integer] Maximum number of users to return. default: (20) minimum: (1) maximum: (100)
  # @parameter offset(query) [Integer] Number of users to skip for pagination. default: (0) minimum: (0)
  #
  # @response Success (200) [Array<Hash{ id: Integer, email: String, created_at: DateTime }>]
  # @response_example Success (200) [JSON[{"id": 1, "email": "user@example.com", "created_at": "2024-01-01T00:00:00Z"}]]
  def index
    users = User.limit(params[:limit] || 20).offset(params[:offset] || 0)
    render json: users
  end
end
```

### Key YARD Tags

| Tag | Purpose | Example |
|-----|---------|---------|
| `@oas_include` | Mark endpoint for inclusion (required) | `# @oas_include` |
| `@summary` | Brief endpoint description | `# @summary Get user by ID` |
| `@tags` | Group endpoints by category | `# @tags Users` |
| `@auth` | Specify auth requirements | `# @auth [bearer_jwt]` |
| `@no_auth` | Mark endpoint as public | `# @no_auth` |
| `@parameter` | Document query/path/header params | `# @parameter id(path) [!Integer] User ID` |
| `@request_body` | Document request body schema | `# @request_body User data [!Hash{ name: String }]` |
| `@response` | Document response schema | `# @response Success (200) [User]` |
| `@response_example` | Add response examples | `# @response_example Success (200) [JSON{...}]` |

### Full Documentation Guide

For comprehensive documentation on using OasRails, including advanced features and examples, see:

**[OAS_RAILS_GUIDE.md](./OAS_RAILS_GUIDE.md)**

This guide covers:
- Complete YARD tag reference
- Request/response documentation patterns
- Using reusable components
- Authentication configuration
- Response examples and schemas

### Tracking API Progress

The `/docs` page shows which endpoints are documented vs. implemented, helping the team track API development progress. Endpoints appear in the documentation only when marked with `@oas_include` and documented with YARD tags.

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
