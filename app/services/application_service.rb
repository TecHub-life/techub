class ApplicationService
  def self.call(*args, **kwargs, &block)
    new(*args, **kwargs).call(&block)
  end

  private

  def success(value = nil, metadata: {})
    log_service(:success, metadata: metadata)
    ServiceResult.success(value, metadata: metadata)
  end

  def failure(error = nil, metadata: {})
    log_service(:failure, error: error, metadata: metadata)
    ServiceResult.failure(error, metadata: metadata)
  end

  def log_service(status, error: nil, metadata: {})
    payload = {
      service: self.class.name,
      status: status,
      error: extract_error_message(error),
      error_class: extract_error_class(error)
    }
    if status == :failure
      StructuredLogger.error(payload.merge(metadata))
    else
      StructuredLogger.info(payload.merge(metadata))
    end
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
end
