# Commit Convention

We follow the **Conventional Commits** specification.

## Structure

```
<type>(<layer>/<scope>): <subject>

[optional body]

[optional footer]
```

## Layer Prefix

Every commit **must** include a layer prefix as the first part of the scope to indicate which part of the codebase was changed.

| Layer | When to use |
|---|---|
| `be` | Changes to `melue-backend` |
| `fe` | Changes to `melue-frontend` |

The full scope field becomes `<layer>/<scope>`, e.g. `be/usm` or `fe/auth`.

When a commit touches both layers (rare in trunk-based development — prefer splitting), use `be+fe/<scope>`.

## Types

| Type | Description |
|---|---|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Code refactoring |
| `perf` | Performance improvement |
| `test` | Adding or updating tests |
| `docs` | Documentation changes |
| `style` | Code style/formatting |
| `chore` | Maintenance, dependency updates |
| `ci` | CI/CD changes |
| `build` | Build system changes |

## Examples

```bash
# Backend feature
git commit -m "feat(be/usm): add user authentication endpoint"

# Backend bug fix with body and YouTrack reference
git commit -m "fix(be/registration): resolve duplicate student enrollment

The enrollment service was allowing duplicate enrollments due to
a race condition in the validation logic. Added a unique constraint
at the database level and improved the service validation.

Fixes: USM-1"

# Frontend feature
git commit -m "feat(fe/dashboard): add enrollment summary widget"

# Breaking change on the backend API (add ! after type)
git commit -m "feat(be/api)!: change authentication response format

BREAKING CHANGE: The authentication endpoint now returns a different
response structure.

Refs: USM-42"
```

## Rules

1. Use imperative mood — `"add feature"` not `"added feature"`
2. Always include a layer prefix in the scope: `be/` or `fe/`
3. Subject line under 72 characters
4. No period at the end of the subject line
5. Separate subject from body with a blank line
6. Reference YouTrack cards in the footer
