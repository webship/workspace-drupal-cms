Feature: The site answers, its accounts work and its page builder holds a page
  As the owner of the site
  I want the front page, the login page, each default account, the dashboard and a page of the page builder to work
  So that a build that came out broken is caught before anything else is tested

  # Placed by the workspace's testing setup as a starting point: it is yours to change.
  # The accounts are the default ones (cmd-tools-add-users.sh); a scenario logs in by a handle of
  # the users registry in cucumber.js, so no password is written here.

  @critical
  Scenario: The front page is served
    Given I am an anonymous user
    And I am on the homepage
    Then the response status code should be 200
    And I should be on the front page
    And the page should not have PHP errors

  @critical
  Scenario: The login page is served with its form
    Given I am on the login page
    Then the response status code should be 200
    And I should see the login form

  Scenario Outline: Each default account logs in
    Given I am a logged in user with the "<handle>" user
    Then I should be logged in
    And the page should return HTTP status 200

    Examples:
      | handle         |
      | admin          |
      | content editor |
      | authenticated  |

  Scenario: The administrator sees the dashboard
    Given I am a logged in user with the "admin" user
    And I am on the dashboard
    Then I should see the dashboard
    And I should see the navigation sidebar
    And I should see the "Recent content" dashboard section

  Scenario: The content editor sees the dashboard and stays out of the people
    Given I am a logged in user with the "content editor" user
    And I am on the dashboard
    Then I should see the dashboard
    And I should be denied access to "/admin/people"

  Scenario: An account with no role stays out of the administration
    Given I am a logged in user with the "authenticated" user
    Then I should be denied access to "/admin/dashboard"
    And I should be denied access to "/admin/content"

  Scenario: The page builder holds the home page
    Given the site template is "drupal_cms_starter"
    And I am a logged in user with the "admin" user
    Then the site should have at least 1 Canvas page
    And the "Home" Canvas page should exist

  Scenario: A visitor is not held up by the consent notice
    Given I am an anonymous user
    And I am on the homepage
    Then I should not see the cookie consent dialog

  Scenario: An anonymous visitor has no session and no way in
    Given I am not logged in
    Then I should not be logged in
    And I should be denied access to "/admin/dashboard"
