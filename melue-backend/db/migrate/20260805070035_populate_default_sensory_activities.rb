class PopulateDefaultSensoryActivities < ActiveRecord::Migration[8.1]
  def up
    activities = [
      { code: 'SEN-001', name: 'Tactile Responsiveness', description: 'Student explores different tactile sensory experiences (sensory board, sensory toys, water, shaving foam.)' },
      { code: 'SEN-002', name: 'Response to Massage', description: 'Student receives massage to assess physical and facial expression responses' },
      { code: 'SEN-003', name: 'Trampoline', description: 'Student engages on a trampoline' },
      { code: 'SEN-004', name: 'Bounce Ball', description: 'Student jumps on a bouncing ball' },
      { code: 'SEN-005', name: 'Balance Beam', description: 'Student walks on a balance beam' },
      { code: 'SEN-006', name: 'Crash Pad', description: 'Student jumps on a crash pad' },
      { code: 'SEN-007', name: 'Sand Play', description: 'Student plays with sand' },
      { code: 'SEN-008', name: 'Seesaw', description: 'Student engages on a seesaw' },
      { code: 'SEN-009', name: 'Slide', description: 'Student engages on a slide' },
      { code: 'SEN-010', name: 'Swing', description: 'Student engages on a swing' },
      { code: 'SEN-011', name: 'Bicycle', description: 'Student rides a bicycle' },
      { code: 'SEN-012', name: 'Turn Taking', description: 'Student takes turns with other students' }
    ]

    activities.each_with_index do |activity, index|
      SensoryActivity.find_or_create_by!(activity_code: activity[:code]) do |a|
        a.name = activity[:name]
        a.description = activity[:description]
        a.display_order = index + 1
        a.is_active = true
      end
    end
  end

  def down
    SensoryActivity.where(activity_code: (1..12).map { |i| format("SEN-%03d", i) }).destroy_all
  end
end
