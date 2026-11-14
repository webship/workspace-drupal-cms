#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The name of the project: its folder, its DDEV project and its host name.')
parser.add_argument('-v', '--version',
                    default="${site_version}",
                    help='The Drupal CMS to build: a release line for its latest release (2.x), a release (2.2.9), or a development branch (2.x-dev). Example: --version 2.2.9 [default %(default)s]')
parser.add_argument('-t', '--template',
                    default="starter",
                    help='The site template the installer applies: starter, blank, or the name of another template recipe. Example: --template blank [default %(default)s]')
parser.add_argument('--template-package',
                    default="",
                    help='The composer package of a site template that is not drupal/<its recipe name>. Example: --template-package drupal/haven')
parser.add_argument('-r', '--recipes',
                    default="_none_",
                    help='With --install, add-on recipes to apply after the install, separated by commas; a short name stands for drupal_cms_<name>. Example: --recipes forms,search')
parser.add_argument('-i', '--install',
                    action='store_true',
                    default=False,
                    help='Install the site, with the workspace account as the administrator.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='With --install, add the default accounts: an administrator, a content editor and an account with no role, the ones the test scenarios log in as.')
parser.add_argument('-l', '--launch',
                    action='store_true',
                    default=False,
                    help='Open the site in a browser when it is ready.')
parser.add_argument('--php-version',
                    default="",
                    choices=['8.5', '8.4', '8.3'],
                    help='PHP version for the project container; empty means the one the project template names. Example: --php-version 8.4')
parser.add_argument('--dry-run',
                    action='store_true',
                    default=False,
                    help='Say what would be built (the code, the container, the site template, the recipes) and build nothing.')
ARGEOF
