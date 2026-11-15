Feature: The site is built from its template, and its editorial tools work
  As the owner of the site
  I want the site template, the add-ons, the workflow and a redirect checked
  So that a build or an update that changed the site is caught by the suite

  Scenario: The site is the one the Starter template builds
    Given the site template is "drupal_cms_starter"
    And I am a logged in user with the "admin" user
    Then the site template should be "drupal_cms_starter"
    And the site should have at least 1 Canvas page
    And the "Home" Canvas page should exist
    And the default theme should be "Mercury"
    And the "canvas" module should be installed
    And the "Utility page" content type should exist
    And the status report should have no errors

  Scenario: The add-ons on offer are there, and the installed ones are the ones of the build
    Given I am a logged in user with the "admin" user
    And I am on the recommended add-ons page
    Then the recommended add-ons should list "Forms"
    And the recommended add-ons should list "Search"
    And the installed add-ons should match the recipes of the suite

  Scenario: The editorial workflow has its states
    Given I am a logged in user with the "admin" user
    Then the "Basic" workflow should have the "Draft" state
    And the "Basic" workflow should have the "Published" state

  Scenario: A redirect is added, followed and deleted
    Given I am a logged in user with the "admin" user
    When I add a redirect from "an-old-address-of-a-scenario" to "/user/login"
    Then the path "/an-old-address-of-a-scenario" should redirect to "/user/login"
    When I delete the redirect from "an-old-address-of-a-scenario"
    Then the path "/an-old-address-of-a-scenario" should not redirect to "/user/login"

  Scenario: A visitor is not held up by the consent notice
    Given I am an anonymous user
    And I am on the homepage
    Then I should not see the cookie consent dialog
