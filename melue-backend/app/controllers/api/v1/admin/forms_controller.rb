# frozen_string_literal: true

module Api
  module V1
    module Admin
      class FormsController < BaseController
        before_action :authenticate_user!
        before_action :set_form_config

        # GET /api/v1/admin/forms/:form_name
        def show
          schema = @form_config.field_schema || {}
          fields = schema["fields"] || []

          # If empty, populate with standard defaults
          if fields.empty?
            schema = default_schema_for(@form_config.form_type)
            @form_config.update!(field_schema: schema)
          end

          render json: {
            formName: @form_config.form_name,
            formType: @form_config.form_type,
            revisionNumber: @form_config.revision_number,
            isDefault: @form_config.is_default,
            fields: schema["fields"] || [],
            customSections: schema["customSections"] || schema["sections"] || [],
            deletedSections: schema["deletedSections"] || [],
            history: schema["history"] || []
          }
        end

        # POST /api/v1/admin/forms/:form_name
        def update_config
          payload = begin
            parsed = JSON.parse(request.raw_post) rescue nil
            parsed.is_a?(Hash) ? parsed : request.request_parameters.except("controller", "action", "form_name")
          end

          fields = payload["fields"] || []
          custom_sections = payload["customSections"] || payload["sections"] || []
          deleted_sections = payload["deletedSections"] || []
          history = payload["history"] || []
          is_default = payload["isDefault"] == true

          schema = {
            "fields" => fields,
            "customSections" => custom_sections,
            "deletedSections" => deleted_sections,
            "history" => history
          }

          @form_config.field_schema = schema
          @form_config.is_default = is_default
          @form_config.revision_number = (@form_config.revision_number || 1) + 1
          @form_config.revision_date = Date.current
          @form_config.save!

          render json: {
            formName: @form_config.form_name,
            formType: @form_config.form_type,
            revisionNumber: @form_config.revision_number,
            isDefault: @form_config.is_default,
            fields: fields,
            customSections: custom_sections,
            deletedSections: deleted_sections,
            history: history
          }
        end

        # POST /api/v1/admin/forms/:form_name/reset
        def reset
          default_schema = default_schema_for(@form_config.form_type)
          @form_config.update!(
            field_schema: default_schema,
            is_default: true,
            revision_date: Date.current
          )

          render json: { status: "ok" }
        end

        private

        def set_form_config
          name = URI.decode_www_form_component(params[:form_name].to_s).strip

          # Map user-friendly form names to form_type enum
          type = case name.downcase
          when /enroll/ then :enrollment
          when /iup/ then :iup
          when /ablls/ then :ablls
          when /incident/ then :abc_data_sheet
          when /behavior/ then :behavioral_assessment
          when /sensory/ then :sensory
          when /preference/ then :preference_assessment
          when /data record|task analysis/ then :task_analysis
          when /social/ then :social_skills
          else :enrollment
          end

          @form_config = FormConfiguration.find_by("lower(form_name) = ?", name.downcase) ||
                         FormConfiguration.find_by(form_type: type) ||
                         FormConfiguration.find_or_create_by!(form_type: type) do |fc|
                           fc.form_name = name
                           fc.is_default = true
                           fc.revision_number = 1
                           fc.field_schema = default_schema_for(type)
                         end
        end

        def default_schema_for(type)
          case type.to_s
          when "enrollment"
            {
              "fields" => [
                { "id" => "f1", "type" => "text", "label" => "Full Name", "required" => true, "visible" => true, "section" => "Student Info" },
                { "id" => "f2", "type" => "date", "label" => "Date of Birth", "required" => true, "visible" => true, "section" => "Student Info" },
                { "id" => "f4", "type" => "text", "label" => "Parent / Guardian Name", "required" => true, "visible" => true, "section" => "Parent Info" },
                { "id" => "f5", "type" => "text", "label" => "Parent Phone", "required" => true, "visible" => true, "section" => "Parent Info" },
                { "id" => "f6", "type" => "text", "label" => "Parent Email", "required" => true, "visible" => true, "section" => "Parent Info" },
                { "id" => "f7", "type" => "textarea", "label" => "Medical Notes & Allergies", "required" => false, "visible" => true, "section" => "Medical Info" },
                { "id" => "f8", "type" => "checkbox", "label" => "Transportation Required", "required" => false, "visible" => true, "section" => "Medical Info" },
                { "id" => "f9", "type" => "text", "label" => "Emergency Contact", "required" => false, "visible" => true, "section" => "Parent Info" }
              ],
              "customSections" => [ "Student Info", "Parent Info", "Medical Info" ],
              "deletedSections" => [],
              "history" => []
            }
          when "iup"
            {
              "fields" => [
                { "id" => "i1", "type" => "text", "label" => "Student Name", "required" => true, "visible" => true, "section" => "General" },
                { "id" => "i2", "type" => "dropdown", "label" => "Target Skill Domain", "required" => true, "visible" => true, "section" => "General", "options" => [ "Language & Communication", "Social Interaction", "Adaptive & Self-Care", "Motor Skills", "Cognitive" ] },
                { "id" => "i3", "type" => "number", "label" => "Baseline Mastery (%)", "required" => true, "visible" => true, "section" => "General" },
                { "id" => "i4", "type" => "textarea", "label" => "Target Objective", "required" => true, "visible" => true, "section" => "General" }
              ],
              "customSections" => [ "General" ],
              "deletedSections" => [],
              "history" => []
            }
          when "abc_data_sheet"
            # Behavior Incident Form: strictly Antecedent (A), Behavior (B), Consequence (C)
            {
              "fields" => [
                { "id" => "b_ant", "type" => "dropdown", "label" => "Antecedent (A)", "required" => true, "visible" => true, "section" => "ABC Tracking", "options" => [ "Demand / Non-Preferred Task", "Transition / Room Change", "Denied Access to Preferred Item", "Attention Diverted", "Sensory Overload / Overstimulation", "Fatigue / Discomfort", "Unstructured Free Time" ] },
                { "id" => "b_beh", "type" => "dropdown", "label" => "Behavior (B)", "required" => true, "visible" => true, "section" => "ABC Tracking", "options" => [ "Screaming / Vocal Tantrum", "Biting Others", "Flopping to Floor", "Elopement", "Scratching / Pinching", "Self-Injurious Hand/Arm Biting", "Throwing Materials", "Refusal / Non-Compliance" ] },
                { "id" => "b_con", "type" => "dropdown", "label" => "Consequence (C)", "required" => true, "visible" => true, "section" => "ABC Tracking", "options" => [ "Differential Reinforcement (DRA)", "Planned Ignoring / Extinction", "Physical Guidance / Redirection", "Prompt Functional Mand", "Sensory Calming Space", "Demand Pause / Work Modification" ] }
              ],
              "customSections" => [ "ABC Tracking" ],
              "deletedSections" => [],
              "history" => []
            }
          when "behavioral_assessment"
            # Behavioral Assessment: Full config with Location, Timer/Duration, Frequency, Intensity, ABC, MASS, FAST
            {
              "fields" => [
                # Incident Details
                { "id" => "b_loc", "type" => "dropdown", "label" => "Location", "required" => true, "visible" => true, "section" => "Incident Details", "options" => [ "Room 1A", "Room 1B", "Room 1C", "Room 1D", "Room 2A", "Room 2B", "Room 2C", "Room 2D", "Sensory Station", "Hallway / Transit", "Playground", "Restroom" ] },
                { "id" => "b_dur", "type" => "number", "label" => "Duration / Timer (mins)", "required" => true, "visible" => true, "section" => "Incident Details" },
                { "id" => "b_freq", "type" => "number", "label" => "Episode Frequency / Count", "required" => true, "visible" => true, "section" => "Incident Details" },
                { "id" => "b_int", "type" => "dropdown", "label" => "Behavior Severity Intensity", "required" => true, "visible" => true, "section" => "Incident Details", "options" => [ "Low", "Medium", "High" ] },

                # ABC Tracking
                { "id" => "abc_ant", "type" => "dropdown", "label" => "Antecedent Category (Trigger)", "required" => true, "visible" => true, "section" => "ABC Tracking", "options" => [ "Demand / Non-Preferred Table Task", "Transition to Station 2 / Room Change", "Denied Access to Preferred Item (e.g. iPad, Spring)", "Attention Diverted to Other Student", "Sensory Overload / Overstimulation", "Fatigue / Hunger / Biological Discomfort", "Unstructured Free Waiting Time" ] },
                { "id" => "abc_beh", "type" => "dropdown", "label" => "Primary Behavior Topography", "required" => true, "visible" => true, "section" => "ABC Tracking", "options" => [ "Screaming & Vocal Tantrum", "Biting Others (Clinician / Peer)", "Flopping to Floor & Body Stiffening", "Elopement from Seat / Room", "Scratching / Pinching Clinician", "Self-Injurious Hand/Arm Biting", "Throwing Therapy Materials", "Unable to Remain Seated at Table" ] },
                { "id" => "abc_con", "type" => "dropdown", "label" => "Structured Consequence Protocol Applied", "required" => true, "visible" => true, "section" => "ABC Tracking", "options" => [ "Differential Reinforcement of Alternative (DRA)", "Planned Ignoring / Extinction Protocol", "Physical Guidance / Neutral Redirection", "Prompt Functional Mand (Break / Toy card)", "Sensory Calming Space Transfer (Crash Pad)", "Demand Pause / Work Task Modification" ] },
                { "id" => "abc_goal", "type" => "dropdown", "label" => "Correlated Active IUP Goal Target", "required" => false, "visible" => true, "section" => "ABC Tracking", "options" => [ "Goal 1: Functional Mand for Break", "Goal 2: Remaining Seated for 10 Minutes", "Goal 3: Requesting Preferred Toy using Word", "Goal 4: Safe Hand Transition / No Aggression", "Emergent Baseline (Unassigned Target)" ] },

                # MASS Items
                { "id" => "M1", "type" => "radio", "label" => "Would the behavior occur continuously if left alone for long periods of time?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },
                { "id" => "M2", "type" => "radio", "label" => "Does the behavior occur when the person is asked to do a difficult task?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },
                { "id" => "M3", "type" => "radio", "label" => "Does the behavior seem to occur when the person is ignored?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },
                { "id" => "M4", "type" => "radio", "label" => "Does the behavior occur when a preferred item is taken away?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },
                { "id" => "M5", "type" => "radio", "label" => "Does the behavior occur when the person is left alone, with no one around?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },
                { "id" => "M6", "type" => "radio", "label" => "Does the behavior occur following a request to perform an undesirable task?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },
                { "id" => "M7", "type" => "radio", "label" => "Does the behavior occur when attention is diverted from the person?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },
                { "id" => "M8", "type" => "radio", "label" => "Does the behavior occur when the person is denied access to a desired item or activity?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },
                { "id" => "M9", "type" => "radio", "label" => "Does the behavior occur during a task that the person does not enjoy?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },
                { "id" => "M10", "type" => "radio", "label" => "Does the behavior seem to be enjoyable to the person (self-stimulatory)?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },
                { "id" => "M11", "type" => "radio", "label" => "Does the behavior occur to get a reaction from others?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },
                { "id" => "M12", "type" => "radio", "label" => "Does the behavior occur to obtain food, toys, or a specific activity?", "required" => true, "visible" => true, "section" => "MASS", "options" => [ "Never", "Almost Never", "Half the Time", "Usually", "Almost Always", "Always" ] },

                # FAST Items
                { "id" => "F1", "type" => "radio", "label" => "Does the behavior occur when others are present, and does attention follow?", "required" => true, "visible" => true, "section" => "FAST", "options" => [ "Yes", "No" ] },
                { "id" => "F2", "type" => "radio", "label" => "Does the behavior occur to avoid or escape a task, demand, or request?", "required" => true, "visible" => true, "section" => "FAST", "options" => [ "Yes", "No" ] },
                { "id" => "F3", "type" => "radio", "label" => "Does the behavior produce a rewarding sensory effect without others?", "required" => true, "visible" => true, "section" => "FAST", "options" => [ "Yes", "No" ] },
                { "id" => "F4", "type" => "radio", "label" => "Does the behavior remove an unpleasant sensation or reduce pain?", "required" => true, "visible" => true, "section" => "FAST", "options" => [ "Yes", "No" ] },
                { "id" => "F5", "type" => "radio", "label" => "Does the behavior typically happen when the person is alone or unoccupied?", "required" => true, "visible" => true, "section" => "FAST", "options" => [ "Yes", "No" ] },
                { "id" => "F6", "type" => "radio", "label" => "Does the behavior occur during transitions or when demands increase?", "required" => true, "visible" => true, "section" => "FAST", "options" => [ "Yes", "No" ] },
                { "id" => "F7", "type" => "radio", "label" => "Does an adult typically react by giving attention or talking to the person?", "required" => true, "visible" => true, "section" => "FAST", "options" => [ "Yes", "No" ] },
                { "id" => "F8", "type" => "radio", "label" => "Is the behavior reduced when a preferred item or activity is provided freely?", "required" => true, "visible" => true, "section" => "FAST", "options" => [ "Yes", "No" ] },

                # General Summary
                { "id" => "beh_summary", "type" => "textarea", "label" => "Clinical Function Hypotheses & Summary Notes", "required" => false, "visible" => true, "section" => "General" }
              ],
              "customSections" => [ "Incident Details", "ABC Tracking", "MASS", "FAST", "General" ],
              "deletedSections" => [],
              "history" => []
            }
          when "sensory"
            {
              "fields" => [
                { "id" => "SEN-001", "type" => "radio", "label" => "Tactile Responsiveness (Sensory board, water, foam, lotion)", "required" => true, "visible" => true, "section" => "Tactile", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] },
                { "id" => "SEN-002", "type" => "radio", "label" => "Response to Massage (Physical and facial expression reactions)", "required" => true, "visible" => true, "section" => "Tactile", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] },
                { "id" => "SEN-003", "type" => "radio", "label" => "Texture Exploration (Rough vs. smooth fabric discs)", "required" => true, "visible" => true, "section" => "Tactile", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] },
                { "id" => "SEN-004", "type" => "radio", "label" => "Sensory Bin Manipulation (Rice, dried beans, hydrogel beads)", "required" => true, "visible" => true, "section" => "Tactile", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] },
                { "id" => "SEN-005", "type" => "radio", "label" => "Visual Tracking of Illuminated Toys (Fiber optic, glow wand)", "required" => true, "visible" => true, "section" => "Visual & Auditory", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] },
                { "id" => "SEN-006", "type" => "radio", "label" => "Auditory Localization (Chimes, maracas, calming melodies)", "required" => true, "visible" => true, "section" => "Visual & Auditory", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] },
                { "id" => "SEN-007", "type" => "radio", "label" => "Light Box Exploration (Geometric colored transparencies)", "required" => true, "visible" => true, "section" => "Visual & Auditory", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] },
                { "id" => "SEN-008", "type" => "radio", "label" => "Bubble Play Eye Tracking & Pop Manding", "required" => true, "visible" => true, "section" => "Visual & Auditory", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] },
                { "id" => "SEN-009", "type" => "radio", "label" => "Vestibular Swing Tolerance (Slow linear swinging)", "required" => true, "visible" => true, "section" => "Proprioception & Vestibular", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] },
                { "id" => "SEN-010", "type" => "radio", "label" => "Deep Pressure Therapy (Weighted compression vest, peanut ball)", "required" => true, "visible" => true, "section" => "Proprioception & Vestibular", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] },
                { "id" => "SEN-011", "type" => "radio", "label" => "Trampoline Jumping (Proprioceptive rebound input)", "required" => true, "visible" => true, "section" => "Proprioception & Vestibular", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] },
                { "id" => "SEN-012", "type" => "radio", "label" => "Joint Compression Sequence (Clinician physical protocol)", "required" => true, "visible" => true, "section" => "Proprioception & Vestibular", "options" => [ "Independent", "Partial Physical Prompt", "Full Physical Prompt", "Not Applicable" ] }
              ],
              "customSections" => [ "Tactile", "Visual & Auditory", "Proprioception & Vestibular" ],
              "deletedSections" => [],
              "history" => []
            }
          when "preference_assessment"
            {
              "fields" => [
                { "id" => "pref_context", "type" => "dropdown", "label" => "Observation Context Setting", "required" => true, "visible" => true, "section" => "General", "options" => [ "Sensory Time (Station 2)", "Circle Time Group Instruction", "1:1 Table Task Play", "Arrival & Free Exploration", "Snack / Meal Routine" ] },
                { "id" => "pref_category", "type" => "dropdown", "label" => "Reinforcer Category Domain", "required" => true, "visible" => true, "section" => "General", "options" => [ "Visual (Tubes, Lights, Visual Timers)", "Auditory (Musical Blocks, Chimes, Singing)", "Tactile (Shaving Foam, Stretch Springs, Slime)", "Toys (Puzzles, Magnetic Apples, Shape Sorters)", "Movement (Crash Pad, Balance Ball, Swing)" ] },
                { "id" => "pref_item_name", "type" => "text", "label" => "Specific Stimulus Item Name", "required" => true, "visible" => true, "section" => "General" },
                { "id" => "pref_duration_seconds", "type" => "number", "label" => "Duration of Sustained Engagement (Seconds)", "required" => true, "visible" => true, "section" => "General" },
                { "id" => "pref_approach_frequency", "type" => "number", "label" => "Unprompted Approach / Reach Frequency Count", "required" => true, "visible" => true, "section" => "General" },
                { "id" => "pref_child_affect", "type" => "dropdown", "label" => "Observed Affect During Interaction", "required" => true, "visible" => true, "section" => "General", "options" => [ "Vocal Pleasure / Smiling / Laughter", "Calm Sustained Focus", "Indifferent / Neutral Contact", "Aversive Avoidance / Pushing Away", "Distress / Negative Vocalization" ] },
                { "id" => "pref_tier_ranking", "type" => "dropdown", "label" => "Evaluated Reinforcer Preference Tier", "required" => true, "visible" => true, "section" => "General", "options" => [ "Highest Tier (Primary Reinforcer - >80% Engagement)", "Moderate Tier (Secondary Reinforcer - 40-79% Engagement)", "Low Tier (Non-Preferred / Distractor - <40% Engagement)" ] },
                { "id" => "pref_delivery_guidelines", "type" => "textarea", "label" => "Clinical Delivery Protocol in 1:1 Therapy Trials", "required" => false, "visible" => true, "section" => "General" }
              ],
              "customSections" => [ "General", "Visual", "Auditory", "Tactile", "Toys", "Movement" ],
              "deletedSections" => [],
              "history" => []
            }
          when "social_skills"
            {
              "fields" => [
                { "id" => "soc_q1", "type" => "radio", "label" => "Initiates verbal greeting or wave to familiar teachers upon arrival", "required" => true, "visible" => true, "section" => "Social Interaction", "options" => [ "0 — Never", "1 — Sometimes", "2 — Often", "3 — Always" ] },
                { "id" => "soc_q2", "type" => "radio", "label" => "Responds to peer approach with positive affect or shared attention", "required" => true, "visible" => true, "section" => "Social Interaction", "options" => [ "0 — Never", "1 — Sometimes", "2 — Often", "3 — Always" ] },
                { "id" => "soc_q3", "type" => "radio", "label" => "Respects personal body boundary when sitting alongside peers", "required" => true, "visible" => true, "section" => "Social Interaction", "options" => [ "0 — Never", "1 — Sometimes", "2 — Often", "3 — Always" ] },
                { "id" => "soc_q4", "type" => "radio", "label" => "Uses vocal mand or communicative picture to ask adult for help", "required" => true, "visible" => true, "section" => "Communication", "options" => [ "0 — Never", "1 — Sometimes", "2 — Often", "3 — Always" ] },
                { "id" => "soc_q5", "type" => "radio", "label" => "Maintains eye contact during 1-to-1 conversational interactions (>2 secs)", "required" => true, "visible" => true, "section" => "Communication", "options" => [ "0 — Never", "1 — Sometimes", "2 — Often", "3 — Always" ] },
                { "id" => "soc_q6", "type" => "radio", "label" => "Answers simple social identity questions (What is your name? How old are you?)", "required" => true, "visible" => true, "section" => "Communication", "options" => [ "0 — Never", "1 — Sometimes", "2 — Often", "3 — Always" ] },
                { "id" => "soc_q7", "type" => "radio", "label" => "Yields preferred toy to peer when prompt timer rings without tantrum", "required" => true, "visible" => true, "section" => "Play & Leisure", "options" => [ "0 — Never", "1 — Sometimes", "2 — Often", "3 — Always" ] },
                { "id" => "soc_q8", "type" => "radio", "label" => "Participates in simple turn-taking interactive play (Rolling ball, stacking)", "required" => true, "visible" => true, "section" => "Play & Leisure", "options" => [ "0 — Never", "1 — Sometimes", "2 — Often", "3 — Always" ] },
                { "id" => "soc_q9", "type" => "radio", "label" => "Discriminates happy vs. angry facial expressions on picture cards", "required" => true, "visible" => true, "section" => "General", "options" => [ "0 — Never", "1 — Sometimes", "2 — Often", "3 — Always" ] },
                { "id" => "soc_q10", "type" => "radio", "label" => "Stops and freezes immediately upon hearing safety 'STOP' verbal cue", "required" => true, "visible" => true, "section" => "General", "options" => [ "0 — Never", "1 — Sometimes", "2 — Often", "3 — Always" ] }
              ],
              "customSections" => [ "Social Interaction", "Communication", "Play & Leisure", "General" ],
              "deletedSections" => [],
              "history" => []
            }
          else # ablls
            {
              "fields" => [
                { "id" => "A1", "type" => "radio", "label" => "A1: Matches identical objects", "required" => true, "visible" => true, "section" => "Visual Performance", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Mastered", "N/A" ] },
                { "id" => "A2", "type" => "radio", "label" => "A2: Matches identical pictures to objects", "required" => true, "visible" => true, "section" => "Visual Performance", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Mastered", "N/A" ] },
                { "id" => "B1", "type" => "radio", "label" => "B1: Gross motor imitation", "required" => true, "visible" => true, "section" => "Motor Imitation", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Mastered", "N/A" ] },
                { "id" => "C1", "type" => "radio", "label" => "C1: Imitation of vowel sounds", "required" => true, "visible" => true, "section" => "Vocal Imitation", "options" => [ "0 — Not Demonstrated", "1 — Emerging", "2 — Mastered", "N/A" ] }
              ],
              "customSections" => [ "Visual Performance", "Motor Imitation", "Vocal Imitation" ],
              "deletedSections" => [],
              "history" => []
            }
          end
        end
        end
      end
    end
  end
end
