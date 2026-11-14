#!/usr/bin/env bash

# Drupal CMS for the Webship Workspace: build a Drupal CMS site from a site template, apply add-on
# recipes, run Drush on it, add its default accounts, and wire its step pack into the testing setup.
#
# Placed by `plugins.sh --install drupal-cms` in core/scripts/plugins/drupal-cms/functions/, where
# bootstrap sources it after the core's own functions. Everything runs in the project's container
# (DDEV by default: `ddev composer …`, `ddev drush …`), never on the host. The container tool
# writes the database settings (settings.ddev.php), so nothing here writes a $databases block.
#
# The plugin is the whole of the platform: it builds with its own functions (drupal_cms_*) and
# calls only the workspace's general helpers (trim_project_name, drop_database, ddev_up,
# ddev_nodejs_version). It reads none of the Drupal functions the workspace base still carries,
# and none of the Drupal plugin's: either plugin works without the other.
#
# Four names are the ones the core's tools look for, under the name `drupal_cms`:
#   set_drupal_cms_users           the default accounts          (cmd-tools-add-users.sh <project> drupal_cms)
#   add_drupal_cms_users           create them with Drush        (the same tool, and --add-users of the builder)
#   cancel_drupal_cms_users        delete them                   (cmd-tools-cancel-users.sh <project> drupal_cms)
#   testing_configure_drupal_cms   the step pack in the testing stack (cmd-tools-testing.sh <project>)

# The step pack a Drupal CMS project is tested with, the core pack it loads by itself, and the
# release line both are required at.
readonly DRUPAL_CMS_STEPS_PACKAGE='@webship-js/drupal-cms-steps';
readonly DRUPAL_CMS_STEPS_VERSION='^2.2.0';
readonly DRUPAL_CMS_CORE_STEPS_PACKAGE='@webship-js/drupal-core-steps';
readonly DRUPAL_CMS_CORE_STEPS_VERSION='^2.2.0';

# The project template every Drupal CMS site is created from.
readonly DRUPAL_CMS_PROJECT_TEMPLATE='drupal/cms';

# The default accounts: an administrator, a content editor (the role Drupal CMS creates, with no
# account of its own) and an account with no role, the three a scenario logs in as. Accounts are
# configuration, created once on the site; a test suite never creates or deletes one. `_none_` is
# an account with no role.
function drupal_cms_default_users() {
  users=(administrator content_editor authenticated);
  user_administrator_name="administrator";
  user_administrator_mail="administrator@example.com";
  user_administrator_password="dD.123123ddd";
  user_administrator_role="administrator";
  user_content_editor_name="content_editor";
  user_content_editor_mail="content_editor@example.com";
  user_content_editor_password="dD.123123ddd";
  user_content_editor_role="content_editor";
  user_authenticated_name="authenticated";
  user_authenticated_mail="authenticated@example.com";
  user_authenticated_password="dD.123123ddd";
  user_authenticated_role="_none_";
}

# The name the core's tools ask for the list by.
function set_drupal_cms_users() {
  drupal_cms_default_users ;
}

# Is this folder a Drupal CMS project? Its DDEV project type is Drupal's and its composer.json
# carries the Drupal CMS packages.
function drupal_cms_is_project() {
  local project_path="$1";
  grep -qE '^type:[[:space:]]*"?drupal[0-9]*"?[[:space:]]*$' "${project_path}/.ddev/config.yaml" 2>/dev/null || return 1 ;
  grep -qE '"drupal/(cms|drupal_cms_[a-z0-9_]+)"' "${project_path}/composer.json" 2>/dev/null ;
}

# Go to the project a tool was asked about, or say why not.
function drupal_cms_enter_project() {
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}";
  if [ ! -d "${project_path}" ] ; then
    echo "No project ${PROJECT_NAME} in ${WORKSPACE_ROOT}/${doc_name}." ;
    return 1 ;
  fi
  if ! drupal_cms_is_project "${project_path}" ; then
    echo "${doc_name}/${PROJECT_NAME} is not a Drupal CMS project (its composer.json does not carry the Drupal CMS packages)." ;
    return 1 ;
  fi
  cd "${project_path}" || return 1 ;
}

# What a version asks for: `2.x` (or `2`) is the latest release of that line, `2.2.9` is that
# release, `2.x-dev` is the development branch. Sets drupal_cms_constraint (what composer
# create-project is given) and drupal_cms_stability ('' is composer's own: stable).
function drupal_cms_resolve_version() {
  local version="${1:-2.x}" ;
  drupal_cms_constraint="" ; drupal_cms_stability="" ;
  if [[ "${version}" =~ ^([0-9]+)(\.x)?$ ]] ; then
    drupal_cms_constraint="^${BASH_REMATCH[1]}" ;
  elif [[ "${version}" =~ ^[0-9]+\.x-dev$ ]] ; then
    drupal_cms_constraint="${version}" ;
    drupal_cms_stability="dev" ;
  elif [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta|rc)[0-9]*)?$ ]] ; then
    drupal_cms_constraint="${version}" ;
    drupal_cms_stability="${BASH_REMATCH[2]}" ;
    [ "${drupal_cms_stability}" == 'rc' ] && drupal_cms_stability="RC" ;
  else
    echo "--version ${version} is not a version this builder reads: a release line (2.x), a release (2.2.9) or a development branch (2.x-dev)." ;
    return 1 ;
  fi
  return 0 ;
}

# The add-on recipe a short name stands for: `forms` is drupal_cms_forms, `seo_tools` is
# drupal_cms_seo_tools. A name that already says drupal_cms_ is taken as it is.
function drupal_cms_recipe_name() {
  local name="$1" ;
  case "${name}" in
    drupal_cms_*) printf '%s' "${name}" ;;
    *) printf 'drupal_cms_%s' "${name}" ;;
  esac
}

# The site template a name stands for: `starter` and `blank` are the two Drupal CMS ships or
# names itself (drupal_cms_starter, drupal_cms_blank); any other name is the recipe folder of
# that template, as it is.
function drupal_cms_template_name() {
  local name="$1" ;
  case "${name}" in
    starter|blank) printf 'drupal_cms_%s' "${name}" ;;
    *) printf '%s' "${name}" ;;
  esac
}

# The recipes --recipes asked for, as one name per word: "forms,search" is
# "drupal_cms_forms drupal_cms_search". Nothing for the default.
function drupal_cms_recipe_list() {
  local given="$1" name list="" ;
  [ "${given}" == '_none_' ] && return 0 ;
  for name in ${given//,/ } ; do
    list="${list}${list:+ }$(drupal_cms_recipe_name "${name}")" ;
  done
  printf '%s' "${list}" ;
}

# composer install, once more if it fails: the first install of a fresh project can fail on a
# network or cache hiccup and pass on the second try. A real dependency problem fails both times.
function drupal_cms_composer_install_retry() {
  ddev composer install --no-interaction && return 0 ;
  echo "composer install failed once, trying it again before giving up." ;
  ddev composer install --no-interaction ;
}

# composer create-project in the current project folder, which holds only its .ddev directory.
function drupal_cms_composer_create_project() {
  local package="$1" stability="$2" ;
  if ddev composer create-project "${package}" --no-interaction ${stability:+--stability=${stability}} ; then
    return 0 ;
  fi
  # When the project reached the install step, composer.json is already there: install once more.
  if [ -f composer.json ] && drupal_cms_composer_install_retry ; then
    echo "composer create-project needed a second install, which worked." ;
    return 0 ;
  fi
  return 1 ;
}

# The project template ships a .ddev/config.yaml of its own, which replaces the one the build
# started with: no project name, a database of its choice, sometimes a container tool newer than
# the one on this machine. Put the project's own values back, keep the database the build already
# started, and start again.
function drupal_cms_align_container() {
  local database="$1" php_version="$2" ;
  local settings=(--project-name=${PROJECT_NAME} --project-type=drupal --docroot=web --nodejs-version=$(ddev_nodejs_version)) ;
  [ -n "${database}" ] && settings+=(--database=${database}) ;
  [ -n "${php_version}" ] && settings+=(--php-version=${php_version}) ;
  if ! ddev config "${settings[@]}" ; then
    if grep -q '^ddev_version_constraint:' .ddev/config.yaml 2>/dev/null ; then
      echo "The project template asks for a newer DDEV than this machine has ($(grep '^ddev_version_constraint:' .ddev/config.yaml))." ;
      echo "The line is taken out so this DDEV runs the project. Update DDEV when you can." ;
      sed -i '/^ddev_version_constraint:/d' .ddev/config.yaml ;
      ddev config "${settings[@]}" || return 1 ;
    else
      return 1 ;
    fi
  fi
  drupal_cms_telemetry_off ;
  ddev_up restart ;
}

# A site built here is a local one: keep it out of the install statistics Drupal CMS reports.
function drupal_cms_telemetry_off() {
  ddev config --web-environment-add=DRUPAL_CMS_TELEMETRY=0 > /dev/null ;
}

# `ddev drush` answering. DDEV rewrites its shared command directory whenever any project on the
# machine starts, and `ddev drush` is missing from it for a moment: wait for it, instead of
# failing the install on its first line. Drupal CMS brings Drush with it; an older release that
# does not gets it here.
function drupal_cms_wait_for_drush() {
  local attempt ;
  if [ ! -d vendor/drush/drush ] ; then
    ddev composer require drush/drush --no-interaction || return 1 ;
  fi
  for attempt in 1 2 3 4 5 6 7 8 9 10 ; do
    ddev drush --version > /dev/null 2>&1 && return 0 ;
    echo "ddev drush is not available yet (attempt ${attempt} of 10), waiting." ;
    sleep 6 ;
  done
  echo "ddev drush is still not available." ;
  return 1 ;
}

# composer require, once more if it fails: a site template brings some sixty packages, and one
# download that times out fails the whole command. A package that does not exist fails both times.
function drupal_cms_composer_require_retry() {
  ddev composer require "$@" --with-all-dependencies --no-interaction && return 0 ;
  echo "composer require failed once, trying it again before giving up." ;
  sleep 20 ;
  ddev composer require "$@" --with-all-dependencies --no-interaction ;
}

# A recipe in recipes/, required with composer when it is not there yet. The project template
# brings the installer and no site template, so the Starter template is required here too. The
# package is drupal/<recipe> unless one is named.
function drupal_cms_require_recipe() {
  local recipe="$1" package="${2:-}" ;
  # What a package ships is unpacked into recipes/ by composer; asking again is harmless.
  ddev composer drupal:recipe-unpack --no-interaction > /dev/null 2>&1 || true ;
  [ -d "recipes/${recipe}" ] && return 0 ;
  package="${package:-drupal/${recipe}}" ;
  echo "The ${recipe} recipe is not in recipes/: requiring ${package}." ;
  drupal_cms_composer_require_retry "${package}" || return 1 ;
  ddev composer drupal:recipe-unpack --no-interaction > /dev/null 2>&1 || true ;
  if [ ! -d "recipes/${recipe}" ] ; then
    echo "The ${recipe} recipe is still not in recipes/ after requiring ${package}." ;
    return 1 ;
  fi
}

# Apply add-on recipes to an installed site, one after the other.
function drupal_cms_apply_recipes() {
  local recipe ;
  for recipe in "$@" ; do
    drupal_cms_require_recipe "${recipe}" || return 1 ;
    echo "Applying the ${recipe} recipe." ;
    ddev drush cache:rebuild ;
    ddev drush recipe "/var/www/html/recipes/${recipe}" || { echo "The ${recipe} recipe could not be applied." ; return 1 ; } ;
  done
}

# What the site was built from, kept where the test suite reads it: the environment of the
# project's container (DRUPAL_SITE_TEMPLATE, DRUPAL_CMS_RECIPES). The recipes are separated by
# spaces there, because the container tool splits its own list on commas.
function drupal_cms_record_build() {
  local template="$1" recipes="$2" ;
  [ -n "${template}" ] && ddev config --web-environment-add="DRUPAL_SITE_TEMPLATE=${template}" > /dev/null ;
  [ -n "${recipes}" ] && ddev config --web-environment-add="DRUPAL_CMS_RECIPES=${recipes}" > /dev/null ;
  return 0 ;
}

# The recipes recorded for the project, one per word.
function drupal_cms_recorded_recipes() {
  local project_path="$1" ;
  grep -E '^[[:space:]]*-[[:space:]]*"?DRUPAL_CMS_RECIPES=' "${project_path}/.ddev/config.yaml" 2>/dev/null | head -1 \
    | sed -E 's/^[[:space:]]*-[[:space:]]*"?DRUPAL_CMS_RECIPES=//; s/"?[[:space:]]*$//' ;
}

# The first account of the site is the workspace account. The platform's installer names it and
# sets its password by itself on some releases, whatever the install command was given, so the
# name, the password and the address are set again here. They are handed over on standard input,
# so no character in them is read as code.
function drupal_cms_set_owner() {
  printf '%s\n%s\n%s' "${account_name}" "${account_pass}" "${account_mail}" | ddev drush php:eval '
    $given = explode("\n", stream_get_contents(STDIN));
    $owner = \Drupal\user\Entity\User::load(1);
    if ($owner && count($given) === 3 && $given[0] !== "") {
      $owner->setUsername($given[0])->setPassword($given[1])->setEmail($given[2])->save();
      print "The first account of the site is " . $owner->getAccountName() . ".\n";
    }' ;
}

# Is the site installed and answering Drush?
function drupal_cms_is_installed() {
  ddev drush status --field=bootstrap 2>/dev/null | grep -qi successful ;
}

# Does a role exist on the site?
function drupal_cms_role_exists() {
  ddev drush config:get "user.role.$1" id > /dev/null 2>&1 ;
}

# Does an account exist on the site?
function drupal_cms_user_exists() {
  ddev drush user:information "$1" > /dev/null 2>&1 ;
}

# Build a Drupal CMS site from nothing: the container, the code, and with --install the site
# itself, from the site template and with the add-on recipes that were asked for.
function drupal_cms_build() {
  trim_project_name ;
  local base_url="https://${PROJECT_NAME}.ddev.site" ;
  local version="${VERSION:-${site_version:-2.x}}" ;
  local php_version="${PHP_VERSION:-}" ;

  drupal_cms_resolve_version "${version}" || exit 1 ;
  local package="${DRUPAL_CMS_PROJECT_TEMPLATE}:${drupal_cms_constraint}" ;
  local template ; template="$(drupal_cms_template_name "${TEMPLATE:-starter}")" ;
  local template_package="${TEMPLATE_PACKAGE:-}" ;
  local recipes ; recipes="$(drupal_cms_recipe_list "${RECIPES:-_none_}")" ;

  echo "Drupal CMS for ${doc_name}/${PROJECT_NAME}:" ;
  echo "  code           ${package}${drupal_cms_stability:+ (stability ${drupal_cms_stability})}" ;
  echo "  container      project type drupal, PHP ${php_version:-the one the project template names}, Node.js $(ddev_nodejs_version)" ;
  echo "  site template  ${template}${template_package:+ (from ${template_package})}" ;
  echo "  recipes        ${recipes:-none}" ;
  echo "  install        $([ "${INSTALL}" == 'yes' ] && echo 'yes' || echo 'no')$([ "${ADD_USERS}" == 'yes' ] && echo ', with the default accounts')" ;
  echo "  address        ${base_url}" ;
  if [ "${DRY_RUN}" == 'yes' ] ; then
    echo "A dry run: nothing was built." ;
    return 0 ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name} || exit 1 ;

  drop_database ;
  rm -rf "${PROJECT_NAME}" ;
  mkdir -p "${PROJECT_NAME}" ;
  cd ${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME} || exit 1 ;

  ddev config --project-type=drupal --docroot=web --project-name=${PROJECT_NAME} \
    --nodejs-version=$(ddev_nodejs_version) ${php_version:+--php-version=${php_version}} --auto || { echo "The container could not be configured." ; exit 1 ; } ;
  drupal_cms_telemetry_off ;
  ddev_up start -y || exit 1 ;

  # The database the container started with, before the project template can name another.
  local database ;
  database=$(ddev describe -j 2>/dev/null | python3 -c 'import json, sys
try:
    raw = json.load(sys.stdin)["raw"]
    print("%s:%s" % (raw["database_type"], raw["database_version"]))
except Exception:
    pass' 2>/dev/null) ;

  if ! drupal_cms_composer_create_project "${package}" "${drupal_cms_stability}" ; then
    echo "composer create-project failed for ${package}: the build stops here, nothing was installed." ;
    exit 1 ;
  fi

  drupal_cms_align_container "${database}" "${php_version}" || { echo "The container could not be started again with the project template's configuration." ; exit 1 ; } ;

  if [ "${INSTALL}" == 'yes' ] ; then
    drupal_cms_wait_for_drush || { echo "Drush does not answer: the build stops here." ; exit 1 ; } ;
    drupal_cms_require_recipe "${template}" "${template_package}" || { echo "The site template is not in the code: the build stops here." ; exit 1 ; } ;

    # The installer applies the site template: the form value is the folder name of its recipe.
    if ! ddev drush site:install drupal_cms_installer "installer_site_template_form.add_ons=${template}" --yes \
      --site-name="${doc_name} ${PROJECT_NAME}" \
      --account-name="${account_name}" --account-pass="${account_pass}" --account-mail="${account_mail}" ; then
      echo "The install of ${doc_name} ${PROJECT_NAME} failed: drush site:install did not finish." ;
      echo "The project is kept for a look: ${base_url} (ddev logs, ddev drush status)." ;
      exit 1 ;
    fi
    drupal_cms_set_owner ;
    if ! drupal_cms_is_installed ; then
      echo "${doc_name} ${PROJECT_NAME} was installed, but the site does not bootstrap. Run: ddev drush status ; ddev logs." ;
      exit 1 ;
    fi

    if [ -n "${recipes}" ] ; then
      drupal_cms_apply_recipes ${recipes} || { echo "The site is installed; a recipe was not applied. Apply it again with cmd-tools-drupal-cms-cli.sh ${PROJECT_NAME} --recipe <name>." ; exit 1 ; } ;
    fi
    drupal_cms_record_build "${template}" "${recipes}" ;

    if [ "${ADD_USERS}" == 'yes' ] ; then
      add_drupal_cms_users ;
      cd ${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME} || exit 1 ;
    fi
    ddev drush cache:rebuild ;

    echo "${doc_name} ${PROJECT_NAME} has been installed: Drupal CMS on Drupal $(ddev drush status --field=drupal-version 2>/dev/null), the ${template} site template${recipes:+, with ${recipes}}.";
    echo "Go to ${base_url}/user/login and log in as ${account_name}";
  else
    [ "${ADD_USERS}" == 'yes' ] && echo "--add-users needs --install: there is no site to add accounts to yet." ;
    [ -n "${recipes}" ] && echo "--recipes needs --install: a recipe is applied to an installed site." ;
    echo "${doc_name} ${PROJECT_NAME} is ready to install.";
    echo "Go to ${base_url}";
  fi

  if [ "${LAUNCH}" == 'yes' ] ; then
    ddev launch ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name};
}

# Create the default accounts with Drush. An account that is already there is left as it is, and
# a role the site does not have is said and skipped.
#
# The list is always this plugin's own: the workspace base still carries an older list under the
# same name, and its tools load that one just before they call this function.
function add_drupal_cms_users() {
  drupal_cms_enter_project || return 1 ;
  drupal_cms_default_users ;
  local user user_name user_mail user_password user_role ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    user_password="user_${user}_password"; user_role="user_${user}_role";

    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo "      User mail: ${!user_mail}";
    echo "  User password: ${!user_password}";
    echo "      User role: ${!user_role}";
    echo " ================================================================= ";

    if drupal_cms_user_exists "${!user_name}" ; then
      echo "   ${!user_name} is already there." ;
    else
      ddev drush user:create "${!user_name}" --mail="${!user_mail}" --password="${!user_password}" ;
    fi
    if [ "${!user_role}" == '_none_' ] ; then
      echo "   No role for this account." ;
    elif drupal_cms_role_exists "${!user_role}" ; then
      ddev drush user:role:add "${!user_role}" "${!user_name}" ;
    else
      echo "   The site has no ${!user_role} role: ${!user_name} is left without one." ;
    fi
  done
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# Delete the default accounts, and what they wrote.
function cancel_drupal_cms_users() {
  drupal_cms_enter_project || return 1 ;
  drupal_cms_default_users ;
  local user user_name ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name";
    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo " ================================================================= ";
    if drupal_cms_user_exists "${!user_name}" ; then
      ddev drush user:cancel --delete-content "${!user_name}" --yes ;
    else
      echo "   ${!user_name} is not there." ;
    fi
  done
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# What cmd-tools-drupal-cms-cli.sh does: the first of --run, --recipe, --update, --cache-rebuild,
# --login, --add-users, --cancel-users that was asked for; with none of them, what the site is.
function drupal_cms_cli_tool() {
  trim_project_name ;
  drupal_cms_enter_project || exit 1 ;
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}" ;

  if ! ddev describe -j 2>/dev/null | grep -q '"status":"running"' ; then
    ddev start -y || exit 1 ;
  fi

  if [ ! "${RUN}" == '_none_' ] ; then
    # Handed to the shell of the container as one line, so an argument in quotes stays one
    # argument: --run "sql:query 'select name from users_field_data'".
    ddev exec "drush ${RUN}" ;
    exit $? ;
  fi

  if [ ! "${RECIPE}" == '_none_' ] ; then
    local asked recorded recipe ;
    asked="$(drupal_cms_recipe_list "${RECIPE}")" ;
    drupal_cms_apply_recipes ${asked} || exit 1 ;
    recorded="$(drupal_cms_recorded_recipes "${project_path}")" ;
    for recipe in ${asked} ; do
      case " ${recorded} " in *" ${recipe} "*) : ;; *) recorded="${recorded}${recorded:+ }${recipe}" ;; esac
    done
    drupal_cms_record_build "" "${recorded}" ;
    ddev drush cache:rebuild ;
    echo "Applied: ${asked}. The test suite reads the recipes of the site from the container: ddev restart before the next run." ;
  elif [ "${UPDATE}" == 'yes' ] ; then
    ddev composer update --with-all-dependencies --no-interaction || exit 1 ;
    ddev drush updatedb --yes ;
    ddev drush cache:rebuild ;
  elif [ "${CACHE_REBUILD}" == 'yes' ] ; then
    ddev drush cache:rebuild ;
  elif [ "${LOGIN}" == 'yes' ] ; then
    echo "A one-time login link for the site's first account:" ;
    ddev drush user:login --no-browser ;
  elif [ "${ADD_USERS}" == 'yes' ] ; then
    add_drupal_cms_users ;
  elif [ "${CANCEL_USERS}" == 'yes' ] ; then
    cancel_drupal_cms_users ;
  else
    echo "${doc_name}/${PROJECT_NAME}:" ;
    ddev drush status --fields=drupal-version,uri,install-profile,theme,admin-theme,php-version,db-driver,bootstrap ;
    echo "" ; echo "Site template: $(grep -E 'DRUPAL_SITE_TEMPLATE=' .ddev/config.yaml 2>/dev/null | head -1 | sed -E 's/.*DRUPAL_SITE_TEMPLATE=//; s/"?[[:space:]]*$//')" ;
    echo "Recipes applied with these tools: $(drupal_cms_recorded_recipes "${project_path}")" ;
    echo "" ; echo "Recipes in the code:" ; ls recipes 2>/dev/null | tr '\n' ' ' ; echo "" ;
    echo "" ; echo "Accounts:" ;
    ddev drush sql:query "SELECT u.name, u.mail, COALESCE(GROUP_CONCAT(r.roles_target_id), '') AS roles FROM users_field_data u LEFT JOIN user__roles r ON r.entity_id = u.uid WHERE u.uid > 0 GROUP BY u.uid, u.name, u.mail ORDER BY u.uid" ;
    echo "" ; echo "Pending database updates:" ;
    ddev drush updatedb:status ;
  fi
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# The step pack in the testing stack of a Drupal CMS project. The core's testing_configure calls
# this in the project folder once webship-js is scaffolded and before the dependencies are
# installed; for a project that is not Drupal CMS it changes nothing.
#
# It adds the pack (and the Drupal core pack it depends on) to package.json, lists its step
# definitions in cucumber.js after webship-js's own — the pack loads the core pack by itself, so
# that one is not listed — and gives cucumber.js what the pack reads: the users registry of the
# default accounts (a handle a scenario reads, mapped to an account; never the workspace account),
# the site template and the recipes of the site, the cookie consent and the third-party requests.
# It writes a first feature when the project has none of its own. Every part is skipped when it is
# already there, so a second run adds what the first missed and never resets a suite.
function testing_configure_drupal_cms() {
  local project_path="$1";
  drupal_cms_is_project "${project_path}" || return 0 ;
  if [ ! -f "${project_path}/cucumber.js" ] || [ ! -f "${project_path}/package.json" ] ; then
    echo "  Drupal CMS: cucumber.js is not here yet — run the testing setup again once webship-js is scaffolded." ;
    return 1 ;
  fi

  echo "Adding the Drupal CMS step pack (${DRUPAL_CMS_STEPS_PACKAGE} ${DRUPAL_CMS_STEPS_VERSION}) and the Drupal core pack it uses.";
  drupal_cms_default_users ;
  # handle | the name of its environment variables | account | password | mail | role
  local registry="" user user_name user_password user_mail user_role handle env ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_password="user_${user}_password";
    user_mail="user_${user}_mail"; user_role="user_${user}_role";
    # The pack's features call the accounts "admin", "content editor" and "authenticated".
    case "${user}" in
      administrator) handle="admin" ; env="ADMIN" ;;
      content_editor) handle="content editor" ; env="EDITOR" ;;
      *) handle="${user}" ; env="${user^^}" ;;
    esac
    registry="${registry}${handle}|${env}|${!user_name}|${!user_password}|${!user_mail}|${!user_role}"$'\n' ;
  done

  python3 - "${project_path}" "${DRUPAL_CMS_STEPS_PACKAGE}" "${DRUPAL_CMS_STEPS_VERSION}" \
    "${DRUPAL_CMS_CORE_STEPS_PACKAGE}" "${DRUPAL_CMS_CORE_STEPS_VERSION}" "${registry}" <<'PYEOF' || return 1
import json, re, sys

project, pack, version, core_pack, core_version, registry = sys.argv[1:7]

# package.json: the pack and the core pack it uses as dev dependencies, at the release lines this
# plugin was proven on.
pkg_file = project + '/package.json'
pkg = json.load(open(pkg_file))
changed = False
for name, wanted in ((pack, version), (core_pack, core_version)):
    if name not in pkg.get('dependencies', {}) and name not in pkg.get('devDependencies', {}):
        pkg.setdefault('devDependencies', {})[name] = wanted
        changed = True
        print('  package.json: %s %s' % (name, wanted))
if changed:
    open(pkg_file, 'w').write(json.dumps(pkg, indent=2) + '\n')

# cucumber.js: the pack's step definitions after webship-js's own, and what the pack reads.
cucumber_file = project + '/cucumber.js'
src = open(cucumber_file).read()
before = src

if ('node_modules/%s/' % pack) not in src:
    line = "'node_modules/%s/tests/step-definitions/**/*.js'," % pack
    core = re.search(r"^([ \t]*)'node_modules/webship-js/tests/step-definitions/[^']*',.*$", src, re.M)
    opening = re.search(r"^([ \t]*)require:[ \t]*\[[ \t]*$", src, re.M)
    if core:
        src = src[:core.end()] + '\n' + core.group(1) + line + src[core.end():]
    elif opening:
        src = src[:opening.end()] + '\n' + opening.group(1) + '  ' + line + src[opening.end():]
    else:
        sys.exit("  cucumber.js has no require list this can add to. Add this line to it:\n    " + line)
    print('  cucumber.js: the step definitions of %s' % pack)

world = re.search(r"^([ \t]*)worldParameters:[ \t]*\{[ \t]*$", src, re.M)
block = []
if world:
    pad = world.group(1) + '  '
    if not re.search(r"^[ \t]*siteTemplate:", src, re.M):
        block += [
            pad + "// The site template the site was installed with and the add-on recipes applied to it. The builder",
            pad + "// keeps both in the environment of the project's container; a scenario that needs another",
            pad + "// template or recipe is skipped.",
            pad + "siteTemplate: process.env.DRUPAL_SITE_TEMPLATE || 'drupal_cms_starter',",
            pad + "recipes: (process.env.DRUPAL_CMS_RECIPES || '').split(/[\\s,]+/).filter(Boolean),",
            pad + "// Requests to other hosts are stopped, so a run does not wait for a third party.",
            pad + "blockThirdPartyRequests: process.env.ALLOW_THIRD_PARTY_REQUESTS !== '1',",
            pad + "// The cookie consent is accepted before every scenario, so the notice never covers what a",
            pad + "// scenario clicks; a scenario about the consent resets it with a step.",
            pad + "acceptCookieConsent: process.env.KEEP_COOKIE_CONSENT !== '1',",
        ]
        print('  cucumber.js: the site template, the recipes and the cookie consent')
    if not re.search(r"^[ \t]*users:[ \t]*\{", src, re.M):
        rows = [r.split('|') for r in registry.splitlines() if r.strip()]
        block += [
            pad + "// The users registry: a handle a scenario reads, mapped to an account of this site (the default",
            pad + "// accounts: cmd-tools-add-users.sh). Override one with DRUPAL_<NAME>_USER, DRUPAL_<NAME>_PASS and",
            pad + "// DRUPAL_<NAME>_MAIL (ADMIN, EDITOR, AUTHENTICATED).",
            pad + "users: {",
        ]
        for handle, env, name, password, mail, role in rows:
            key = handle if re.match(r'^[A-Za-z_][A-Za-z0-9_]*$', handle) else "'%s'" % handle
            roles = '[]' if role == '_none_' else "['%s']" % role
            block.append(pad + "  %s: { username: process.env.DRUPAL_%s_USER || '%s', password: process.env.DRUPAL_%s_PASS || '%s', email: process.env.DRUPAL_%s_MAIL || '%s', roles: %s },"
                         % (key, env, name, env, password, env, mail, roles))
        block.append(pad + "},")
        print('  cucumber.js: the users registry (%s)' % ', '.join(r[0] for r in rows))
    if block:
        src = src[:world.end()] + '\n' + '\n'.join(block) + src[world.end():]
elif not re.search(r"^[ \t]*users:[ \t]*\{", src, re.M):
    sys.exit("  cucumber.js has no worldParameters block to add the users registry to.")

if src != before:
    open(cucumber_file, 'w').write(src)
PYEOF

  # A first feature, when the project has none for the site yet: the front page, the login page,
  # each default account, the dashboard, a Canvas page and the cookie consent.
  local feature="${WORKSPACE_SCRIPTS}/plugins/drupal-cms/site.feature" ;
  if [ -f "${feature}" ] && [ ! -f "${project_path}/tests/features/site.feature" ] ; then
    mkdir -p "${project_path}/tests/features" && cp "${feature}" "${project_path}/tests/features/site.feature" \
      && echo "  tests/features/site.feature: a first feature for the site" ;
  fi

  # The scenarios log in as the default accounts: make sure an installed site has them.
  if drupal_cms_is_installed ; then
    ( add_drupal_cms_users > /dev/null ) && echo "  the default accounts are on the site (${users[*]})" ;
  fi
}
