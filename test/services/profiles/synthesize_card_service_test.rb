require "test_helper"

class SynthesizeCardServiceTest < ActiveSupport::TestCase
  def setup
    @profile = Profile.create!(
      github_id: 999,
      login: "builder",
      name: "Builder One",
      bio: "OSS founder and AI tinkerer",
      followers: 250,
      public_repos: 42,
      github_created_at: 5.years.ago
    )
    # languages
    @profile.profile_languages.create!(name: "Ruby", count: 9000)
    @profile.profile_languages.create!(name: "JavaScript", count: 5000)
    # organizations
    @profile.profile_organizations.create!(login: "acme", name: "ACME")
    # activity
    @profile.create_profile_activity!(total_events: 120)
    # repositories
    @profile.profile_repositories.create!(name: "top1", full_name: "builder/top1", stargazers_count: 1200, repository_type: "top")
    @profile.profile_repositories.create!(name: "active1", full_name: "builder/active1", stargazers_count: 50, repository_type: "active")
  end

  test "computes and persists a profile card" do
    result = Profiles::SynthesizeCardService.call(profile: @profile, persist: true)
    assert result.success?, -> { result.error&.message }
    card = result.value
    assert_kind_of ProfileCard, card
    assert_equal @profile, card.profile
    assert_includes 0..100, card.attack
    assert_includes 0..100, card.defense
    assert_includes 0..100, card.speed
    assert_not_empty card.tags_array
    assert_equal "TecHub", card.theme
  end

  test "returns attrs without persisting when persist=false" do
    result = Profiles::SynthesizeCardService.call(profile: @profile, persist: false)
    assert result.success?
    value = result.value
    assert value[:attack]
    assert_equal "TecHub", value[:theme]
    assert_nil @profile.reload.profile_card
  end

  test "normalizes tags to six unique kebab-case entries" do
    profile = Profile.create!(
      github_id: 1001,
      login: "slugger",
      name: "Slugger Dev",
      followers: 1,
      public_repos: 3,
      github_created_at: 1.year.ago
    )
    %w[C++ C# C].each_with_index do |lang, idx|
      profile.profile_languages.create!(name: lang, count: 100 - idx)
    end
    repo = profile.profile_repositories.create!(
      name: "math-lab",
      full_name: "slugger/math-lab",
      repository_type: "top",
      stargazers_count: 10
    )
    repo.repository_topics.create!(name: "C++")
    repo.repository_topics.create!(name: "C Sharp")
    profile.create_profile_activity!(total_events: 12)

    result = Profiles::SynthesizeCardService.call(profile: profile, persist: true)
    assert result.success?, -> { result.error&.message }
    card = result.value
    assert_equal 6, card.tags_array.length
    card.tags_array.each do |tag|
      assert_match(/\A[a-z0-9]+(?:-[a-z0-9]+){0,2}\z/, tag)
    end
  end
end
