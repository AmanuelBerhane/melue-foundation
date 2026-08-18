#!/bin/bash
echo "🔍 Running Pre-Push Checks for MR-30 (Goal Management + Charts)..."
echo ""

# 1. Check migrations - FIXED
echo "📦 1. Checking migrations..."

# Check if there are any migrations with status "down"
if bin/rails db:migrate:status | grep -E '^[[:space:]]*down[[:space:]]'; then
    echo "⚠️  Pending migrations found!"
    echo "Run: bin/rails db:migrate"
    exit 1
fi
echo "✅ Migrations OK"

# 2. Reset test database
echo ""
echo "📦 2. Resetting test database..."
bin/rails db:test:prepare

# 3. Run chart service tests
echo ""
echo "📦 3. Running chart service tests..."
bundle exec rspec spec/services/charts/ || exit 1
echo "✅ Chart service tests passing"

# 4. Run goal management tests
echo ""
echo "📦 4. Running goal management tests..."
bundle exec rspec spec/services/students/ spec/services/goals/ || exit 1
echo "✅ Goal management tests passing"

# 5. Run request tests
echo ""
echo "📦 5. Running request tests..."
bundle exec rspec spec/requests/api/v1/students/charts_spec.rb || exit 1
echo "✅ Request tests passing"

# 6. Run RuboCop
echo ""
echo "📦 6. Running RuboCop..."
bundle exec rubocop app/services/charts/ app/services/students/ app/services/goals/ || exit 1
echo "✅ RuboCop passing"

# 7. Run full CI
echo ""
echo "📦 7. Running full CI..."
bin/ci || exit 1
echo "✅ CI passing"

echo ""
echo "🎉 All checks passed! "
echo ""