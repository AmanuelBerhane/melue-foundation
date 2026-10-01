# frozen_string_literal: true

module Api
  module V1
    module Admin
      class AbcListsController < BaseController
        before_action :authenticate_user!

        # GET /api/v1/admin/abc-lists
        def index
          options = AbcDropdownOption.all.order(:display_order)

          behaviors = options.select(&:behavior?).map(&method(:serialize_item))
          antecedents = options.select(&:antecedent?).map(&method(:serialize_item))
          consequences = options.select(&:consequence?).map(&method(:serialize_item))

          if behaviors.empty?
            seed_defaults!
            options = AbcDropdownOption.all.order(:display_order)
            behaviors = options.select(&:behavior?).map(&method(:serialize_item))
            antecedents = options.select(&:antecedent?).map(&method(:serialize_item))
            consequences = options.select(&:consequence?).map(&method(:serialize_item))
          end

          locations = [
            { id: "loc-1", name: "Classroom", status: "Active" },
            { id: "loc-2", name: "Playground", status: "Active" },
            { id: "loc-3", name: "Sensory Room", status: "Active" },
            { id: "loc-4", name: "Cafeteria", status: "Active" }
          ]

          render json: {
            behaviors: behaviors,
            antecedents: antecedents,
            consequences: consequences,
            locations: locations
          }
        end

        # POST /api/v1/admin/abc-lists/:list_type
        def update_list
          list_type = params[:list_type].to_s.downcase
          category = case list_type
                     when /behavior/ then :behavior
                     when /antecedent/ then :antecedent
                     when /consequence/ then :consequence
                     else nil
          end

          items = params[:items] || []

          if category
            items.each_with_index do |item, idx|
              label = item[:name] || item[:label]
              next if label.blank?

              opt = AbcDropdownOption.find_or_initialize_by(category: category, label: label)
              opt.display_order = idx
              opt.is_active = (item[:status].to_s.downcase != "inactive")
              opt.save!
            end
          end

          render json: { success: true }
        end

        # POST /api/v1/admin/abc-lists/reset
        def reset
          seed_defaults!(force: true)
          render json: { success: true }
        end

        private

        def serialize_item(opt)
          {
            id: opt.id.to_s,
            name: opt.label,
            label: opt.label,
            status: opt.is_active ? "Active" : "Inactive",
            category: "General",
            definition: opt.is_other ? "Other specified behavior" : opt.label
          }
        end

        def seed_defaults!(force: false)
          AbcDropdownOption.destroy_all if force

          defaults = {
            behavior: ["Self-Injurious Behavior", "Aggression", "Elopement", "Flopping", "Vocal Outburst", "Property Destruction", "Non-Compliance", "Other"],
            antecedent: ["Transition Demand", "Task Demand", "Denied Access to Item", "Peer Interaction", "Loud Noise / Sensory", "Change in Routine", "Attention Shift", "Other"],
            consequence: ["Verbal Redirection", "Visual Prompt Given", "Short Break Allowed", "Item Delivered", "Demand Repeated", "Ignored / Extinction", "Differential Reinforcement", "Other"]
          }

          defaults.each do |cat, list|
            list.each_with_index do |lbl, idx|
              AbcDropdownOption.find_or_create_by!(category: cat, label: lbl) do |o|
                o.display_order = idx
                o.is_active = true
                o.is_other = (lbl == "Other")
              end
            end
          end
        end
      end
    end
  end
end
