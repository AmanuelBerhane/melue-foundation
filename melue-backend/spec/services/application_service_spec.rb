require "rails_helper"

RSpec.describe ApplicationService do
  let(:dummy_service) do
    Class.new(ApplicationService) do
      def initialize(should_succeed:)
        @should_succeed = should_succeed
      end

      def call
        if @should_succeed
          success("Operation succeeded")
        else
          failure("Operation failed")
        end
      end
    end
  end

  it "returns a successful ServiceResult when operation succeeds" do
    result = dummy_service.call(should_succeed: true)

    expect(result).to be_success
    expect(result).not_to be_failure
    expect(result.data).to eq("Operation succeeded")
    expect(result.error).to be_nil
  end

  it "returns a failed ServiceResult when operation fails" do
    result = dummy_service.call(should_succeed: false)

    expect(result).to be_failure
    expect(result).not_to be_success
    expect(result.error).to eq("Operation failed")
    expect(result.data).to be_nil
  end

  it "raises NotImplementedError if #call is not implemented" do
    expect { ApplicationService.call }.to raise_error(NotImplementedError)
  end
end
