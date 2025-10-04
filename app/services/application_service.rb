class ApplicationService
  def self.call(*args, **kwargs, &block)
    new(*args, **kwargs, &block).call
  end

  private

  def success(value = nil, metadata: {})
    ServiceResult.success(value, metadata: metadata)
  end

  def failure(error = nil, metadata: {})
    ServiceResult.failure(error, metadata: metadata)
  end
end
