# frozen_string_literal: true

require "test_helper"

class AxiomAdminClientTest < ActiveSupport::TestCase
  class FakeResponse < Struct.new(:body); end

  class FakeConnection
    Request = Struct.new(:method, :path, :headers, :body) do
      def url(value)
        self.path = value
      end
    end

    attr_reader :requests

    def initialize(responses)
      @responses = responses
      @requests = []
    end

    def get(&block)
      dispatch(:get, &block)
    end

    def post(&block)
      dispatch(:post, &block)
    end

    def delete(&block)
      dispatch(:delete, &block)
    end

    def put(&block)
      dispatch(:put, &block)
    end

    private

    def dispatch(method)
      request = Request.new(method, nil, {}, nil)
      yield(request) if block_given?
      key = [ method, request.path ]
      response = @responses.fetch(key) { raise "No stub for #{method} #{request.path}" }
      response = response.shift if response.is_a?(Array)
      @requests << request
      response
    end
  end

  test "list_fields unwraps payload arrays" do
    payload = { "data" => [ { "name" => "alpha" }, { "name" => "beta" } ] }.to_json
    connection = FakeConnection.new([ :get, "/v2/datasets/otel-logs/fields" ] => FakeResponse.new(payload))

    client = Axiom::AdminClient.new(token: "secret", base_url: "https://api.example", connection: connection)
    result = client.list_fields(dataset: "otel-logs")

    assert_equal 2, result.size
    assert_equal "alpha", result.first["name"]
    assert_equal "/v2/datasets/otel-logs/fields", connection.requests.first.path
  end

  test "create_map_field posts payload JSON" do
    response_body = { "name" => "attributes.custom", "status" => "mapped" }.to_json
    connection = FakeConnection.new([ :post, "/v2/datasets/otel-logs/mapfields" ] => FakeResponse.new(response_body))

    client = Axiom::AdminClient.new(token: "master", base_url: "https://api.example", connection: connection)
    result = client.create_map_field(dataset: "otel-logs", name: "attributes.custom")

    assert_equal "attributes.custom", result["name"]
    request = connection.requests.last
    assert_equal "/v2/datasets/otel-logs/mapfields", request.path
    assert_equal({ "name" => "attributes.custom" }, JSON.parse(request.body))
  end

  test "raises when token missing" do
    assert_raises(ArgumentError) do
      Axiom::AdminClient.new(token: nil)
    end
  end

  test "trim_dataset posts duration payload" do
    connection = FakeConnection.new([ :post, "/v2/datasets/otel-logs/trim" ] => FakeResponse.new(""))

    client = Axiom::AdminClient.new(token: "master", base_url: "https://api.example", connection: connection)
    assert client.trim_dataset(dataset: "otel-logs", max_duration: "168h")

    request = connection.requests.last
    assert_equal :post, request.method
    assert_equal "/v2/datasets/otel-logs/trim", request.path
    assert_equal({ "maxDuration" => "168h" }, JSON.parse(request.body))
  end

  test "list_datasets returns raw array" do
    payload = [ { "name" => "otel-logs" }, { "name" => "otel-traces" } ].to_json
    connection = FakeConnection.new([ :get, "/v2/datasets" ] => FakeResponse.new(payload))

    client = Axiom::AdminClient.new(token: "secret", base_url: "https://api.example", connection: connection)
    list = client.datasets

    assert_equal 2, list.size
    assert_equal "otel-logs", list.first["name"]
  end
end
