---
name: drupal-cms-scenarios
description: Write and run webship-js scenarios for a Drupal CMS site of the Webship Workspace with the Drupal CMS step pack (`@webship-js/drupal-cms-steps`, which loads the Drupal core pack) — the phrases of the pack by area (the dashboard and the navigation, pages of the page builder, the site template and its add-ons, the editorial tools, the trash, the consent notice), the handles of the users registry, and the workspace command that runs them in the site's container. Use when asked to "write a scenario for this Drupal CMS site", "test the content editor role", "which step is there for a Canvas page", "add a feature for the site template", or when a `.feature` file of a Drupal CMS project is being written or fixed.
argument-hint: '<site> [what to cover]'
---

# drupal-cms-scenarios

Scenarios for a Drupal CMS site of a Webship Workspace (`~/workspace`, container-based, DDEV by
default), written from the steps of [`@webship-js/drupal-cms-steps`](https://github.com/webship/drupal-cms-steps),
of the Drupal core pack it loads ([`@webship-js/drupal-core-steps`](https://github.com/webship/drupal-core-steps))
and of [webship-js](https://github.com/webship/webship-js) itself, and run in the site's container
by the workspace's own command. It comes with the Drupal CMS plugin
(`@webship.co/workspace-drupal-cms`), like the builder (`cmd-drupal-cms-project.sh`), the Drush
tool (`cmd-tools-drupal-cms-cli.sh`) and the agents `drupal-cms-site-builder` and
`drupal-cms-tester`.

## Where everything is

| What | Where |
| --- | --- |
| The site | `~/workspace/<folder>/<site>`, at `https://<site>.ddev.site` (`<folder>` is a sites folder: `dev`, `test`, `sandboxes`, `demos`) |
| The suite's configuration | `<site>/cucumber.js`: the step definitions it loads, the users registry (`worldParameters.users`), the site template and the recipes of the site |
| The features | `<site>/tests/features/*.feature` (`site.feature` is the first one the setup wrote) |
| The packs' steps | `<site>/node_modules/@webship-js/drupal-cms-steps/tests/step-definitions/*.steps.js` and `…/drupal-core-steps/tests/step-definitions/*.steps.js` |
| webship-js's steps | `<site>/node_modules/webship-js/tests/step-definitions/*.js` |
| The reports | `<site>/tests/reports/` |

## The order of work

1. **Make sure the testing stack is there.** From the sites folder:
   ```bash
   cd ~/workspace/<folder>
   bash cmd-tools-testing.sh <site>
   ```
   It adds webship-js, both step packs, the users registry and `tests/features/site.feature`,
   writes the site template and the recipes of the site where the pack reads them, and makes sure
   the default accounts are on the site. It is safe to run again: it adds what is missing and
   keeps what was changed.
2. **Read the installed steps before writing a phrase.** They are the source of truth: the packs
   move, and a phrase from memory is a guess.
   ```bash
   cd ~/workspace/<folder>/<site>
   grep -hE "^(Given|When|Then)\(" node_modules/@webship-js/drupal-cms-steps/tests/step-definitions/*.steps.js
   grep -hE "^(Given|When|Then)\(" node_modules/@webship-js/drupal-core-steps/tests/step-definitions/*.steps.js
   ```
   Every step carries a comment block with examples above it; open the file when a phrase is not
   obvious.
3. **Look at the page first** (the Playwright MCP browser, a tab of your own) when the scenario
   is about a page you have not seen. A scenario written without having seen the page asserts
   what you imagine.
4. **Write the feature** in `<site>/tests/features/`, from phrases that exist (the lists below).
5. **Match every step without a browser**, then run the feature, then the suite:
   ```bash
   cd ~/workspace/<folder>
   bash cmd-tools-testing.sh <site> --dry-run --path tests/features/<name>.feature
   bash cmd-tools-testing.sh <site> --run --path tests/features/<name>.feature
   bash cmd-tools-testing.sh <site> --run --tags "@critical"
   bash cmd-tools-testing.sh <site> --run
   ```
   A dry run says `Undefined` for a phrase no definition matches: fix the phrase, do not write a
   step for it.

## Accounts: a handle, never a password

A scenario logs in by a handle of the users registry. The default accounts are on the site
already (`bash cmd-tools-drupal-cms-cli.sh <site> --add-users` adds them again if they were
removed):

| Handle | Account | Role |
| --- | --- | --- |
| `admin` | `administrator` | administrator |
| `content editor` | `content_editor` | content_editor |
| `authenticated` | `authenticated` | none |

```gherkin
Given I am a logged in user with the "content editor" user
And I am on the dashboard
Then I should see the dashboard
```

## The phrases, by area

Each line is a phrase one of the packs defines, and each one passed on a site built with
`bash cmd-drupal-cms-project.sh <site> --install --add-users` (the Starter site template; the
names in quotes are that site's). Most `should` steps also take the negative: `should not see`,
`should not list`, `should not exist`.

### Sessions, the dashboard and the navigation

```gherkin
Given I am an anonymous user
Given I am on the login page
Given I am a logged in user with the "content editor" user
When I log in with the email address of "content editor"
When I log out
Then I should be logged in
Then I should not be logged in
Given I am on the dashboard
Then I should see the dashboard
Then I should see the "Recent content" dashboard section
Then I should see the "Top tasks" dashboard section
Then I should see the navigation sidebar
Then the navigation sidebar should list "Pages"
Then the navigation sidebar should not list "Extend"
Then I should be allowed access to "/admin/content"
Then I should be denied access to "/admin/people"
```

### Pages of the page builder

```gherkin
When I create a Canvas page "Landing" at "/landing" with the "Heading" component
Then the "Landing" Canvas page should exist
Then the "Landing" Canvas page should have 1 component
When I visit the "Landing" Canvas page
When I delete the "Landing" Canvas page
Then the Canvas pages trash should hold "Landing"
When I purge "Landing" from the Canvas pages trash
Then the site should have at least 1 Canvas page
Then the Canvas component library should list the "Heading" component
When I open the "Home" Canvas page in the editor
Then I should see the Canvas editor
Then the Canvas editor should be editing "Home"
Then the Canvas editor should show the page as "Published"
Then the Canvas editor should have no pending changes
When I open the "Pages" panel in the Canvas editor
Then the Canvas "Pages" panel should list "Home"
```

A component is named by its label (`"Heading"`) or by its id (`"sdc.mercury.heading"`), and takes
its values from a table when the step ends with a colon:

```gherkin
When I create a Canvas page "Landing" at "/landing" with the "sdc.mercury.heading" component:
  | heading_text | A heading written by a scenario |
```

### The site template, the add-ons and how the site is built

```gherkin
Given the site template is "drupal_cms_starter"
Then the site template should be "drupal_cms_starter"
Given I am on the recommended add-ons page
Then the recommended add-ons should list "Forms"
Then the "Forms" add-on should not be installed
Then the installed add-ons should match the recipes of the suite
Then the default theme should be "Mercury"
Then the "canvas" module should be installed
Then the "Utility page" content type should exist
Then the "Content editor" role should exist
Then the status report should have no errors
```

`Given the site template is "<name>"` is a condition, not an assertion: on a site built from
another template the scenario is skipped. `Then the site template should be "<name>"` asserts.

### Content, the editorial tools and the trash

```gherkin
Given I am adding a "page" content item
When I fill in "Title" with "A utility page written by a scenario"
When I save the content
When I try to save the content
Then the "Description" field should block submission as required
Then the content should be unpublished
Then the moderation state should be "Draft"
When I delete the content item I am viewing
Given I am on the content trash
Then the content trash should hold "A utility page written by a scenario"
When I purge "A utility page written by a scenario" from the content trash
Then the "Basic" workflow should have the "Draft" state
When I add a redirect from "an-old-address" to "/user/login"
Then the path "/an-old-address" should redirect to "/user/login"
When I delete the redirect from "an-old-address"
```

### The consent notice

```gherkin
Then I should not see the cookie consent dialog
Then the consent dialog mode should be "silent"
```

`I am an anonymous user`, `I am on the homepage`, `I fill in "<field>" with "<value>"`,
`I should see "<text>"` and `the response status code should be 200` are webship-js's own steps;
its status codes, classes, landmarks and accessibility audits are used as they are and never
redefined for this platform.

## Traps found on a real site

- **The navigation is not Drupal core's.** The sidebar of the Starter template lists `Dashboard`,
  `Create`, `Pages`, `Media`, `Trash`, and for an administrator `Structure`, `Appearance`,
  `Extend`, `Configuration`, `People`. There is no `Content` link: `the navigation sidebar should
  list "Content"` fails for every role.
- **The one content type is "Utility page"**, with the machine name `page`: `the "Utility page"
  content type should exist` reads the label, `I am adding a "page" content item` opens the form.
  Its `Description` is required, so `I create a "page" content item titled "<title>"` (which
  fills the title only) is refused: fill the form step by step.
- **Two fields are labelled "Description"** on that form (the page's own and the menu link's):
  `I fill in "Description" with "<text>"` finds both and fails. Name the page's own by its id:
  `I fill in "edit-field-description-0-value" with "<text>" by its "id" attribute`.
- **A saved page is a draft.** The content editor saves into the `Draft` state: assert
  `the content should be unpublished`, not `published`.
- **Deleting is trashing, and the content editor cannot purge.** A deleted page or Canvas page
  goes to the trash and stays there. The content trash gives the content editor no purge: log in
  as `admin` in the same scenario (`Given I am a logged in user with the "admin" user`) and purge
  there.
- **The content editor cannot publish a Canvas page.** `I create a Canvas page …` as
  `content editor` fails at the publish (`The 'publish auto-saves' permission is required`) and
  leaves the page behind: build pages as `admin`, and delete and purge what a failed run left.
- **A fresh site shows no consent dialog.** The consent manager runs in the `silent` mode until
  the site adds a service that needs consent, so `I should see the cookie consent dialog` fails
  even after `Given the cookie consent is not given yet`.
- A scenario that failed after it created something left it behind: delete and purge it before
  the next run, or the next run finds it.

## Rules

- **No account is created in a suite.** No `drush user:create` in a hook, no registration
  scenario that leaves an account behind. A role the registry does not have is asked for, not
  made.
- **Never the workspace account.** The site's own administrator is not in the registry; `admin`
  is the `administrator` default account.
- **No password in a feature file**, except where a wrong password is the subject.
- **No platform name in a step phrase**: `I am on the dashboard`, never a phrase that names the
  platform. The same holds for a custom step.
- **No selector when a step says it**: `I should see the dashboard`, not the class of the
  dashboard. A field's id is the exception a form with two labels of the same name forces.
- **What a scenario creates, it removes** in the same scenario, under a title nobody else uses:
  deleted and purged from the trash.
- **A custom step is the last resort**: look in both packs and in webship-js first, write it in
  `<site>/tests/step-definitions/` with a comment block and examples, and say it may belong in
  the pack.
- **Everything runs in the container**, through `cmd-tools-testing.sh`. Never `npx cucumber-js`
  or `npx playwright` on the host.
- **A failing scenario is a result.** No `@wip`, no longer timeout, no looser assertion to turn a
  run green: say what the site did.

## Examples that run

`examples/` holds four features that pass on a site built with
`bash cmd-drupal-cms-project.sh <site> --install --add-users`. Copy one into the suite and run it:

```bash
cp ~/workspace/ai-skills/drupal-cms-scenarios/examples/dashboard-and-roles.feature ~/workspace/<folder>/<site>/tests/features/
cd ~/workspace/<folder>
bash cmd-tools-testing.sh <site> --run --path tests/features/dashboard-and-roles.feature
```

| Feature | What it shows |
| --- | --- |
| `examples/dashboard-and-roles.feature` | The dashboard and the navigation of each role, a login by email address, the paths a role is refused |
| `examples/canvas-page-lifecycle.feature` | A Canvas page built, seen, deleted and purged; a component given its text from a table; the home page in the editor |
| `examples/site-template-and-editorial.feature` | The site template, the add-ons, the workflow, a redirect added and deleted, the consent notice |
| `examples/utility-page-and-trash.feature` | The content editor writing and trashing a page, the administrator purging it; a required field refusing the form |

## The book

For any automated functional testing in this work (a Gherkin feature, a step definition, choosing a
step, a test run and its failures), read the book *Automated Functional Testing Recipes* first.

- **Where.** Use the first that exists: `.claude/automated-functional-testing-recipes/` in the project,
  `~/.claude/automated-functional-testing-recipes/` (installed by webship/webship-js-ai-agent,
  webship/webship-js-skills or webship/ai-agents), or
  https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes
- **How.** Its `README.md` first, then the chapter that matches the task (one file per chapter,
  named by its subject), not the single complete file.
- **Which wins.** The installed webship-js package and the step pack are the source of truth for
  step phrasing. When they differ from the book, follow them and say so.
- **For Drupal CMS.** Start with `ch26-testing-cms-applications.md` (content, publishing, media and
  taxonomy), `ch10-authentication-authorization.md` (logins, sessions and access by role),
  `ch33-complete-step-definition-reference.md` (every built-in step) and `ch21-when-tests-go-bad.md`
  (flaky, brittle and slow scenarios).
