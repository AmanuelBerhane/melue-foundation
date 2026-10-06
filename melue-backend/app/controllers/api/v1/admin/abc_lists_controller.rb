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
          locations = options.select(&:location?).map(&method(:serialize_item))

          if behaviors.empty? || locations.empty?
            seed_defaults!
            options = AbcDropdownOption.all.order(:display_order)
            behaviors = options.select(&:behavior?).map(&method(:serialize_item))
            antecedents = options.select(&:antecedent?).map(&method(:serialize_item))
            consequences = options.select(&:consequence?).map(&method(:serialize_item))
            locations = options.select(&:location?).map(&method(:serialize_item))
          end

          render json: {
            behaviors: behaviors,
            antecedents: antecedents,
            consequences: consequences,
            locations: locations,
            Behaviors: behaviors,
            Antecedents: antecedents,
            Consequences: consequences,
            Locations: locations
          }
        end

        # POST /api/v1/admin/abc-lists/:list_type
        def update_list
          list_type = params[:list_type].to_s.downcase
          category = case list_type
          when /behavior/ then :behavior
          when /antecedent/ then :antecedent
          when /consequence/ then :consequence
          when /location/ then :location
          else nil
          end

          items = params[:items] || []

          if category
            ActiveRecord::Base.transaction do
              items.each_with_index do |item, idx|
                label = item[:name] || item[:label]
                next if label.blank?

                is_other_val = if item.key?(:is_other)
                  ActiveModel::Type::Boolean.new.cast(item[:is_other])
                elsif item.key?(:isOther)
                  ActiveModel::Type::Boolean.new.cast(item[:isOther])
                else
                  label.to_s.strip.casecmp("other").zero?
                end

                opt = nil
                if item[:id].present? && item[:id].to_s !~ /\A(?:loc-|l|c|a|b|\d{10,})/
                  opt = AbcDropdownOption.find_by(category: category, id: item[:id])
                end
                opt ||= AbcDropdownOption.find_or_initialize_by(category: category, label: label)

                opt.label = label
                opt.display_order = idx
                opt.is_active = (item[:status].to_s.downcase != "inactive" && item[:active] != false)

                if is_other_val
                  AbcDropdownOption.where(category: category, is_other: true).where.not(id: opt.id).update_all(is_other: false)
                end
                opt.is_other = is_other_val
                opt.save!
              end
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
            active: opt.is_active,
            category: "General",
            definition: opt.is_other ? "Other specified #{opt.category}" : opt.label,
            is_other: opt.is_other,
            isOther: opt.is_other
          }
        end

        def seed_defaults!(force: false)
          AbcDropdownOption.destroy_all if force

          defaults = {
            behavior: [ "Self-Injurious Behavior", "Aggression", "Elopement", "Flopping", "Vocal Outburst", "Property Destruction", "Non-Compliance", "Other" ],
            antecedent: [ "Transition Demand", "Task Demand", "Denied Access to Item", "Peer Interaction", "Loud Noise / Sensory", "Change in Routine", "Attention Shift", "Other" ],
            consequence: [ "Verbal Redirection", "Visual Prompt Given", "Short Break Allowed", "Item Delivered", "Demand Repeated", "Ignored / Extinction", "Differential Reinforcement", "Other" ],
            location: [ "Classroom", "Playground", "Sensory Room", "Cafeteria", "Other" ]
          }

          defaults.each do |cat, list|
            next if !force && AbcDropdownOption.where(category: cat).exists?

            list.each_with_index do |lbl, idx|
              has_other = AbcDropdownOption.where(category: cat, is_other: true).exists?
              is_other_flag = (lbl == "Other") && !has_other

              AbcDropdownOption.find_or_create_by(category: cat, label: lbl) do |o|
                o.display_order = idx
                o.is_active = true
                o.is_other = is_other_flag
              end
            end
          end
        end
      end
    end
  end
end
