# Multi-Tenancy Security - CRITICAL TODO

## Status: NOT IMPLEMENTED

The application has indicators of multi-tenancy (organization_name field in form_configurations)
but does NOT have tenant scoping implemented in the session summary feature.

## BLOCKING ISSUE FOR PRODUCTION WITH MULTIPLE CLIENTS

### Current Vulnerability:
Coordinators can access session summaries from ALL organizations by:
1. Listing all summaries without organization filtering
2. Reviewing summaries by guessing UUIDs from other organizations

### Required Fixes (if multi-tenancy is needed):

#### 1. Add Organization Model/Scoping
```ruby
# In models/user.rb or models/staff_member.rb
belongs_to :organization

# In controllers/api/v1/therapy_coordinator/session_summaries_controller.rb
def index
  scope = SessionSummary.joins(therapy_session: { teacher: :organization })
                        .where(organizations: { id: current_user.organization_id })
                        .includes(...)
  # ... rest
end

def set_summary
  @summary = SessionSummary.joins(therapy_session: { teacher: :organization })
                           .where(organizations: { id: current_user.organization_id })
                           .find_by(id: params[:id])
  render_not_found("Session summary not found") unless @summary
end
```

#### 2. Add Tests for Cross-Tenant Access
```ruby
it "prevents coordinator from viewing summaries from other organizations" do
  other_org_summary = create(:session_summary, :submitted, organization: other_org)
  
  get "/api/v1/therapy_coordinator/session_summaries/#{other_org_summary.id}/review",
      headers: coordinator_headers
  
  expect(response).to have_http_status(:not_found)
end
```

## Decision Required:

**Is this application intended to serve multiple organizations/institutions?**

- **YES** → Implement the fixes above BEFORE production deployment
- **NO** → Document that this is a single-tenant application and add guards against multi-tenant usage

## Date Identified: 2026-08-14
