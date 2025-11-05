module Profiles
  module Pipeline
    module Stages
      class BaseStage < ApplicationService
        def initialize(context:, **options)
          @context = context
          @options = options
        end

        private

        attr_reader :context, :options

        def login
          context.login
        end

        def host
          context.host
        end

        def stage_id
          self.class::STAGE_ID
        end

        def trace(event, payload = {})
          context.trace(stage_id, event, payload)
        end

        def success_with_context(value = nil, metadata: {})
          success(value, metadata: metadata.merge(stage: stage_id))
        end

        def degraded_with_context(value = nil, metadata: {})
          degraded(value, metadata: metadata.merge(stage: stage_id))
        end

        def failure_with_context(error, metadata: {})
          failure(error, metadata: metadata.merge(stage: stage_id))
        end

        def safe_metadata(result)
          result.respond_to?(:metadata) ? result.metadata : nil
        end
      end
    end
  end
end
