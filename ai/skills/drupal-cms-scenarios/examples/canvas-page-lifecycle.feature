Feature: A page of the page builder is made and taken away again
  As an administrator
  I want to build a Canvas page, see it on the site and remove it
  So that the suite proves the page builder works and leaves the site as it found it

  # A deleted Canvas page goes to the trash: the scenario purges it, or the next run finds it.

  Scenario: The administrator builds a Canvas page with one component and removes it
    Given I am a logged in user with the "admin" user
    When I create a Canvas page "A page written by a scenario" at "/a-page-written-by-a-scenario" with the "Heading" component
    Then the "A page written by a scenario" Canvas page should exist
    And the "A page written by a scenario" Canvas page should have 1 component
    When I visit the "A page written by a scenario" Canvas page
    Then the response status code should be 200
    When I delete the "A page written by a scenario" Canvas page
    Then the "A page written by a scenario" Canvas page should not exist
    And the Canvas pages trash should hold "A page written by a scenario"
    When I purge "A page written by a scenario" from the Canvas pages trash
    Then the Canvas pages trash should not hold "A page written by a scenario"

  Scenario: A component is given its text when the page is made
    Given I am a logged in user with the "admin" user
    When I create a Canvas page "A heading written by a scenario" at "/a-heading-written-by-a-scenario" with the "sdc.mercury.heading" component:
      | heading_text | This heading is written and removed by the suite |
    And I visit the "A heading written by a scenario" Canvas page
    Then I should see "This heading is written and removed by the suite"
    When I delete the "A heading written by a scenario" Canvas page
    And I purge "A heading written by a scenario" from the Canvas pages trash
    Then the "A heading written by a scenario" Canvas page should not exist

  Scenario: The home page opens in the editor of the page builder
    Given the site template is "drupal_cms_starter"
    And I am a logged in user with the "admin" user
    When I open the "Home" Canvas page in the editor
    Then I should see the Canvas editor
    And the Canvas editor should be editing "Home"
    And the Canvas editor should show the page as "Published"
    And the Canvas editor should have no pending changes
    When I open the "Pages" panel in the Canvas editor
    Then the Canvas "Pages" panel should list "Home"
