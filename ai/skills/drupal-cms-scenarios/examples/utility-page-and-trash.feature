Feature: A content editor writes a page, and the trash holds it until it is purged
  As the owner of the site
  I want the content editor to write and delete a page, and the administrator to empty the trash
  So that the suite proves the content form and the trash, and leaves the site as it found it

  # The content editor may delete a page and may not purge it: the administrator does, in the
  # same scenario. The form has two fields labelled "Description" (the page's, and the menu
  # link's), so the page's own is named by its id.

  Scenario: The editor writes a utility page and trashes it, the administrator purges it
    Given I am a logged in user with the "content editor" user
    And I am adding a "page" content item
    When I fill in "Title" with "A utility page written by a scenario"
    And I fill in "edit-field-description-0-value" with "Written and removed by the suite." by its "id" attribute
    And I save the content
    Then I should see a status message
    And the content should be unpublished
    And the moderation state should be "Draft"
    When I delete the content item I am viewing
    And I am on the content trash
    Then the content trash should hold "A utility page written by a scenario"
    Given I am a logged in user with the "admin" user
    And I am on the content trash
    When I purge "A utility page written by a scenario" from the content trash
    Then the content trash should not hold "A utility page written by a scenario"

  Scenario: The page form refuses a page with no description
    Given I am a logged in user with the "content editor" user
    And I am adding a "page" content item
    When I fill in "Title" with "A utility page with no description"
    And I try to save the content
    Then the "Description" field should block submission as required
