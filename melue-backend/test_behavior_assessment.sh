#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

BASE_URL="http://localhost:3000"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  jq not found. Installing jq...${NC}"
    sudo apt-get update && sudo apt-get install jq -y
fi

# Login to get a fresh token
echo "🔐 Getting fresh token..."
LOGIN_RESPONSE=$(curl -s -X POST $BASE_URL/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }')

TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.access_token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo -e "${RED}❌ Failed to get token. Please check credentials.${NC}"
  echo "Response: $LOGIN_RESPONSE"
  exit 1
fi

echo -e "${GREEN}✅ Token obtained successfully${NC}"

# Get student ID
STUDENT_ID=$(bin/rails runner "puts Student.first&.id")

if [ -z "$STUDENT_ID" ]; then
  echo -e "${YELLOW}⚠️  No student found. Creating test student...${NC}"
  STUDENT_ID=$(bin/rails runner "
    student = Student.create!(
      first_name: 'Test',
      last_name: 'Student',
      date_of_birth: '2015-01-01',
      guardian_name: 'Test Guardian',
      guardian_phone: '555-1234',
      program_type: 'regular',
      therapy_group: 'basic',
      status: 'in_assessment'
    )
    puts student.id
  ")
  echo -e "${GREEN}✅ Test student created: $STUDENT_ID${NC}"
fi

echo ""
echo "========================================="
echo "🔍 Manual Testing for Behavior Assessment"
echo "========================================="
echo ""
echo "Student ID: $STUDENT_ID"
echo ""

# Test 1: MASS Assessment
echo "--- Test 1: MASS Assessment (FR-041, FR-042) ---"
MASS_RESPONSE=$(curl -s -X POST $BASE_URL/api/v1/assessments/mass \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"student_id\": \"$STUDENT_ID\"}")

MASS_ID=$(echo "$MASS_RESPONSE" | jq -r '.id' 2>/dev/null)
if [ "$MASS_ID" != "null" ] && [ -n "$MASS_ID" ]; then
  echo -e "${GREEN}✅ MASS Assessment created: $MASS_ID${NC}"
else
  echo -e "${RED}❌ MASS Assessment creation failed${NC}"
  echo "$MASS_RESPONSE"
fi

# Test 2: FAST Assessment
echo ""
echo "--- Test 2: FAST Assessment (FR-043, FR-044) ---"
FAST_RESPONSE=$(curl -s -X POST $BASE_URL/api/v1/assessments/fast \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"student_id\": \"$STUDENT_ID\"}")

FAST_ID=$(echo "$FAST_RESPONSE" | jq -r '.id' 2>/dev/null)
if [ "$FAST_ID" != "null" ] && [ -n "$FAST_ID" ]; then
  echo -e "${GREEN}✅ FAST Assessment created: $FAST_ID${NC}"
else
  echo -e "${RED}❌ FAST Assessment creation failed${NC}"
  echo "$FAST_RESPONSE"
fi

# Test 3: Behavior Incident
echo ""
echo "--- Test 3: Behavior Incident (FR-045, FR-046) ---"
INCIDENT_RESPONSE=$(curl -s -X POST $BASE_URL/api/v1/students/$STUDENT_ID/behavior_incidents \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "student_id": "'$STUDENT_ID'",
    "behavior_name": "Elopement",
    "frequency": "frequently",
    "intensity": "moderate",
    "category": "safety_concerns",
    "antecedent": "Transition to new activity",
    "consequence": "Redirected back",
    "location": "Classroom",
    "occurred_at": "'$(date -Iseconds)'"
  }')

INCIDENT_ID=$(echo "$INCIDENT_RESPONSE" | jq -r '.id' 2>/dev/null)
if [ "$INCIDENT_ID" != "null" ] && [ -n "$INCIDENT_ID" ]; then
  echo -e "${GREEN}✅ Behavior Incident created: $INCIDENT_ID${NC}"
else
  echo -e "${RED}❌ Behavior Incident creation failed${NC}"
  echo "$INCIDENT_RESPONSE"
fi

# Test 4: Get Behavior Incidents
echo ""
echo "--- Test 4: Get Behavior Incidents ---"
INCIDENTS=$(curl -s -X GET "$BASE_URL/api/v1/students/$STUDENT_ID/behavior_incidents?student_id=$STUDENT_ID" \
  -H "Authorization: Bearer $TOKEN")

INCIDENT_COUNT=$(echo "$INCIDENTS" | jq '. | length' 2>/dev/null)
if [ "$INCIDENT_COUNT" -gt 0 ] 2>/dev/null; then
  echo -e "${GREEN}✅ Retrieved $INCIDENT_COUNT incidents${NC}"
else
  echo -e "${YELLOW}⚠️ No incidents found or error occurred${NC}"
fi

# Test 5: Dashboard
echo ""
echo "--- Test 5: Assessment Dashboard (FR-084) ---"
DASHBOARD=$(curl -s -X GET "$BASE_URL/api/v1/assessments/dashboard" \
  -H "Authorization: Bearer $TOKEN")

TOTAL=$(echo "$DASHBOARD" | jq -r '.summary.total_students' 2>/dev/null)
if [ "$TOTAL" -ge 0 ] 2>/dev/null; then
  echo -e "${GREEN}✅ Dashboard returned total students: $TOTAL${NC}"
else
  echo -e "${RED}❌ Dashboard failed${NC}"
  echo "$DASHBOARD"
fi

# Test 6: Launch Assessment
echo ""
echo "--- Test 6: Launch Assessment (FR-035) ---"
LAUNCH=$(curl -s -X POST "$BASE_URL/api/v1/assessments/launch" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"student_id\": \"$STUDENT_ID\", \"assessment_type\": \"skills\"}")

LAUNCH_STATUS=$(echo "$LAUNCH" | jq -r '.status' 2>/dev/null)
if [ "$LAUNCH_STATUS" = "in_progress" ]; then
  echo -e "${GREEN}✅ Launch assessment successful: $LAUNCH_STATUS${NC}"
else
  echo -e "${RED}❌ Launch failed${NC}"
  echo "$LAUNCH"
fi

# Test 7: Get the created assessments
echo ""
echo "--- Test 7: Verify Assessments Created ---"
echo "MASS ID: $MASS_ID"
echo "FAST ID: $FAST_ID"
echo "Incident ID: $INCIDENT_ID"

echo ""
echo "========================================="
echo "✅ Manual Testing Complete!"
echo "========================================="
