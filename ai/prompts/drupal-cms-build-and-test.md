Build a Drupal CMS site in a sites folder and prove it with its first webship-js feature.

The launch command below is for Claude Code, the default; the text between the triple quotes can be given to another AI CLI as it is.

```
claude --permission-mode bypassPermissions """
Build a Drupal CMS site named <name> in this sites folder and test it with webship-js
# ~/workspace/<dev|test|sandboxes|demos> · https://<name>.ddev.site · container-based (DDEV by default)
# the builder deletes a project of the same name first: stop if <name> is a site somebody still needs
# nothing on the host: no drush, composer, npm or mysql outside the site's container
# a feature to write or a run to read: the book Automated Functional Testing Recipes first (its README.md, then the matching chapter), from .claude/automated-functional-testing-recipes/ in the project, ~/.claude/automated-functional-testing-recipes/ or https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes

1. bash cmd-drupal-cms-project.sh <name> --install --add-users
   (add --template blank for the Blank site template, --recipes forms,search for add-on recipes,
   --version <x> for another release; --dry-run first says what it would build)
2. bash cmd-tools-drupal-cms-cli.sh <name>
   tell me the version, the address, the site template, the recipes and the accounts it lists
3. bash cmd-tools-testing.sh <name>
   webship-js, the step packs, the users registry and tests/features/site.feature
4. bash cmd-tools-testing.sh <name> --dry-run --path tests/features/site.feature
5. bash cmd-tools-testing.sh <name> --run --path tests/features/site.feature

If a command fails, show the line that failed and stop. Do not retry with other flags.
When the feature is green: the address, the version, how many scenarios and steps passed
(a scenario for another site template is skipped, not failed: say which).
Then ask me whether to keep the site or remove it with: bash cmd-tools-remove.sh <name>
"""
```
