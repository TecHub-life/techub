module Profiles
  module Pipeline
    module Stages
      class PersistGithubProfile < BaseStage
        STAGE_ID = :store_github_profile

        def call
          payload = context.github_payload
          unless payload.present? && payload[:profile].present?
            return failure_with_context(StandardError.new("github_payload_missing"))
          end

          trace(:started)
          profile = Profile.find_or_initialize_by(github_id: payload[:profile][:id])
          preserve_avatar = context.override(:preserve_profile_avatar, false)
          existing_avatar = preserve_avatar ? profile.avatar_url : nil

          preserve_fields = preserved_profile_fields

          ActiveRecord::Base.transaction do
            assign_profile_attributes(profile, payload, preserve_fields)
            new_avatar = context.avatar_public_url.presence || context.avatar_relative_path.presence
            # Prefer Spaces-hosted avatar, fall back to downloaded relative path if upload failed.
            if preserve_avatar && existing_avatar.present?
              profile.avatar_url = existing_avatar
            else
              profile.avatar_url = new_avatar
            end
            profile.last_synced_at = Time.current
            profile.save!

            update_repositories(profile, payload)
            update_organizations(profile, payload)
            update_social_accounts(profile, payload)
            update_languages(profile, payload)
            update_activity(profile, payload)
            update_readme(profile, payload)
          end

          profile.update_columns(last_sync_error: nil, last_sync_error_at: nil)

          context.profile = profile
          trace(:completed, profile_id: profile.id, avatar_url: profile.avatar_url)
          success_with_context(profile, metadata: { profile_id: profile.id, avatar_url: profile.avatar_url })
        rescue StandardError => e
          record_sync_error(payload, e)
          trace(:failed, error: e.message)
          failure_with_context(e)
        end

        private

        def assign_profile_attributes(profile, payload, preserve_fields)
          data = payload[:profile]
          attrs = {
            login: data[:login].to_s.downcase,
            name: pick(data, :name, profile.name),
            bio: pick(data, :bio, profile.bio),
            company: pick(data, :company, profile.company),
            location: pick(data, :location, profile.location),
            blog: pick(data, :blog, profile.blog),
            twitter_username: pick(data, :twitter_username, profile.twitter_username),
            hireable: pick(data, :hireable, profile.hireable || false),
            html_url: pick(data, :html_url, profile.html_url),
            followers: pick(data, :followers, profile.followers || 0),
            following: pick(data, :following, profile.following || 0),
            public_repos: pick(data, :public_repos, profile.public_repos || 0),
            public_gists: pick(data, :public_gists, profile.public_gists || 0),
            github_created_at: pick(data, :created_at, profile.github_created_at),
            github_updated_at: pick(data, :updated_at, profile.github_updated_at),
            summary: pick(payload, :summary, profile.summary)
          }
          attrs.except!(*preserve_fields) if preserve_fields.present?
          profile.assign_attributes(attrs)
        end

        def pick(hash, key, fallback)
          hash.key?(key) && !hash[key].nil? ? hash[key] : fallback
        end

        def update_repositories(profile, payload)
          update_repository_set(profile, payload, :top_repositories, "top")
          update_repository_set(profile, payload, :pinned_repositories, "pinned")
          update_repository_set(profile, payload, :active_repositories, "active")
        end

        def update_repository_set(profile, payload, key, repo_type)
          return unless payload.key?(key) && payload[key]

          profile.profile_repositories.where(repository_type: repo_type).destroy_all
          Array(payload[key]).each do |repo_data|
            repo = profile.profile_repositories.create!(
              name: repo_data[:name],
              full_name: repo_data[:full_name],
              description: repo_data[:description],
              html_url: repo_data[:html_url],
              stargazers_count: repo_data[:stargazers_count] || 0,
              forks_count: repo_data[:forks_count] || 0,
              language: repo_data[:language],
              repository_type: repo_type,
              github_created_at: repo_data[:created_at],
              github_updated_at: repo_data[:updated_at]
            )

            Array(repo_data[:topics]).each do |topic_name|
              repo.repository_topics.create!(name: topic_name)
            end
          end
        end

        def update_organizations(profile, payload)
          return unless payload.key?(:organizations) && payload[:organizations]

          profile.profile_organizations.destroy_all
          Array(payload[:organizations]).each do |org_data|
            profile.profile_organizations.create!(
              login: org_data[:login],
              name: org_data[:name],
              avatar_url: org_data[:avatar_url],
              description: org_data[:description],
              html_url: org_data[:html_url]
            )
          end
        end

        def update_social_accounts(profile, payload)
          accounts = payload[:social_accounts]
          return unless accounts

          profile.profile_social_accounts.destroy_all
          Array(accounts).each do |social|
            profile.profile_social_accounts.create!(
              provider: social[:provider],
              display_name: social[:display_name].presence || social[:handle],
              url: social[:url]
            )
          end
        end

        def update_languages(profile, payload)
          languages = payload.key?(:languages) ? payload[:languages] : payload[:profile_languages]
          return unless languages

          profile.profile_languages.destroy_all
          normalized_languages(languages).each do |lang|
            profile.profile_languages.create!(name: lang[:name], count: lang[:count])
          end
        end

        def update_activity(profile, payload)
          activity_payload = payload[:activity] || payload[:recent_activity]
          return unless activity_payload.is_a?(Hash)

          activity = profile.profile_activity || profile.build_profile_activity
          activity.assign_attributes(activity_payload)
          activity.save!
        end

        def update_readme(profile, payload)
          readme_payload = payload[:readme] || payload[:profile_readme]
          return if readme_payload.blank?

          readme_attrs = case readme_payload
          when String then { content: readme_payload }
          when Hash then readme_payload.symbolize_keys
          else
            {}
          end
          return if readme_attrs.blank?

          readme = profile.profile_readme || profile.build_profile_readme
          readme.assign_attributes(readme_attrs)
          readme.save!
        end

        def record_sync_error(payload, error)
          profile = Profile.for_login(login).first
          profile&.update_columns(
            last_sync_error: "#{error.class.name}: #{error.message}",
            last_sync_error_at: Time.current
          )
          StructuredLogger.error(
            message: "github_profile_persist_failed",
            login: login,
            error_class: error.class.name,
            error: error.message
          ) if defined?(StructuredLogger)
        end

        def normalized_languages(languages)
          case languages
          when Hash
            languages.map { |name, count| { name: name, count: count } }
          else
            Array(languages).map do |entry|
              if entry.is_a?(Hash)
                { name: entry[:name] || entry["name"], count: entry[:count] || entry["count"] }
              else
                entry
              end
            end
          end.compact.map do |lang|
            {
              name: lang[:name],
              count: lang[:count]
            }
          end.select { |lang| lang[:name].present? }
        end

        def preserved_profile_fields
          @preserved_profile_fields ||= Array(context.override(:preserve_profile_fields))
            .map { |field| field.to_s.strip.downcase }
            .reject(&:blank?)
            .map(&:to_sym)
            .uniq
        end
      end
    end
  end
end
