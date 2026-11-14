Feature: The Drupal CMS plugin on the dashboard
  Once the plugin is activated and installed, the sites folders offer the Drupal CMS builder, the
  AI Agents folder lists the Drupal CMS agents, and the Plugins page lists the plugin with its steps.

  Scenario: The plugin is listed on the Plugins page
    Given I am on "/settings/plugins"
     Then I should see "Drupal CMS"
      And I should see "@webship.co/workspace-drupal-cms"

  Scenario: A sites folder offers the Drupal CMS builder
    Given I am on "/dev"
     Then "option[value='cmd-drupal-cms-project.sh']" should be attached

  Scenario: The AI Agents folder lists the agents the plugin ships
    Given I am on "/ai-agents"
     Then I should see "drupal-cms-site-builder"
      And I should see "drupal-cms-tester"
