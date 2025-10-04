class ServiceResult
  attr_reader :value, :error, :metadata

  def self.success(value = nil, metadata: {})
    new(success: true, value: value, metadata: metadata)
  end

  def self.failure(error = nil, metadata: {})
    new(success: false, error: error, metadata: metadata)
  end

  def initialize(success:, value: nil, error: nil, metadata: {})
    @success = success
    @value = value
    @error = error
    @metadata = metadata
  end

  def success?
    @success
  end

  def failure?
    !success?
  end

  def value!
    raise error || StandardError, "ServiceResult is a failure" if failure?

    value
  end

  def error!
    raise error || StandardError, "ServiceResult is a success" if success?

    error
  end

  def with_metadata(additional_metadata)
    self.class.new(
      success: success?,
      value: value,
      error: error,
      metadata: metadata.merge(additional_metadata)
    )
  end
end
