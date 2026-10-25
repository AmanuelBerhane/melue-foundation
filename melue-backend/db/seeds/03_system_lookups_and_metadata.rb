# frozen_string_literal: true

# ==============================================================================
# Melue Foundation Therapy Management System — Database Seeds
# File 3/5: db/seeds/03_system_lookups_and_metadata.rb
#
# Scope:
#   1. 12 Default Sensory Activities (SEN-001 through SEN-012 per FR-051b)
#   2. Clinical ABC Dropdown Lists (Antecedents, Behaviors, Consequences per FR-147/148)
#   3. Five-Category Preference Assessment Item Inventory (FR-047a)
#   4. Canonical Goal Domains & Standard Goal Bank (Exclusively Standard Goals — No TA Steps)
#   5. Complete 25-Domain ABLLS-R Hierarchy (A–Z) & Baseline Skill Items
# ==============================================================================

puts "\n" + ("=" * 80)
puts "  [SEED 03/05] SYSTEM LOOKUPS, CLINICAL TAXONOMIES & METADATA"
puts ("=" * 80)

ActiveRecord::Base.transaction do
  # ----------------------------------------------------------------------------
  # 1. 12 Default Sensory Activities (SRS 3.3.5 / FR-051b)
  # ----------------------------------------------------------------------------
  puts "\n--> Provisioning 12 Canonical Sensory Activities (SEN-001 to SEN-012)..."

  sensory_activities_seed = [
    { code: "SEN-001", name: "Tactile Responsiveness",  description: "Sensory board, water, shaving foam, lotion exploration",   order: 1  },
    { code: "SEN-002", name: "Response to Massage",     description: "Physical and facial expression reactions to deep pressure", order: 2  },
    { code: "SEN-003", name: "Trampoline",              description: "Jumping and motor engagement on rebounder",                order: 3  },
    { code: "SEN-004", name: "Bounce Ball",             description: "Bouncing ball engagement and rhythm coordination",         order: 4  },
    { code: "SEN-005", name: "Balance Beam",            description: "Dynamic balance walking and postural control",             order: 5  },
    { code: "SEN-006", name: "Crash Pad",               description: "Jumping and crashing kinetic proprioceptive play",          order: 6  },
    { code: "SEN-007", name: "Sand Play",               description: "Tactile exploration and molding in sand area",              order: 7  },
    { code: "SEN-008", name: "Seesaw",                  description: "Partner kinetic engagement and vestibular rocking",        order: 8  },
    { code: "SEN-009", name: "Slide",                   description: "Climbing ladder and sliding motor sequence",               order: 9  },
    { code: "SEN-010", name: "Swing",                   description: "Linear and rotational vestibular swing stimulation",        order: 10 },
    { code: "SEN-011", name: "Bicycle",                 description: "Pedaling and bilateral lower body coordination",           order: 11 },
    { code: "SEN-012", name: "Turn Taking",             description: "Peer interactive play routines and shared equipment turns", order: 12 }
  ]

  sensory_activities_seed.each do |attrs|
    activity = SensoryActivity.find_or_initialize_by(activity_code: attrs[:code])
    activity.name          = attrs[:name]
    activity.description   = attrs[:description]
    activity.display_order = attrs[:order]
    activity.is_active     = true
    activity.save!

    puts "    ✓ Sensory Activity: [#{activity.activity_code}] #{activity.name.ljust(24)} (Order: #{activity.display_order})"
  end

  # ----------------------------------------------------------------------------
  # 2. Clinical ABC Dropdown Lists (SRS 3.6.3 / FR-147, FR-148)
  # ----------------------------------------------------------------------------
  puts "\n--> Provisioning Clinical ABC Dropdown Lists (Antecedents, Behaviors, Consequences)..."

  # 2a. Behaviors
  behaviors_seed = [
    { label: "Screaming",                 order: 1 },
    { label: "Biting others",             order: 2 },
    { label: "Flopping",                  order: 3 },
    { label: "Unable to remain seated",   order: 4 },
    { label: "Scratching",                order: 5 },
    { label: "Elopement / Wandering",     order: 6 },
    { label: "Hitting",                   order: 7 },
    { label: "Property destruction",      order: 8 },
    { label: "Other",                     order: 9, is_other: true }
  ]

  behaviors_seed.each do |attrs|
    opt = AbcDropdownOption.find_or_initialize_by(category: :behavior, label: attrs[:label])
    opt.display_order = attrs[:order]
    opt.is_other      = attrs[:is_other] || false
    opt.is_active     = true
    opt.save!
  end
  puts "    ✓ Seeded #{behaviors_seed.size} Behavior dropdown options"

  # 2b. Antecedents
  antecedents_seed = [
    { label: "Instructor instruction: '3, 2, 1 give me...'",                         order: 1 },
    { label: "Demand to transition away from high-preference activity (sand, crash pad)", order: 2 },
    { label: "Instructor engaged in report writing / divided attention",              order: 3 },
    { label: "Therapy room door opened",                                              order: 4 },
    { label: "Completion of snack / unstructured transition",                         order: 5 },
    { label: "Task demand presented",                                                 order: 6 },
    { label: "Denied access to preferred item",                                       order: 7 },
    { label: "Other",                                                                 order: 8, is_other: true }
  ]

  antecedents_seed.each do |attrs|
    opt = AbcDropdownOption.find_or_initialize_by(category: :antecedent, label: attrs[:label])
    opt.display_order = attrs[:order]
    opt.is_other      = attrs[:is_other] || false
    opt.is_active     = true
    opt.save!
  end
  puts "    ✓ Seeded #{antecedents_seed.size} Antecedent dropdown options"

  # 2c. Consequences
  consequences_seed = [
    { label: "Wait time / 3-second delay provided for independent response", order: 1 },
    { label: "Verbal redirection / '3, 2, 1 STOP'",                          order: 2 },
    { label: "Response blocking / hand held and returned to area",           order: 3 },
    { label: "Prompted to mand / request appropriately",                     order: 4 },
    { label: "Planned ignoring until calm",                                  order: 5 },
    { label: "Given sensory break",                                          order: 6 },
    { label: "Redirected to task",                                           order: 7 },
    { label: "Other",                                                        order: 8, is_other: true }
  ]

  consequences_seed.each do |attrs|
    opt = AbcDropdownOption.find_or_initialize_by(category: :consequence, label: attrs[:label])
    opt.display_order = attrs[:order]
    opt.is_other      = attrs[:is_other] || false
    opt.is_active     = true
    opt.save!
  end
  puts "    ✓ Seeded #{consequences_seed.size} Consequence dropdown options"

  # ----------------------------------------------------------------------------
  # 3. Preference Assessment Item Inventory (SRS 3.3.4 / FR-047a)
  # ----------------------------------------------------------------------------
  puts "\n--> Provisioning Preference Assessment Item Inventory (5 Categories)..."

  inventory_items_seed = {
    "Visual" => [
      "Phone", "TV", "Flashlight", "Picture books", "Balloon",
      "Crayons or markers", "Painting", "Shadow", "Beads", "Pouring liquids"
    ],
    "Sensory" => [
      "Lotion", "Play doh", "Sand play", "Water play",
      "Toys that bend or stretch", "Finger painting", "Soap bubbles", "Shining"
    ],
    "Auditory" => [
      "Toys that talk or sing", "Music", "Low pitch voice", "Stress balls"
    ],
    "Movement" => [
      "Movement", "Rolling on floor", "Being held upside down"
    ],
    "Toys" => [
      "Tube car", "Frog toy", "Coloring tube", "Fish toy", "Red plastic toy",
      "Stress ball", "Flexy red", "Piano", "Coloring glitter", "Body part puzzle",
      "Letter mat", "Gross motor handle", "Seesaw", "Slide", "Magnetic Apple",
      "Mobile art", "Watch", "Large & small toys", "Harmonica", "Stretch spring",
      "Bicycle", "Number book", "Spinner", "Colors"
    ]
  }

  total_inventory_items = 0
  inventory_items_seed.each do |category, item_names|
    item_names.each do |name|
      item = PreferenceInventoryItem.find_or_initialize_by(category: category, name: name)
      item.is_active     = true
      item.discarded_at  = nil
      item.save!
      total_inventory_items += 1
    end
    puts "    ✓ Category: #{category.ljust(10)} (#{item_names.size} items)"
  end
  puts "    ✓ Total Preference Inventory Items: #{total_inventory_items}"

  # ----------------------------------------------------------------------------
  # 4. Canonical Goal Domains & Standard Goal Bank (SRS 3.5.1 / FR-071)
  #    CRITICAL RESTRICTION: Exclusively goal_type: "standard". No TA templates.
  # ----------------------------------------------------------------------------
  puts "\n--> Provisioning 5 Goal Domains & Standard Clinical Goal Bank (No TA Steps)..."

  domains_seed = [
    { name: "Communication", order: 1 },
    { name: "Motor",         order: 2 },
    { name: "Social",        order: 3 },
    { name: "Self-Help",     order: 4 },
    { name: "Cognition",     order: 5 }
  ]

  domain_records = {}
  domains_seed.each do |attrs|
    domain = GoalDomain.find_or_initialize_by(name: attrs[:name])
    domain.display_order = attrs[:order]
    domain.is_active     = true
    domain.discarded_at  = nil
    domain.save!
    domain_records[attrs[:name]] = domain
  end

  # Goals catalogue strictly adhering to goal_type: "standard"
  goals_seed = [
    # ── Communication ──────────────────────────────────────────────────────────
    { domain: "Communication", name: "Request preferred items using words" },
    { domain: "Communication", name: "Functional Requesting (Mand via sign or distal point)" },
    { domain: "Communication", name: "Follow two-step verbal instructions" },
    { domain: "Communication", name: "Answer simple 'what' questions" },
    { domain: "Communication", name: "Vocal imitation of series of speech sounds" },

    # ── Motor ──────────────────────────────────────────────────────────────────
    { domain: "Motor", name: "Imitate motor actions with objects upon 'Do this'" },
    { domain: "Motor", name: "Maintain pencil grip for 3 minutes" },
    { domain: "Motor", name: "Stack 6 blocks independently" },
    { domain: "Motor", name: "Cut along a straight line with scissors" },

    # ── Social ─────────────────────────────────────────────────────────────────
    { domain: "Social", name: "Initiate greeting with peers" },
    { domain: "Social", name: "Respond to greetings and goodbyes from others" },
    { domain: "Social", name: "Take turns in structured play" },
    { domain: "Social", name: "Make eye contact during conversation" },
    { domain: "Social", name: "Share materials with a peer" },

    # ── Self-Help ──────────────────────────────────────────────────────────────
    { domain: "Self-Help", name: "Washing Hands" },
    { domain: "Self-Help", name: "Toileting - Urination" },
    { domain: "Self-Help", name: "Toileting - Request" },
    { domain: "Self-Help", name: "Dressing - Shoes" },
    { domain: "Self-Help", name: "Dressing - Pants" },
    { domain: "Self-Help", name: "Pack school bag" },

    # ── Cognition ──────────────────────────────────────────────────────────────
    { domain: "Cognition", name: "Match identical objects" },
    { domain: "Cognition", name: "Match objects to pictures" },
    { domain: "Cognition", name: "Sort objects by color" },
    { domain: "Cognition", name: "Identify letters A-Z by name" },
    { domain: "Cognition", name: "Count objects 1-10 with one-to-one correspondence" }
  ]

  goals_seed.each do |attrs|
    domain = domain_records[attrs[:domain]]
    goal = Goal.find_or_initialize_by(name: attrs[:name], goal_domain: domain)
    goal.goal_type    = :standard
    goal.is_active    = true
    goal.discarded_at = nil
    goal.save!
  end

  puts "    ✓ Seeded #{GoalDomain.count} Goal Domains and #{Goal.count} Standard Goals across:"
  domain_records.each do |name, d|
    puts "      - #{name.ljust(15)} : #{d.goals.count} goals"
  end

  # ----------------------------------------------------------------------------
  # 5. ABLLS-R Domains & Skills Catalogue (SRS 3.3.3)
  # ----------------------------------------------------------------------------
  puts "\n--> Provisioning Full 25-Domain ABLLS-R Hierarchy (A–Z) & Skill Items..."

  ablls_domain_definitions = [
    { code: "A", name: "Cooperation and Reinforcer Effectiveness", position: 1  },
    { code: "B", name: "Visual Performance",                       position: 2  },
    { code: "C", name: "Receptive Language",                       position: 3  },
    { code: "D", name: "Motor Imitation",                          position: 4  },
    { code: "E", name: "Vocal Imitation",                          position: 5  },
    { code: "F", name: "Requests (Mands)",                         position: 6  },
    { code: "G", name: "Labeling (Tacts)",                         position: 7  },
    { code: "H", name: "Intraverbals",                             position: 8  },
    { code: "I", name: "Spontaneous Vocalizations",                position: 9  },
    { code: "J", name: "Syntax and Grammar",                       position: 10 },
    { code: "K", name: "Play and Leisure",                         position: 11 },
    { code: "L", name: "Social Interaction",                       position: 12 },
    { code: "M", name: "Group Instruction",                        position: 13 },
    { code: "N", name: "Classroom Routines",                       position: 14 },
    { code: "P", name: "Generalized Responding",                   position: 15 },
    { code: "Q", name: "Reading",                                  position: 16 },
    { code: "R", name: "Math",                                     position: 17 },
    { code: "S", name: "Writing",                                  position: 18 },
    { code: "T", name: "Spelling",                                 position: 19 },
    { code: "U", name: "Dressing",                                 position: 20 },
    { code: "V", name: "Eating",                                   position: 21 },
    { code: "W", name: "Grooming",                                 position: 22 },
    { code: "X", name: "Toileting",                                position: 23 },
    { code: "Y", name: "Gross Motor",                              position: 24 },
    { code: "Z", name: "Fine Motor",                               position: 25 }
  ]

  ablls_domain_records = {}
  ablls_domain_definitions.each do |attrs|
    domain = AbllsDomain.find_or_initialize_by(code: attrs[:code])
    domain.name         = attrs[:name]
    domain.position     = attrs[:position]
    domain.is_active    = true
    domain.discarded_at = nil
    domain.save!
    ablls_domain_records[attrs[:code]] = domain
  end

  ablls_skill_items_seed = {
    "A" => [
      "Willingly goes with a teacher to the teaching area",
      "Accepts reinforcers from a teacher",
      "Sits in a chair at a table for 2 minutes",
      "Attends to reinforcers for at least 5 seconds"
    ],
    "B" => [
      "Attends to a visual stimulus for at least 3 seconds",
      "Tracks a moving object across midline",
      "Matches identical objects",
      "Matches identical pictures",
      "Sorts objects by color"
    ],
    "C" => [
      "Looks at or orients toward a sound source",
      "Follows instruction to sit down",
      "Follows instruction to stand up",
      "Follows instruction to come here",
      "Identifies common objects when named"
    ],
    "D" => [
      "Imitates gross motor movements (arms up)",
      "Imitates touching body parts",
      "Imitates actions with objects",
      "Imitates fine motor movements",
      "Imitates a sequence of 2 movements"
    ],
    "E" => [
      "Imitates vowel sounds",
      "Imitates consonant-vowel combinations",
      "Imitates single words",
      "Imitates two-word phrases"
    ],
    "F" => [
      "Requests preferred items using words or signs",
      "Requests help",
      "Requests attention from an adult",
      "Requests break or cessation of activity",
      "Requests using a multi-word phrase"
    ],
    "G" => [
      "Labels common objects",
      "Labels pictures of common objects",
      "Labels actions in pictures",
      "Labels colors",
      "Labels shapes"
    ],
    "H" => [
      "Fills in words of familiar songs",
      "Answers simple 'what' questions",
      "Answers 'where' questions about common objects",
      "Answers 'who' questions",
      "Describes the function of common objects"
    ],
    "I" => [
      "Spontaneously vocalizes (babbles/jargon)",
      "Spontaneously produces recognizable words",
      "Spontaneously produces word combinations",
      "Initiates comments about the environment"
    ],
    "J" => [
      "Uses noun-verb combinations",
      "Uses pronouns correctly",
      "Uses prepositions in speech",
      "Uses plurals correctly"
    ],
    "K" => [
      "Independently explores toys and materials",
      "Engages in cause-and-effect play",
      "Engages in pretend play",
      "Plays simple games with rules",
      "Plays cooperatively with peers for 5 minutes"
    ],
    "L" => [
      "Makes eye contact with familiar adults",
      "Responds to greetings from others",
      "Initiates greetings",
      "Shares items with peers",
      "Takes turns with peers during activities"
    ],
    "M" => [
      "Sits appropriately in a group for 3 minutes",
      "Attends to teacher during group instruction",
      "Responds to group instructions",
      "Raises hand to answer questions in group"
    ],
    "N" => [
      "Follows transition routine between activities",
      "Follows classroom clean-up routine",
      "Hangs up backpack/coat independently",
      "Lines up when directed"
    ],
    "P" => [
      "Responds to instructions in a novel environment",
      "Responds to instructions from a novel teacher",
      "Generalizes labeling to novel examples",
      "Generalizes requesting skills across settings"
    ],
    "Q" => [
      "Identifies letters of the alphabet",
      "Associates letters with their sounds",
      "Reads simple CVC words",
      "Reads common sight words"
    ],
    "R" => [
      "Rote counts to 10",
      "Counts objects with one-to-one correspondence",
      "Identifies written numerals 1-10",
      "Compares quantities (more/less)"
    ],
    "S" => [
      "Holds a writing utensil with appropriate grip",
      "Traces lines and shapes",
      "Copies letters from a model",
      "Writes first name independently"
    ],
    "T" => [
      "Spells own first name orally",
      "Spells simple CVC words",
      "Identifies beginning sounds in words"
    ],
    "U" => [
      "Removes shoes independently",
      "Puts on shoes independently",
      "Removes pullover shirt",
      "Puts on pullover shirt",
      "Fastens large buttons"
    ],
    "V" => [
      "Drinks from an open cup",
      "Eats with a spoon independently",
      "Eats with a fork independently",
      "Uses a napkin when prompted"
    ],
    "W" => [
      "Washes hands with soap and water",
      "Dries hands with a towel",
      "Brushes teeth with assistance",
      "Wipes face with a cloth"
    ],
    "X" => [
      "Indicates need to use the toilet",
      "Uses the toilet for urination",
      "Uses the toilet for bowel movements",
      "Pulls pants up/down for toileting"
    ],
    "Y" => [
      "Walks independently",
      "Runs without falling",
      "Climbs stairs alternating feet",
      "Kicks a ball forward",
      "Catches a large ball with two hands"
    ],
    "Z" => [
      "Picks up small objects using pincer grasp",
      "Stacks 6 or more blocks",
      "Strings large beads",
      "Uses scissors to cut along a straight line",
      "Completes simple puzzles (4-6 pieces)"
    ]
  }

  total_ablls_items = 0
  ablls_skill_items_seed.each do |domain_code, descriptions|
    domain = ablls_domain_records[domain_code]
    descriptions.each_with_index do |desc, index|
      identifier = "#{domain_code}#{index + 1}"
      item = AbllsSkillItem.find_or_initialize_by(identifier: identifier)
      item.ablls_domain = domain
      item.description  = desc
      item.position     = index + 1
      item.is_active    = true
      item.discarded_at = nil
      item.save!
      total_ablls_items += 1
    end
  end

  puts "    ✓ Synchronized #{AbllsDomain.count} ABLLS-R domains and #{total_ablls_items} skill items."

  # ----------------------------------------------------------------------------
  # Final Step 3 Verification Summary
  # ----------------------------------------------------------------------------
  puts "\n--> System Lookups & Metadata Summary:"
  puts "    Sensory Activities:          #{SensoryActivity.count}"
  puts "    ABC Dropdown Options:        #{AbcDropdownOption.count}"
  puts "      - Behaviors:               #{AbcDropdownOption.behavior.count}"
  puts "      - Antecedents:             #{AbcDropdownOption.antecedent.count}"
  puts "      - Consequences:            #{AbcDropdownOption.consequence.count}"
  puts "    Preference Inventory Items:  #{PreferenceInventoryItem.count}"
  puts "    Goal Domains:                #{GoalDomain.count}"
  puts "    Standard Goals (Zero TA):    #{Goal.standard.count}"
  puts "    ABLLS Domains:               #{AbllsDomain.count}"
  puts "    ABLLS Skill Items:           #{AbllsSkillItem.count}"
  puts ("=" * 80) + "\n"
end
