# frozen_string_literal: true

module Api
  module V1
    module Sysadmin
      class StaffController < Api::V1::BaseController
        before_action :authenticate_user!
        before_action :require_system_admin, except: %i[index show]
        before_action :set_staff_and_user, only: %i[show update update_status reset_password destroy]

        # GET /api/v1/sysadmin/staff
        def index
          staff_scope = StaffMember.includes(user: :roles).where(discarded_at: nil)

          # Also gather any users who might not have a staff_member record yet (e.g. system admins)
          users_with_staff = staff_scope.map(&:user_id).compact
          orphan_users = User.where.not(id: users_with_staff).includes(:roles)

          results = []

          staff_scope.each do |sm|
            user = sm.user
            next unless user

            results << serialize_staff(sm, user)
          end

          orphan_users.each do |user|
            results << serialize_user_as_staff(user)
          end

          # Filter by search
          if params[:search].present?
            q = params[:search].to_s.strip.downcase
            results = results.select do |s|
              s[:name].to_s.downcase.include?(q) || s[:email].to_s.downcase.include?(q)
            end
          end

          # Filter by role
          if params[:role].present? && params[:role] != "All"
            req_role = params[:role].to_s
            results = results.select do |s|
              s[:roles].include?(req_role)
            end
          end

          # Filter by status
          if params[:status].present? && params[:status] != "All"
            is_active = params[:status] == "Active"
            results = results.select do |s|
              s[:active] == is_active
            end
          end

          render json: results
        end

        # GET /api/v1/sysadmin/staff/:id
        def show
          render json: serialize_staff(@staff_member, @user)
        end

        # POST /api/v1/sysadmin/staff
        def create
          email = params[:email].to_s.strip.downcase
          if email.blank?
            return render json: { error: "Email is required" }, status: :unprocessable_entity
          end

          if User.exists?(email: email)
            return render json: { error: "A user with email #{email} already exists." }, status: :unprocessable_entity
          end

          password = params[:password].to_s.strip
          if password.blank?
            return render json: { error: "Password is required" }, status: :unprocessable_entity
          end

          name = params[:name].to_s.strip
          if name.blank?
            return render json: { error: "Full name is required" }, status: :unprocessable_entity
          end

          roles = Array(params[:roles]).presence || [ "Teacher" ]
          primary_ui_role = roles.first

          is_active = params[:active] != false

          ActiveRecord::Base.transaction do
            user = User.new(
              email: email,
              status: is_active ? :verified : :closed,
              password_hash: BCrypt::Password.create(password)
            )

            user.role = case primary_ui_role
            when "System Admin" then :system_admin
            when "Institutional Admin" then :institutional_admin
            when "Teacher" then :therapist
            else :clinical_staff
            end

            user.save!

            # Assign roles
            roles.each do |r_name|
              canonical = canonical_role_name(r_name)
              role_record = Role.find_by(name: canonical)
              user.assign_role(role_record) if role_record
            end

            staff_role = case primary_ui_role
            when "Teacher" then "teacher"
            when "Coordinator" then "therapy_coordinator"
            when "Program Director", "Director" then "program_director"
            else "admin"
            end

            staff_num = "STF-#{SecureRandom.hex(3).upcase}"

            staff = StaffMember.create!(
              user: user,
              full_name: name,
              staff_number: staff_num,
              role: staff_role
            )

            render json: serialize_staff(staff, user), status: :created
          end
        rescue ActiveRecord::RecordInvalid => e
          render json: { error: e.message }, status: :unprocessable_entity
        end

        # PATCH /api/v1/sysadmin/staff/:id
        def update
          name = params[:name].to_s.strip if params[:name].present?
          email = params[:email].to_s.strip.downcase if params[:email].present?
          password = params[:password].to_s.strip if params[:password].present?
          roles = params[:roles] if params.key?(:roles)
          active = params[:active] if params.key?(:active)

          ActiveRecord::Base.transaction do
            if @staff_member && name
              @staff_member.update!(full_name: name)
            end

            if @user
              attrs = {}
              attrs[:email] = email if email.present?
              attrs[:password_hash] = BCrypt::Password.create(password) if password.present?
              attrs[:status] = active ? :verified : :closed if active != nil
              @user.update!(attrs) if attrs.any?

              if roles.is_a?(Array) && roles.any?
                # Revoke active roles not in new list
                canonical_roles = roles.map { |r| canonical_role_name(r) }
                @user.role_assignments.active.each do |ra|
                  ra.revoke! unless canonical_roles.include?(ra.role.name)
                end
                # Assign new ones
                canonical_roles.each do |c_name|
                  r = Role.find_by(name: c_name)
                  @user.assign_role(r) if r
                end
              end
            end

            render json: serialize_staff(@staff_member, @user)
          end
        rescue ActiveRecord::RecordInvalid => e
          render json: { error: e.message }, status: :unprocessable_entity
        end

        # POST /api/v1/sysadmin/staff/:id/status
        def update_status
          active = params[:active] == true || params[:status] == "active"
          if @user
            @user.update!(status: active ? :verified : :closed)
          end
          render json: { status: "ok", active: active }
        end

        # POST /api/v1/sysadmin/staff/:id/reset-password
        def reset_password
          new_pw = params[:newPassword].to_s.strip.presence || "Password123!"
          if @user
            @user.update!(password_hash: BCrypt::Password.create(new_pw))
          end
          render json: { status: "ok", password: new_pw }
        end

        # DELETE /api/v1/sysadmin/staff/:id
        def destroy
          if @staff_member
            @staff_member.discard if @staff_member.respond_to?(:discard)
            @staff_member.destroy unless @staff_member.discarded?
          end
          if @user
            @user.destroy
          end
          render json: { deleted: true }
        end

        # POST /api/v1/sysadmin/staff/bulk
        def bulk
          staff_ids = Array(params[:staffIds])
          action = params[:action].to_s.downcase

          staff_ids.each do |sid|
            staff = StaffMember.find_by(id: sid)
            user = staff&.user || User.find_by(id: sid)
            next unless user

            if action.include?("deact")
              user.update(status: :closed)
            elsif action.include?("act")
              user.update(status: :verified)
            elsif action.include?("del")
              staff&.destroy
              user.destroy
            end
          end

          render json: { status: "ok" }
        end

        private

        def set_staff_and_user
          @staff_member = StaffMember.find_by(id: params[:id])
          @user = @staff_member&.user || User.find_by(id: params[:id])

          unless @user || @staff_member
            render json: { error: "Staff member not found" }, status: :not_found
          end
        end

        def serialize_staff(sm, user)
          roles = user ? map_user_roles(user) : [ "Teacher" ]
          is_active = user ? (user.status == "verified" || user.status_before_type_cast == 2) : true

          {
            id: sm ? sm.id.to_s : user.id.to_s,
            name: sm&.full_name.presence || user&.email&.split("@")&.first&.titleize || "Staff Member",
            email: user&.email || "",
            phone: "",
            roles: roles,
            active: is_active
          }
        end

        def serialize_user_as_staff(user)
          roles = map_user_roles(user)
          is_active = user.status == "verified" || user.status_before_type_cast == 2

          {
            id: user.id.to_s,
            name: user.email.split("@").first.titleize,
            email: user.email,
            phone: "",
            roles: roles,
            active: is_active
          }
        end

        def map_user_roles(user)
          names = user.active_roles.map(&:name)
          if names.empty? && user.role.present?
            names = [ user.role.to_s.titleize ]
          end

          names.map do |n|
            case n
            when Role::Names::TEACHER, "Teacher", "therapist" then "Teacher"
            when Role::Names::THERAPY_COORDINATOR, "Therapy Coordinator", "coordinator" then "Coordinator"
            when Role::Names::PROGRAM_DIRECTOR, "Program Director" then "Program Director"
            when Role::Names::DIRECTOR, "Director" then "Director"
            when Role::Names::INSTITUTIONAL_ADMIN, "Institutional Administrator", "Institutional Admin", "institutional_admin" then "Institutional Admin"
            when Role::Names::SYSTEM_ADMIN, "System Administrator", "System Admin", "system_admin" then "System Admin"
            else n
            end
          end.uniq
        end

        def canonical_role_name(ui_role)
          case ui_role
          when "Teacher" then Role::Names::TEACHER
          when "Coordinator" then Role::Names::THERAPY_COORDINATOR
          when "Program Director" then Role::Names::PROGRAM_DIRECTOR
          when "Director" then Role::Names::DIRECTOR
          when "Institutional Admin" then Role::Names::INSTITUTIONAL_ADMIN
          when "System Admin" then Role::Names::SYSTEM_ADMIN
          else ui_role
          end
        end

        def require_system_admin
          return if current_user&.has_role?(:system_admin) ||
                    current_user&.has_role?("system_admin") ||
                    current_user&.has_role?(Role::Names::SYSTEM_ADMIN) ||
                    current_user&.has_role?(:institutional_admin) ||
                    current_user&.has_role?(Role::Names::INSTITUTIONAL_ADMIN)

          render json: { error: "Forbidden: Administrator access required" }, status: :forbidden
        end
      end
    end
  end
end
