#!/usr/bin/env bash

# Installed by the Drupal CMS plugin (plugins.sh --install drupal-cms); __WORKSPACE__ is the workspace it was installed into.
#
# Drush for one Drupal CMS project of this workspace, in its container: say what the site is, run
# a Drush command, apply an add-on recipe, update the code and the database, rebuild the cache,
# print a one-time login link, add or remove the default accounts. Nothing here runs on the host.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="drupal_cms";

ARGPARSE_DESCRIPTION="Run Drush on a Drupal CMS project of __WORKSPACE__: status, a command, a recipe, updates, the cache, a login link, the default accounts"
# The args file comes with the plugin: core/scripts/plugins/drupal-cms/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/drupal-cms/args/arg-drupal-cms-cli.sh || exit 1 ;

shift $#;

drupal_cms_cli_tool ;
