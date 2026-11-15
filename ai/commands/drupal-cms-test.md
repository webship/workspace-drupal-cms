---
description: Test a Drupal CMS site of the Webship Workspace with webship-js and the Drupal CMS step pack — set the testing stack up when it is missing, match every step, run the suite (or one feature, or one tag) in the site's container, and report what failed and why.
argument-hint: '<site> [tests/features/<name>.feature | @tag]'
---

# /drupal-cms-test

Test the Drupal CMS site named in: `$ARGUMENTS`

The first word is the site (its folder name in a sites folder of the workspace). What follows, if
anything, narrows the run: a path that starts with `tests/features/` is one feature (or one
folder of features), a word that starts with `@` is a tag expression. With nothing after the site,
the whole suite runs. With no site at all, stop and ask for one: list the candidates with
`grep -lE '"drupal/(cms|drupal_cms_[a-z0-9_]+)"' ~/workspace/*/*/composer.json`.

The workspace is container-based (DDEV by default) and everything below runs in the site's
container through the workspace's own command. Never run `npx cucumber-js`, `npx playwright`,
`drush`, `composer` or `npm` on the host for a site.

## 1. Find the site

```bash
ls -d ~/workspace/*/<site>/.ddev/config.yaml
grep -cE '"drupal/(cms|drupal_cms_[a-z0-9_]+)"' ~/workspace/<folder>/<site>/composer.json
```

`<folder>` is the sites folder the site is in (`dev`, `test`, `sandboxes`, `demos`). If
`composer.json` carries none of the Drupal CMS packages, stop: this command is for a Drupal CMS
site, such as one built with `cmd-drupal-cms-project.sh`. If `<folder>` has no
`cmd-tools-testing.sh`, stop and say that the folder is not a sites folder of this workspace.

## 2. Make sure the testing stack is there

```bash
cd ~/workspace/<folder>
grep -c "@webship-js/drupal-cms-steps" <site>/cucumber.js
```

If `cucumber.js` is missing or does not name the step pack, set the stack up (it adds what is
missing and keeps what was changed):

```bash
bash cmd-tools-testing.sh <site>
```

The pack loads the Drupal core step pack by itself, so `cucumber.js` names the Drupal CMS pack
only. The setup also writes the site template and the recipes of the site where the pack reads
them: a scenario that starts with `Given the site template is "<name>"` is skipped, not failed, on
a site built from another template.

## 3. Match every step, without a browser

```bash
bash cmd-tools-testing.sh <site> --dry-run                                        # the whole suite
bash cmd-tools-testing.sh <site> --dry-run --path tests/features/<name>.feature   # one feature
bash cmd-tools-testing.sh <site> --dry-run --tags "@critical"                     # one tag
```

Use the form that matches what was asked. An `Undefined` or `Ambiguous` step is a finding: name
the feature, the line and the phrase, show the closest phrase the pack defines
(`grep -hE "^(Given|When|Then)\(" <site>/node_modules/@webship-js/drupal-c*-steps/tests/step-definitions/*.steps.js`),
and stop before the real run.

## 4. Run

```bash
bash cmd-tools-testing.sh <site> --run                                            # the whole suite
bash cmd-tools-testing.sh <site> --run --path tests/features/<name>.feature       # one feature
bash cmd-tools-testing.sh <site> --run --tags "@critical"                         # one tag
```

Run it once. Do not add `--retry`, do not tag a scenario `@wip` and do not change a feature to
make the run pass.

## 5. Report

Say, in this order:

1. The site, its address (`https://<site>.ddev.site`) and what was run (suite, feature or tag).
2. The totals the run printed: scenarios and steps, passed and failed, and the time.
3. For each failed scenario: the feature and line, the step that failed, the message with its
   `Why` and `Hint` lines, and what it means for the site — a defect of the site, a scenario that
   asserts something the site never did (a role that may not publish a page of the page builder, a
   field label the form has twice), or the environment (the site was stopped, an account is
   missing: `bash cmd-tools-drupal-cms-cli.sh <site> --add-users` adds the default ones).
4. Where the report is: `~/workspace/<folder>/<site>/tests/reports/`.

A failing suite is a result: report it as it is. Never create an account for a scenario, never
write a password into a feature file, and never write a platform name into a step phrase. For
writing or fixing scenarios, use the `drupal-cms-scenarios` skill or hand over to the `drupal-cms-tester`
agent; for changing the site, to `drupal-cms-site-builder`.
