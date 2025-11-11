# frozen_string_literal: true

require "test_helper"

class OpsAxiomAdminServiceTest < ActiveSupport::TestCase
  test "coerce_duration_param handles days suffix" do
    assert_equal "168h", Ops::AxiomAdminService.coerce_duration_param("7d")
  end

  test "coerce_duration_param passes through explicit unit" do
    assert_equal "12h", Ops::AxiomAdminService.coerce_duration_param("12h")
  end

  test "coerce_duration_param handles plain integer as hours" do
    assert_equal "24h", Ops::AxiomAdminService.coerce_duration_param("24")
  end

  test "coerce_duration_param returns nil on invalid input" do
    assert_nil Ops::AxiomAdminService.coerce_duration_param("foo")
  end
end
