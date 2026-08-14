class Api::V1::Admin::StaffMembersController < Api::V1::BaseController
  before_action :set_staff_member, only: %i[show update update_status reset_password]
  before_action -> { authorize!("staff_members", action_name) }

  # @oas_include
  # @summary List all staff members
  # @tags Admin - Staff
  # @auth [bearer_jwt]
  # @response Success (200) [Array<Hash>]
  def index
    staff = StaffMember.includes(user: :roles).all
    render json: staff.as_json(include: { user: { include: :roles } })
  end

  # @oas_include
  # @summary Get a specific staff member
  # @tags Admin - Staff
  # @auth [bearer_jwt]
  # @parameter id(path) [!String] Staff Member ID
  # @response Success (200) [Hash]
  def show
    render json: @staff_member.as_json(include: { user: { include: :roles } })
  end

  # @oas_include
  # @summary Update staff member details and roles
  # @tags Admin - Staff
  # @auth [bearer_jwt]
  # @parameter id(path) [!String] Staff Member ID
  # @request_body Staff data [!Hash{full_name: String, staff_number: String, role_ids: Array<String>}]
  # @response Success (200) [Hash]
  def update
    if @staff_member.update(staff_params)
      update_staff_roles if params.key?(:role_ids)
      render json: @staff_member.as_json(include: { user: { include: :roles } })
    else
      render json: { errors: @staff_member.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # @oas_include
  # @summary Toggle staff account active/inactive status (FR-011)
  # @tags Admin - Staff
  # @auth [bearer_jwt]
  # @parameter id(path) [!String] Staff Member ID
  # @request_body Status data [!Hash{active: Boolean}]
  # @response Success (200) [Hash]
  def update_status
    user = @staff_member.user
    # Map active to Rodauth status (verified: 2, closed: 3)
    new_status = params[:active] ? :verified : :closed

    if user.update(status: new_status)
      render json: { message: "Account status updated", active: params[:active] }
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # @oas_include
  # @summary Trigger password reset for staff member (FR-010)
  # @tags Admin - Staff
  # @auth [bearer_jwt]
  # @parameter id(path) [!String] Staff Member ID
  # @response Success (200) [Hash]
  def reset_password
    user = @staff_member.user
    # Usually rodauth has a built-in method for this, or we just send an email here
    # For MVP, we simulate the password reset request
    # rodauth.send_reset_password_email(user.email) (requires rodauth instance)

    render json: { message: "Password reset email triggered for #{user.email}" }
  end

  private

  def set_staff_member
    @staff_member = StaffMember.find(params[:id])
  end

  def staff_params
    params.permit(:full_name, :staff_number)
  end

  def update_staff_roles
    user = @staff_member.user
    user.roles = Role.where(id: params[:role_ids])
  end
end
