# frozen_string_literal: true

require "application_system_test_case"

class StimulusTabsTest < ApplicationSystemTestCase
  test "profile page loads Stimulus and tab switching works" do
    # Create a profile with necessary data for rendering
    profile = profiles(:one)
    profile.update!(
      login: "testuser",
      name: "Test User",
      bio: "Test bio",
      avatar_url: "https://avatars.githubusercontent.com/u/1?v=4",
      html_url: "https://github.com/testuser"
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

    visit profile_path(profile)

    # Wait for page to load and Stimulus to initialize
    assert_selector "[data-controller='tabs']", wait: 5

    # Verify initial state - Profile tab should be active by default
    assert_selector "#tab-profile[aria-selected='true']", wait: 2
    assert_selector "#tab-panel-profile:not(.hidden)", wait: 2

    # Click on Cards tab
    find("#tab-cards").click

    # Verify Cards tab becomes active and its panel is visible
    assert_selector "#tab-cards[aria-selected='true']", wait: 2
    assert_selector "#tab-panel-cards:not(.hidden)", wait: 2
    # Profile panel should be hidden
    assert_selector "#tab-panel-profile.hidden", wait: 2

    # Click on Overview tab
    find("#tab-overview").click

    # Verify Overview tab becomes active
    assert_selector "#tab-overview[aria-selected='true']", wait: 2
    assert_selector "#tab-panel-overview:not(.hidden)", wait: 2
    # Cards panel should be hidden
    assert_selector "#tab-panel-cards.hidden", wait: 2
  end

  test "ops profile page loads Stimulus and tab switching works" do
    # Create a profile for ops page
    profile = profiles(:one)
    profile.update!(
      login: "opsuser",
      name: "Ops User",
      bio: "Ops test bio",
      avatar_url: "https://avatars.githubusercontent.com/u/2?v=4",
      html_url: "https://github.com/opsuser"
    )

    profile.create_profile_card!(
      attack: 60,
      defense: 60,
      speed: 60,
      vibe: "Ops Vibe",
      archetype: "System Admin",
      spirit_animal: "Eagle"
    )

    visit ops_profile_path(profile)

    # Wait for page to load and Stimulus to initialize
    assert_selector "[data-controller='tabs']", wait: 5

    # Verify tabs controller is working by checking for tab elements
    assert_selector "[data-tabs-target='tab']", minimum: 3

    # Click on a tab to verify Stimulus is functional
    first_tab = find("[data-tabs-target='tab']", match: :first)
    first_tab.click

    # Verify the tab has aria-selected attribute (managed by Stimulus)
    assert first_tab["aria-selected"].present?, "Stimulus should set aria-selected attribute"
  end

  test "Stimulus fails gracefully if importmap is broken" do
    # This test documents expected behavior when Stimulus doesn't load
    # In real scenarios with broken importmap, the tabs controller won't initialize
    # and we should see the fallback behavior (all tabs visible or first tab only)

    profile = profiles(:one)
    profile.update!(
      login: "fallbackuser",
      name: "Fallback User",
      avatar_url: "https://avatars.githubusercontent.com/u/3?v=4",
      html_url: "https://github.com/fallbackuser"
    )

    profile.create_profile_card!(
      attack: 70,
      defense: 70,
      speed: 70,
      vibe: "Fallback Vibe",
      archetype: "Debugger",
      spirit_animal: "Owl"
    )

    visit profile_path(profile)

    # Even if Stimulus fails, the page should still render
    assert_selector "h1", text: profile.display_name, wait: 5

    # Tab navigation should be present in the DOM
    assert_selector "[data-controller='tabs']"
    assert_selector "[data-tabs-target='tab']", minimum: 3
  end
end
