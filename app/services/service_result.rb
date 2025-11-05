class ServiceResult
  attr_reader :value, :error, :metadata, :status

  def self.success(value = nil, metadata: {}, status: :ok)
    new(success: true, value: value, metadata: metadata, status: status)
  end

  def self.degraded(value = nil, metadata: {})
    new(success: true, value: value, metadata: metadata, status: :degraded)
  end

  def self.failure(error = nil, metadata: {}, status: :failed)
    new(success: false, error: error, metadata: metadata, status: status)
  end

  def initialize(success:, value: nil, error: nil, metadata: {}, status: nil)
    @success = success
    @value = value
    @error = error
    @metadata = metadata || {}
    @status = status || default_status(success)
  end

  def success?
    @success
  end

  def failure?
    !success?
  end

  def degraded?
    status == :degraded
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
      metadata: metadata.merge(additional_metadata || {}),
      status: status
    )
  end

  private

  def default_status(success)
    success ? :ok : :failed
  end
end
