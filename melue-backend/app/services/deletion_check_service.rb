class DeletionCheckService < ApplicationService
  def initialize(resource)
    @resource = resource
  end

  def call
    case @resource
    when GoalDomain
      check_goals
    when PromptLevel
      check_trials
    when SessionBlockDefinition
      check_sessions
    else
      success
    end
  end

  private

  def check_goals
    count = @resource.goals.count
    return success if count.zero?
    failure("Cannot delete domain with #{count} existing goals")
  end

  def check_trials
    count = @resource.trials.count
    return success if count.zero?
    failure("Cannot delete prompt level with #{count} existing trials")
  end

  def check_sessions
    count = @resource.therapy_sessions.count
    return success if count.zero?
    failure("Cannot delete session block with #{count} existing sessions")
  end
end
