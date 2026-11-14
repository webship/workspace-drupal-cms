#!/usr/bin/env bash

# workspace-name: Drupal CMS (a site template and recipes)

# Installed by the Drupal CMS plugin (plugins.sh --install drupal-cms); __WORKSPACE__ is the workspace it was installed into.
#
# Build a Drupal CMS site in a container: the latest 2.x, or what --version names, at
# https://<name>.ddev.site. With --install the site is installed from a site template (the Starter
# one unless --template names another) with the workspace account as its administrator, and the
# add-on recipes of --recipes are applied; with --add-users it also gets the default accounts: an
# administrator, a content editor and an account with no role.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Set site version: the release line whose latest release is built when --version says nothing.
site_version="2.x";

# Distribution.
distribution_name="drupal_cms";
distribution_title="Drupal CMS";
distribution_webroot="web";

ARGPARSE_DESCRIPTION="Build a ${distribution_title} project in __WORKSPACE__"
# The args file comes with the plugin: core/scripts/plugins/drupal-cms/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/drupal-cms/args/arg-drupal-cms.sh || exit 1 ;

shift $#;

drupal_cms_build ;
