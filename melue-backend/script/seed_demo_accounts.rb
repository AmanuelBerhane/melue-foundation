# frozen_string_literal: true

require "bcrypt"

puts "Seeding demo accounts for frontend testing..."

demo_accounts = [
  {
    email: "teacher@melue.org",
    role: Role::Names::TEACHER,
    full_name: "Teacher A",
    staff_number: "DEMO-T1"
  },
  {
    email: "coordinator@melue.org",
    role: Role::Names::THERAPY_COORDINATOR,
    full_name: "Coordinator A",
    staff_number: "DEMO-TC"
  },
  {
    email: "director@melue.org",
    role: Role::Names::DIRECTOR,
    full_name: "Director A",
    staff_number: "DEMO-DIR"
  },
  {
    email: "admin@melue.org",
    role: Role::Names::INSTITUTIONAL_ADMIN,
    full_name: "Admin A",
    staff_number: "DEMO-IA"
  },
  {
    email: "sysadmin@melue.org",
    role: Role::Names::SYSTEM_ADMIN,
    full_name: "Sysadmin A",
    staff_number: "DEMO-SA"
  },
  {
    email: "pd@melue.org",
    role: Role::Names::PROGRAM_DIRECTOR,
    full_name: "Program Director A",
    staff_number: "DEMO-PD"
  },
  {
    email: "parent@melue.org",
    role: Role::Names::PARENT,
    full_name: "Parent A",
    is_parent: true
  }
]

password_hash_demo = BCrypt::Password.create("demo1234")

demo_accounts.each do |attrs|
  user = User.find_or_initialize_by(email: attrs[:email])
  user.password_hash = password_hash_demo
  user.status = 2 # verified
  user.save!

  role = Role.find_or_create_by!(name: attrs[:role])
  user.assign_role(role)

  if attrs[:is_parent]
    Guardian.find_or_create_by!(user: user) do |g|
      g.full_name = attrs[:full_name]
    end
  else
    StaffMember.find_or_create_by!(user: user) do |s|
      s.full_name = attrs[:full_name]
      s.staff_number = attrs[:staff_number]
    end
  end
  puts "  ✓ Seeded #{attrs[:email]} (#{attrs[:role]}) with password 'demo1234'"
end

# Also ensure existing seed accounts have roles properly mapped
t1 = User.find_by(email: "teacher1@melue.foundation")
if t1
  t1.password_hash = BCrypt::Password.create("Password123!")
  t1.status = 2
  t1.save!
  t1.assign_role(Role.find_by!(name: Role::Names::TEACHER))
  puts "  ✓ Updated teacher1@melue.foundation with password 'Password123!'"
end

admin_found = User.find_by(email: "admin@melue.foundation")
if admin_found
  admin_found.password_hash = BCrypt::Password.create("Password123!")
  admin_found.status = 2
  admin_found.save!
  admin_found.assign_role(Role.find_by!(name: Role::Names::SYSTEM_ADMIN))
  StaffMember.find_or_create_by!(user: admin_found) do |s|
    s.full_name = "System Admin"
    s.staff_number = "ADM-001"
  end
  puts "  ✓ Updated admin@melue.foundation with password 'Password123!'"
end

puts "Done seeding demo accounts!"
