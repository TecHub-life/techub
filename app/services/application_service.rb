class ApplicationService
  def self.call(*args, **kwargs, &block)
    new(*args, **kwargs).call(&block)
  end

  private

  def success(value = nil, metadata: {})
    log_service(:ok, metadata: metadata)
    ServiceResult.success(value, metadata: safe_metadata(metadata), status: :ok)
  end

  def degraded(value = nil, metadata: {})
    log_service(:degraded, metadata: metadata)
    ServiceResult.degraded(value, metadata: safe_metadata(metadata))
  end

  def failure(error = nil, metadata: {})
    log_service(:failed, error: error, metadata: metadata)
    ServiceResult.failure(error, metadata: safe_metadata(metadata))
  end

  def log_service(status, error: nil, metadata: {})
    payload = {
      service: self.class.name,
      status: status,
      error: extract_error_message(error),
      error_class: extract_error_class(error)
    }
    level = case status
            when :failed then :error
            when :degraded then :warn
            else :info
            end
    safe = safe_metadata(metadata)
    safe = {} unless safe.is_a?(Hash)
    StructuredLogger.public_send(
      level,
      payload.merge(safe),
      component: "service",
      event: "service.#{self.class.name}",
      ops_details: safe.merge(status: status)
    )
  end

  def extract_error_message(error)
    return nil if error.nil?
    return error.message if error.respond_to?(:message)
    error.to_s
  end

  def extract_error_class(error)
    return nil if error.nil?
    (error.respond_to?(:class) && error.class) ? error.class.name : nil
  end

  def safe_metadata(metadata)
    return {} if metadata.nil?
    return sanitize_hash(metadata) if metadata.is_a?(Hash)

    { value: metadata }
  rescue StandardError
    {}
  end

  def sanitize_hash(hash)
    sanitized = hash.each_with_object({}) do |(key, value), memo|
      next if value.nil?
      memo[key] = value
    end
    sanitized.empty? ? {} : sanitized
  end
end
