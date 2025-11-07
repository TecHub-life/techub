# frozen_string_literal: true

module SystemTest
  module ProfileHelpers
    TAB_IDS = %w[profile overview cards repos activity stats].freeze

    DEFAULT_CARD_ATTRIBUTES = {
      attack: 50,
      defense: 50,
      speed: 50,
      vibe: "Test Vibe",
      archetype: "Code Warrior",
      spirit_animal: "Wolf"
    }.freeze

    def given_profile(kind = :listed_with_card, profile: {}, card: {}, preferences: {})
      profile_attrs = default_profile_attributes(profile, kind)
      record = Profile.create!(profile_attrs)

      if kind.to_s.end_with?("with_card") || kind.to_s.include?("card")
        card_attrs = DEFAULT_CARD_ATTRIBUTES.merge(card || {})
        record.create_profile_card!(card_attrs)
      end

      record.create_preferences!(preferences) unless record.preferences
      record
    end

    def expect_profile_page(profile)
      assert_equal "#{profile.name} – TecHub", page.title
      assert_current_path profile_path(profile.login), ignore_query: true
    end

    def expect_tabs(*ids)
      ids = TAB_IDS if ids.empty?
      assert_selector "[data-controller='tabs']"
      assert_selector "[data-tabs-target='tab']", count: TAB_IDS.size
      ids.each do |id|
        assert_selector "#tab-#{id}"
        assert_selector "#tab-panel-#{id}", visible: :all
      end
    end

    private

    def default_profile_attributes(overrides, kind)
      login = overrides[:login] || "user-#{SecureRandom.hex(3)}"
      default_listed = !kind.to_s.include?("unlisted")
      {
        github_id: overrides[:github_id] || SecureRandom.random_number(1_000_000) + 1_000_000,
        login: login,
        name: overrides[:name] || login.titleize,
        bio: overrides[:bio] || "Test bio",
        avatar_url: overrides[:avatar_url] || "https://avatars.githubusercontent.com/u/1?v=4",
        html_url: overrides[:html_url] || "https://github.com/#{login}",
        listed: overrides.key?(:listed) ? overrides[:listed] : default_listed
      }.merge(overrides.except(:login, :name, :bio, :avatar_url, :html_url, :listed))
    end
  end
end
