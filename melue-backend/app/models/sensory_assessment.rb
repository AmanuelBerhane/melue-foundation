class SensoryAssessment < ApplicationRecord
  belongs_to :student
  has_many :sensory_assessment_records, dependent: :destroy

  accepts_nested_attributes_for :sensory_assessment_records, allow_destroy: true

  validates :status, inclusion: { in: %w[draft complete] }

  def summary
    {
      engagement_levels: sensory_assessment_records.group(:engagement_level).count,
      response_reactions: sensory_assessment_records.group(:response_reaction).count
    }
  end

  def submit!
    update!(status: "complete")
    # FR-050: Logic to mark student as "Assessment Complete" could be triggered here or in an observer/callback
    # if all three assessments are complete. Since we don't have the other two here, we can leave a hook.
    check_overall_assessment_completion
    true
  end

  private

  def check_overall_assessment_completion
    # TODO: Check if ABLLS and Behavior assessments are also complete
    # If so: student.update!(status: 'Assessment Complete')
  end
end
