module Images
  class OptimizeJob < ApplicationJob
    queue_as :images

    retry_on StandardError, wait: ->(executions) { (executions**2).seconds }, attempts: 3

    def perform(path:, format: nil, quality: nil)
      Images::OptimizeService.call(path: path, output_path: path, format: format, quality: quality)
    end
  end
end
