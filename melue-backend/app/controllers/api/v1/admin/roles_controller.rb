class Api::V1::Admin::RolesController < Api::V1::BaseController
  before_action :set_role, only: %i[show update destroy]
  before_action -> { authorize!("roles", action_name) }

  # @oas_include
  # @summary List all roles
  # @tags Admin - Roles
  # @auth [bearer_jwt]
  # @response Success (200) [Array<Hash{id: String, name: String, is_system_critical: Boolean, description: String, permissions: Array<Hash>}>]
  def index
    roles = Role.includes(:permissions).all
    render json: roles.as_json(include: :permissions)
  end

  # @oas_include
  # @summary Get a specific role
  # @tags Admin - Roles
  # @auth [bearer_jwt]
  # @parameter id(path) [!String] Role ID
  # @response Success (200) [Hash{id: String, name: String, is_system_critical: Boolean, description: String, permissions: Array<Hash>}]
  def show
    render json: @role.as_json(include: :permissions)
  end

  # @oas_include
  # @summary Create a new custom role
  # @tags Admin - Roles
  # @auth [bearer_jwt]
  # @request_body Role data [!Hash{name: String, description: String, permission_ids: Array<String>}]
  # @response Created (201) [Hash]
  # @response Unprocessable Entity (422) [Hash]
  def create
    @role = Role.new(role_params)
    @role.is_system_critical = false # Custom roles are never critical

    if @role.save
      update_role_permissions if params[:permission_ids].present?
      render json: @role.as_json(include: :permissions), status: :created
    else
      render json: { errors: @role.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # @oas_include
  # @summary Update a role and its permissions
  # @tags Admin - Roles
  # @auth [bearer_jwt]
  # @parameter id(path) [!String] Role ID
  # @request_body Role data [!Hash{name: String, description: String, permission_ids: Array<String>}]
  # @response Success (200) [Hash]
  # @response Unprocessable Entity (422) [Hash]
  def update
    if @role.update(role_params)
      update_role_permissions if params.key?(:permission_ids)
      render json: @role.as_json(include: :permissions)
    else
      render json: { errors: @role.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # @oas_include
  # @summary Delete a custom role
  # @tags Admin - Roles
  # @auth [bearer_jwt]
  # @parameter id(path) [!String] Role ID
  # @response No Content (204) []
  # @response Unprocessable Entity (422) [Hash]
  def destroy
    if @role.destroy
      head :no_content
    else
      render json: { errors: @role.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_role
    @role = Role.find(params[:id])
  end

  def role_params
    params.permit(:name, :description)
  end

  def update_role_permissions
    @role.permissions = Permission.where(id: params[:permission_ids])
  end
end
