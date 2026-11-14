#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The Drupal CMS project in this workspace.')
parser.add_argument('-r', '--run',
                    default="_none_",
                    help='A Drush command to run in the project, without the leading drush. Example: --run "pm:list --status=enabled"')
parser.add_argument('-R', '--recipe',
                    default="_none_",
                    help='Add-on recipes to apply to the site, separated by commas; a short name stands for drupal_cms_<name>. Example: --recipe forms,search')
parser.add_argument('-u', '--update',
                    action='store_true',
                    default=False,
                    help='Update the code with composer, run the database updates and rebuild the cache.')
parser.add_argument('-b', '--cache-rebuild',
                    action='store_true',
                    default=False,
                    help='Rebuild the cache, and nothing else.')
parser.add_argument('-l', '--login',
                    action='store_true',
                    default=False,
                    help='Print a one-time login link for the first account of the site.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='Add the default accounts. An account that is already there is left as it is.')
parser.add_argument('-c', '--cancel-users',
                    action='store_true',
                    default=False,
                    help='Delete the default accounts and what they wrote.')
ARGEOF
