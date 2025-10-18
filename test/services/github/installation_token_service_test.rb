require "test_helper"

module Github
  class InstallationTokenServiceTest < ActiveSupport::TestCase
    test "service removed" do
      result = Github::InstallationTokenService.call
      assert result.failure?
    end
  end
end
