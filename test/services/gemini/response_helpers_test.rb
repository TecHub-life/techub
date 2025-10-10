require "test_helper"

class DummyIncludingClass
  include Gemini::ResponseHelpers
end

class ResponseHelpersTest < ActiveSupport::TestCase
  def setup
    @helper = DummyIncludingClass.new
  end

  test "dig_value handles symbol and string keys" do
    source = { "a" => 1, b: 2 }
    assert_equal 1, @helper.dig_value(source, :a)
    assert_equal 2, @helper.dig_value(source, "b")
    assert_nil @helper.dig_value(nil, :x)
  end

  test "normalize_to_hash accepts hash and JSON string" do
    h = { "k" => "v" }
    assert_equal h, @helper.normalize_to_hash(h)
    assert_equal h, @helper.normalize_to_hash('{"k":"v"}')
    assert_nil @helper.normalize_to_hash("not json")
  end

  test "parse_relaxed_json handles trailing commas and fenced blocks" do
    with_trailing = "{\n  \"a\": 1,\n}"
    parsed = @helper.parse_relaxed_json(with_trailing)
    assert_equal 1, parsed["a"]

    fenced = "```json\n{\n  \"a\": 2\n}\n```"
    parsed2 = @helper.parse_relaxed_json(fenced)
    assert_equal 2, parsed2["a"]

    assert_nil @helper.parse_relaxed_json("")
  end
end
