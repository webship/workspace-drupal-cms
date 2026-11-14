/**
 * Drupal CMS for Webship Workspace: a platform plugin.
 *
 * What the package carries is placed by the installer from the manifest: the builder and the
 * Drush tool in the sites folders, their functions and argparse under core/scripts/plugins/drupal-cms/,
 * the agents in the AI Agents folder. The dashboard needs nothing drawn for it: the builder is in the
 * Build list because it is a cmd-*-project.sh, the row menus are the core's, the agents are listed
 * like any other. What register() adds is what the assistant is told.
 *
 * Everything the dashboard is asked for goes through `api`; this package requires nothing from the
 * dashboard's own files, so it can be installed from npm and removed without a trace.
 */

import type { PluginApi } from '@webship.co/workspace-plugin-api';

/** The plugin's name: what --activate and --install take, and the folder under core/scripts/plugins/. */
export const PLATFORM = 'drupal-cms';

/** The name its functions and its user list are called by (a bash function name takes no hyphen). */
export const USER_LIST = 'drupal_cms';

/** The commands the installer places in every sites folder. */
export const COMMANDS = ['cmd-drupal-cms-project.sh', 'cmd-tools-drupal-cms-cli.sh'];

/** The agents the installer places in the AI Agents folder. */
export const AGENTS = ['drupal-cms-site-builder', 'drupal-cms-tester'];

/** What the assistant is told about Drupal CMS in this workspace. */
export function assistantContext(): string {
  return [
    'Drupal CMS (a plugin, @webship.co/workspace-drupal-cms): a Drupal CMS site is built with',
    '`bash cmd-drupal-cms-project.sh <name> --install --add-users` from a sites folder (dev, test, sandboxes, demos),',
    'in a container like every other project, at https://<name>.ddev.site.',
    '`--version` takes a release line (2.x, the default), a release (2.2.9) or a development branch (2.x-dev);',
    '`--template` takes starter (the default), blank or the name of another site template;',
    '`--recipes forms,search` applies add-on recipes after the install; `--dry-run` says what would be built and builds nothing.',
    '`bash cmd-tools-drupal-cms-cli.sh <name>` says what the site is; `--run "<drush command>"` runs Drush in it,',
    '`--recipe <names>` applies add-on recipes, `--update` updates the code and the database, `--cache-rebuild` rebuilds the cache,',
    '`--login` prints a one-time login link, `--add-users` adds the default accounts (administrator, content_editor, authenticated).',
    '`bash cmd-tools-testing.sh <name>` sets up webship-js with the Drupal CMS step pack; `--run` runs the suite.',
    `For Drupal CMS work, hand over to the agents ${AGENTS.map((a) => `\`${a}\``).join(' and ')}.`,
    'Never run composer, drush, npm or mysql on the host for a project; never write a $databases block into settings.php.',
  ].join(' ');
}

export function register(api: PluginApi): void {
  api.addAssistantContext(assistantContext);
}
