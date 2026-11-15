Feature: Each account gets the dashboard and the menu of its role
  As the owner of the site
  I want every default account to see its own dashboard and navigation and to be refused the rest
  So that a change of permissions is caught by the suite

  # The accounts are the default ones; a scenario logs in by a handle of the users registry.

  Scenario: The administrator sees the dashboard and the whole navigation
    Given I am a logged in user with the "admin" user
    And I am on the dashboard
    Then I should see the dashboard
    And I should see the "Recent content" dashboard section
    And I should see the "Top tasks" dashboard section
    And the navigation sidebar should list "Pages"
    And the navigation sidebar should list "Extend"

  Scenario: The content editor sees the dashboard and a shorter navigation
    Given I am a logged in user with the "content editor" user
    And I am on the dashboard
    Then I should see the dashboard
    And the navigation sidebar should list "Pages"
    And the navigation sidebar should list "Media"
    And the navigation sidebar should not list "Extend"
    And the navigation sidebar should not list "People"

  Scenario: The content editor reaches the content and nothing above it
    Given I am a logged in user with the "content editor" user
    Then I should be allowed access to "/admin/content"
    And I should be denied access to "/admin/people"
    And I should be denied access to "/admin/modules"

  Scenario: An account logs in with its email address
    Given I am on the login page
    When I log in with the email address of "content editor"
    Then I should be logged in
    When I log out
    Then I should not be logged in

  Scenario: An account with no role has no dashboard
    Given I am a logged in user with the "authenticated" user
    Then I should be denied access to "/admin/dashboard"
    And I should be denied access to "/admin/content"
