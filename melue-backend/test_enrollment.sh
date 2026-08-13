#!/bin/bash
# Final test script for Enrollment Wizard

echo "🔍 Running Final Enrollment Wizard Tests..."

echo ""
echo "📦 1. Running all tests..."
bundle exec rspec

echo ""
echo "📦 2. Running specific Enrollment tests..."
bundle exec rspec spec/models/student_spec.rb
bundle exec rspec spec/services/enrollment_service_spec.rb
bundle exec rspec spec/requests/api/v1/enrollments_spec.rb

echo ""
echo "📦 3. Checking migrations..."
bin/rails db:migrate:status

echo ""
echo "📦 4. Running RuboCop..."
bundle exec rubocop app/models/student.rb
bundle exec rubocop app/services/enrollment_service.rb
bundle exec rubocop app/controllers/api/v1/enrollments_controller.rb

echo ""
echo "📦 5. Checking migrations..."
bin/rails db:migrate

echo ""
echo "📦 6. Checking database integrity..."
bin/rails runner "puts 'Student count: ' + Student.count.to_s"

echo ""
echo "✅ All checks complete!"
echo ""