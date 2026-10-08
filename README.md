# Melu-e Foundation

The foundational repository for the Melu-e special education management platform, housing the Rails 8 API backend and core services.

---

## Repository Structure

```text
melue-foundation/
├── melue-backend/          # Ruby on Rails 8 API server (PostgreSQL, Rodauth, JWT)
├── references/             # Architectural specifications, domain models, and designs
├── .gitignore              # Monorepo-level git ignore rules
└── README.md               # This repository documentation
```

---

## Backend Services (`melue-backend/`)

The primary API engine powering the Melu-e platform.

### Quick Start
```bash
cd melue-backend

# 1. Install dependencies
bundle install

# 2. Setup environment configuration
cp .env.example .env

# 3. Setup and migrate database
bin/rails db:prepare

# 4. Seed demo accounts
bin/rails runner script/seed_demo_accounts.rb

# 5. Start API server on port 3000
bin/rails server -p 3000
```

For full backend details, architecture patterns, and API documentation tags, see **[melue-backend/README.md](./melue-backend/README.md)**.

---

## Quality & Contribution Guidelines

Before pushing to any branch:
```bash
cd melue-backend
bin/ci
```

This runs RuboCop linting, Brakeman security audits, Bundler CVE scanner, database migration checks, and RSpec unit tests.
