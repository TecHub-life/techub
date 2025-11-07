# frozen_string_literal: true

require "application_system_test_case"

class StimulusTabsTest < ApplicationSystemTestCase
  test "profile page has tabs controller and tab elements" do
    profile = given_profile(
      :listed_with_card,
      profile: {
        github_id: 1001,
        login: "testuser",
        name: "Test User",
        bio: "Test bio",
        html_url: "https://github.com/testuser"
      },
      card: {
        attack: 50,
        defense: 50,
        speed: 50,
        vibe: "Test Vibe",
        archetype: "Code Warrior",
        spirit_animal: "Wolf"
      }
    )

    visit profile_path(profile.login)

    expect_profile_page(profile)
    expect_tabs
  end

  test "tabs are clickable and have correct data attributes" do
    profile = given_profile(
      :listed_with_card,
      profile: {
        github_id: 1002,
        login: "tabuser",
        name: "Tab User",
        bio: "Testing tabs",
        html_url: "https://github.com/tabuser"
      },
      card: {
        attack: 60,
        defense: 60,
        speed: 60,
        vibe: "Tab Vibe",
        archetype: "System Admin",
        spirit_animal: "Eagle"
      }
    )

    visit profile_path(profile.login)

    expect_profile_page(profile)

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
    profile = given_profile(
      :listed_with_card,
      profile: {
        github_id: 1003,
        login: "contentuser",
        name: "Content User",
        bio: "Testing content",
        html_url: "https://github.com/contentuser"
      },
      card: {
        attack: 70,
        defense: 70,
        speed: 70,
        vibe: "Content Vibe",
        archetype: "Debugger",
        spirit_animal: "Owl"
      }
    )

    visit profile_path(profile.login)

    expect_profile_page(profile)

    expect_tabs(:profile, :overview, :cards)
  end

  # Skip settings test for now - authentication in system tests is complex
  # test "settings page has tabs structure" do
  #   # TODO: Implement proper authentication for system tests
  # end
end
