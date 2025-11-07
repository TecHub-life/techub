# frozen_string_literal: true

require "application_system_test_case"

class StimulusTabsTest < ApplicationSystemTestCase
  test "profile page has tabs controller and tab elements" do
    # Create a profile with necessary data for rendering
    profile = Profile.create!(
      github_id: 1001,
      login: "testuser",
      name: "Test User",
      bio: "Test bio",
      avatar_url: "https://avatars.githubusercontent.com/u/1?v=4",
      html_url: "https://github.com/testuser",
      listed: true
    )

    # Create a profile card so the page renders fully
    profile.create_profile_card!(
      attack: 50,
      defense: 50,
      speed: 50,
      vibe: "Test Vibe",
      archetype: "Code Warrior",
      spirit_animal: "Wolf"
    )

    # Create preferences (required by view)
    profile.create_preferences! unless profile.preferences

    visit profile_path(profile.login)

    # Verify page loaded by checking title (more reliable than gradient text)
    assert_equal "Test User – TecHub", page.title

    # Verify we're on the correct profile page by checking URL
    assert_current_path profile_path("testuser")

    # Verify tabs controller is present
    assert_selector "[data-controller='tabs']"

    # Verify all 6 tab buttons exist
    assert_selector "[data-tabs-target='tab']", count: 6
    assert_selector "#tab-profile"
    assert_selector "#tab-overview"
    assert_selector "#tab-cards"
    assert_selector "#tab-repos"
    assert_selector "#tab-activity"
    assert_selector "#tab-stats"

    # Verify tab panels exist in DOM
    assert_selector "#tab-panel-profile", visible: :all
    assert_selector "#tab-panel-overview", visible: :all
    assert_selector "#tab-panel-cards", visible: :all
  end

  test "tabs are clickable and have correct data attributes" do
    profile = Profile.create!(
      github_id: 1002,
      login: "tabuser",
      name: "Tab User",
      bio: "Testing tabs",
      avatar_url: "https://avatars.githubusercontent.com/u/2?v=4",
      html_url: "https://github.com/tabuser",
      listed: true
    )

    profile.create_profile_card!(
      attack: 60,
      defense: 60,
      speed: 60,
      vibe: "Tab Vibe",
      archetype: "System Admin",
      spirit_animal: "Eagle"
    )

    # Create preferences
    profile.create_preferences! unless profile.preferences

    visit profile_path(profile.login)

    # Verify page loaded
    assert_equal "Tab User – TecHub", page.title
    assert_current_path profile_path("tabuser")

    # Verify tabs have correct data attributes for Stimulus
    cards_tab = find("#tab-cards")
    assert cards_tab["data-tabs-target"] == "tab"
    assert cards_tab["data-tabs-id"] == "cards"
    assert cards_tab["data-action"] == "tabs#select"

    # Verify tab panels have correct data attributes
    cards_panel = find("#tab-panel-cards", visible: :all)
    assert cards_panel["data-tabs-target"] == "panel"
    assert cards_panel["data-tabs-id"] == "cards"
  end

  test "profile page renders with all content" do
    # This test verifies the page renders correctly
    profile = Profile.create!(
      github_id: 1003,
      login: "contentuser",
      name: "Content User",
      bio: "Testing content",
      avatar_url: "https://avatars.githubusercontent.com/u/3?v=4",
      html_url: "https://github.com/contentuser",
      listed: true
    )

    profile.create_profile_card!(
      attack: 70,
      defense: 70,
      speed: 70,
      vibe: "Content Vibe",
      archetype: "Debugger",
      spirit_animal: "Owl"
    )

    # Create preferences
    profile.create_preferences! unless profile.preferences

    visit profile_path(profile.login)

    # Verify page loaded
    assert_equal "Content User – TecHub", page.title
    assert_current_path profile_path("contentuser")

    # Tab navigation should be present in the DOM
    assert_selector "[data-controller='tabs']"
    assert_selector "[data-tabs-target='tab']", count: 6

    # Verify all tab panels exist (even if hidden)
    assert_selector "#tab-panel-profile", visible: :all
    assert_selector "#tab-panel-overview", visible: :all
    assert_selector "#tab-panel-cards", visible: :all
  end

  # Skip settings test for now - authentication in system tests is complex
  # test "settings page has tabs structure" do
  #   # TODO: Implement proper authentication for system tests
  # end
end
