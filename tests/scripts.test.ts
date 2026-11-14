import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { spawnSync } from 'child_process';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const FUNCTIONS = path.join(PKG, 'scripts', 'functions', 'fun-drupal-cms.sh');

// The cucumber.js webship-js scaffolds, as far as the testing hook reads it.
const SCAFFOLD = `module.exports = {
  default: {
    requireModule: ['ts-node/register'],
    require: [
      'node_modules/webship-js/tests/step-definitions/**/*.js',          // Webship-js core step definitions.
      'tests/step-definitions/**/*.js',                                  // Your custom step definitions.
    ],
    paths: ['tests/features/**/*.feature'],
    worldParameters: {
      launchUrl: process.env.LAUNCH_URL || 'http://localhost:8080',
    },
  },
};
`;

const CMS = { name: 'drupal/cms', require: { 'drupal/drupal_cms_starter': '^2', 'drupal/core-recommended': '^11' } };

/** A project folder with the testing stack scaffolded, and the tooling folder the installer would have filled. */
function project(type: string, composer: Record<string, unknown> = CMS) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'drupal-cms-plugin-'));
  const dir = path.join(root, 'dev', 'site1');
  fs.mkdirSync(path.join(dir, '.ddev'), { recursive: true });
  fs.writeFileSync(path.join(dir, '.ddev', 'config.yaml'), `name: site1\ntype: ${type}\ndocroot: web\n`);
  fs.writeFileSync(path.join(dir, 'composer.json'), JSON.stringify(composer, null, 2));
  fs.writeFileSync(path.join(dir, 'cucumber.js'), SCAFFOLD);
  fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify({ name: 'site1', devDependencies: { 'webship-js': '^2.0.6' } }, null, 2));
  const scripts = path.join(root, 'core', 'scripts');
  fs.mkdirSync(path.join(scripts, 'plugins', 'drupal-cms'), { recursive: true });
  fs.copyFileSync(path.join(PKG, 'testing', 'site.feature'), path.join(scripts, 'plugins', 'drupal-cms', 'site.feature'));
  return { root, dir, scripts };
}

// `ddev` replaced by a recorder: the site is installed, no account is there yet, every role
// exists, `ddev describe -j` names the database the container started with, and a recipe that
// composer requires appears in recipes/.
const DDEV = `ddev() {
  echo "ddev $*" >> "\${DDEV_LOG:-/dev/null}" ;
  [ "$1 $2" == "describe -j" ] && { echo '{"raw":{"status":"running","database_type":"mariadb","database_version":"10.11"}}' ; return 0 ; } ;
  [ "$1 $2 $3" == "drush status --field=bootstrap" ] && { echo Successful ; return 0 ; } ;
  [ "$1 $2" == "drush user:information" ] && return 1 ;
  [ "$1 $2" == "composer create-project" ] && { echo '{"name":"drupal/cms"}' > composer.json ; mkdir -p recipes vendor/drush/drush ; return 0 ; } ;
  [ "$1 $2" == "composer require" ] && { mkdir -p "recipes/\${3#drupal/}" ; return 0 ; } ;
  return 0 ;
}`;

/** Run bash with the plugin's functions sourced and `ddev` replaced by the recorder. */
function bash(script: string, env: Record<string, string> = {}) {
  return spawnSync('bash', ['-c', `${DDEV}\nsource ${FUNCTIONS}\n${script}`], { encoding: 'utf8', env: { ...process.env, ...env } });
}

const HELPERS = 'trim_project_name() { :; } ; ddev_nodejs_version() { echo 24 ; } ; drop_database() { echo DROPPED ; } ; sleep() { :; } ;'
  + ' ddev_up() { mkdir -p .ddev ; [ -f .ddev/config.yaml ] || printf "type: drupal11\\ndocroot: web\\n" > .ddev/config.yaml ; ddev "$@" ; } ;';

test('the default accounts are an administrator, a content editor and an account with no role, with example addresses', () => {
  const r = bash('set_drupal_cms_users ; for u in "${users[@]}" ; do n="user_${u}_name" ; m="user_${u}_mail" ; p="user_${u}_password" ; l="user_${u}_role" ; echo "${!n}|${!m}|${!p}|${!l}" ; done');
  assert.strictEqual(r.status, 0, r.stderr);
  const rows = r.stdout.trim().split('\n').map((l) => l.split('|'));
  assert.deepStrictEqual(rows.map((x) => x[0]), ['administrator', 'content_editor', 'authenticated']);
  assert.deepStrictEqual(rows.map((x) => x[3]), ['administrator', 'content_editor', '_none_']);
  for (const [name, mail, password] of rows) {
    assert.strictEqual(mail, `${name}@example.com`);
    assert.ok(password.length >= 8);
  }
});

test('a version is read as a release line, a release or a development branch', () => {
  const plan = (v: string) => bash(`drupal_cms_resolve_version "${v}" ; echo "rc=$?|$drupal_cms_constraint|$drupal_cms_stability"`).stdout.trim().split('\n').pop();
  assert.strictEqual(plan('2.x'), 'rc=0|^2|');
  assert.strictEqual(plan('2'), 'rc=0|^2|');
  assert.strictEqual(plan('2.2.9'), 'rc=0|2.2.9|');
  assert.strictEqual(plan('2.x-dev'), 'rc=0|2.x-dev|dev');
  assert.strictEqual(plan('3.0.0-beta1'), 'rc=0|3.0.0-beta1|beta');
  assert.match(plan('latest') as string, /^rc=1\|/);
});

test('short names stand for the recipes and the site templates of the platform, and other names are kept', () => {
  assert.strictEqual(bash('drupal_cms_recipe_list forms,search,seo_tools').stdout, 'drupal_cms_forms drupal_cms_search drupal_cms_seo_tools');
  assert.strictEqual(bash('drupal_cms_recipe_list drupal_cms_forms').stdout, 'drupal_cms_forms');
  assert.strictEqual(bash('drupal_cms_recipe_list _none_').stdout, '');
  assert.strictEqual(bash('drupal_cms_template_name starter').stdout, 'drupal_cms_starter');
  assert.strictEqual(bash('drupal_cms_template_name blank').stdout, 'drupal_cms_blank');
  assert.strictEqual(bash('drupal_cms_template_name my_template').stdout, 'my_template');
});

test('a dry run says what would be built and touches nothing', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'drupal-cms-plugin-'));
  fs.mkdirSync(path.join(root, 'dev'));
  const log = path.join(root, 'ddev.log');
  const r = bash(`${HELPERS} PROJECT_NAME=site1 ; VERSION=2.x ; TEMPLATE=blank ; RECIPES=forms,search ; INSTALL=yes ; ADD_USERS=yes ; DRY_RUN=yes ; drupal_cms_build`,
    { WORKSPACE_ROOT: root, doc_name: 'dev', DDEV_LOG: log });
  assert.strictEqual(r.status, 0, r.stderr);
  assert.match(r.stdout, /code +drupal\/cms:\^2\n/);
  assert.match(r.stdout, /site template +drupal_cms_blank\n/);
  assert.match(r.stdout, /recipes +drupal_cms_forms drupal_cms_search\n/);
  assert.match(r.stdout, /install +yes, with the default accounts/);
  assert.match(r.stdout, /A dry run: nothing was built\./);
  assert.doesNotMatch(r.stdout, /DROPPED/);
  assert.ok(!fs.existsSync(path.join(root, 'dev', 'site1')));
  assert.ok(!fs.existsSync(log), 'the container tool was not called');
});

test('a build creates the code, keeps the project\'s own container values, installs from the site template, applies the recipes and adds the accounts', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'drupal-cms-plugin-'));
  fs.mkdirSync(path.join(root, 'dev'));
  const log = path.join(root, 'ddev.log');
  const r = bash(`${HELPERS} PROJECT_NAME=site1 ; VERSION=2.x ; TEMPLATE=blank ; RECIPES=forms,search ; INSTALL=yes ; ADD_USERS=yes ; account_name=owner ; account_pass=secret ; account_mail=owner@example.com ; drupal_cms_build`,
    { WORKSPACE_ROOT: root, doc_name: 'dev', DDEV_LOG: log });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const calls = fs.readFileSync(log, 'utf8');
  assert.match(calls, /ddev config --project-type=drupal --docroot=web --project-name=site1 --nodejs-version=24 --auto/);
  assert.match(calls, /ddev config --web-environment-add=DRUPAL_CMS_TELEMETRY=0/);
  assert.match(calls, /ddev composer create-project drupal\/cms:\^2 --no-interaction\n/);
  assert.match(calls, /ddev config --project-name=site1 --project-type=drupal --docroot=web --nodejs-version=24 --database=mariadb:10\.11\n/, 'after the template replaced the configuration');
  assert.match(calls, /ddev composer require drupal\/drupal_cms_blank --with-all-dependencies --no-interaction/, 'a template that is not in the code is required');
  assert.match(calls, /ddev drush site:install drupal_cms_installer installer_site_template_form\.add_ons=drupal_cms_blank --yes --site-name=dev site1 --account-name=owner --account-pass=secret --account-mail=owner@example\.com/);
  assert.doesNotMatch(calls, /db-url/);
  assert.match(calls, /ddev drush php:eval[\s\S]*User::load\(1\)[\s\S]*setUsername/, 'the first account is set to the workspace account after the install');
  const owner = calls.slice(calls.indexOf('ddev drush php:eval')).split('\nddev ')[0];
  assert.doesNotMatch(owner, /secret|owner@example/, 'its values are handed over on standard input, not on the command line');
  assert.match(calls, /ddev drush recipe \/var\/www\/html\/recipes\/drupal_cms_forms\n/);
  assert.match(calls, /ddev drush recipe \/var\/www\/html\/recipes\/drupal_cms_search\n/);
  assert.match(calls, /ddev config --web-environment-add=DRUPAL_SITE_TEMPLATE=drupal_cms_blank\n/);
  assert.match(calls, /ddev config --web-environment-add=DRUPAL_CMS_RECIPES=drupal_cms_forms drupal_cms_search\n/, 'kept where the suite reads it');
  assert.match(calls, /ddev drush user:create content_editor --mail=content_editor@example\.com/);
  assert.match(calls, /ddev drush user:role:add content_editor content_editor/);
  assert.doesNotMatch(calls, /user:role:add \S+ authenticated/, 'the account with no role gets none');
});

test('a template that asks for a newer container tool has that line taken out, and the build goes on', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'drupal-cms-plugin-'));
  const dir = path.join(root, 'site1');
  fs.mkdirSync(path.join(dir, '.ddev'), { recursive: true });
  fs.writeFileSync(path.join(dir, '.ddev', 'config.yaml'), 'type: drupal11\nddev_version_constraint: ">= 1.25.0"\n');
  const r = bash(`cd ${dir} ; ${HELPERS} PROJECT_NAME=site1 ;`
    + ' real_ddev=$(declare -f ddev) ; eval "recorded_${real_ddev}" ;'
    + ' ddev() { recorded_ddev "$@" ; if [ "$1" == config ] && [[ "$2" == --project-name=* ]] && grep -q ddev_version_constraint .ddev/config.yaml ; then return 1 ; fi ; return 0 ; } ;'
    + ' drupal_cms_align_container mariadb:10.11 ""', { DDEV_LOG: path.join(root, 'ddev.log') });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  assert.match(r.stdout, /asks for a newer DDEV than this machine has/);
  assert.doesNotMatch(fs.readFileSync(path.join(dir, '.ddev', 'config.yaml'), 'utf8'), /ddev_version_constraint/);
});

test('a site template whose download fails once is required a second time', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'drupal-cms-plugin-'));
  const log = path.join(root, 'ddev.log');
  const r = bash(`cd ${root} ; sleep() { :; } ; real_ddev=$(declare -f ddev) ; eval "recorded_\${real_ddev}" ;`
    + ' ddev() { if [ "$1 $2" == "composer require" ] && [ ! -f failed-once ] ; then echo "ddev $*" >> "${DDEV_LOG}" ; touch failed-once ; return 1 ; fi ; recorded_ddev "$@" ; } ;'
    + ' drupal_cms_require_recipe drupal_cms_starter', { DDEV_LOG: log });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  assert.match(r.stdout, /composer require failed once, trying it again/);
  assert.strictEqual(fs.readFileSync(log, 'utf8').split('ddev composer require drupal/drupal_cms_starter').length - 1, 2);
  assert.ok(fs.existsSync(path.join(root, 'recipes', 'drupal_cms_starter')));
});

test('the accounts are this plugin\'s own even after the base loaded its older list under the same name', () => {
  const p = project('drupal11');
  const log = path.join(p.root, 'ddev.log');
  const r = bash('set_drupal_cms_users() { users=(old) ; user_old_name="Old" ; } ; set_drupal_cms_users ; add_drupal_cms_users > /dev/null ; echo "${users[*]}"',
    { WORKSPACE_ROOT: p.root, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log });
  assert.strictEqual(r.stdout.trim(), 'administrator content_editor authenticated');
  assert.doesNotMatch(fs.readFileSync(log, 'utf8'), /user:create Old/);
});

test('the testing hook adds both packs, lists only the Drupal CMS one, and writes what it reads, once', () => {
  const p = project('drupal11');
  const log = path.join(p.root, 'ddev.log');
  const run = () => bash(`cd ${p.dir} && testing_configure_drupal_cms ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log });
  const r = run();
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const pkg = JSON.parse(fs.readFileSync(path.join(p.dir, 'package.json'), 'utf8'));
  assert.strictEqual(pkg.devDependencies['@webship-js/drupal-cms-steps'], '^2.2.0');
  assert.strictEqual(pkg.devDependencies['@webship-js/drupal-core-steps'], '^2.2.0', 'the core pack it depends on');
  assert.strictEqual(pkg.devDependencies['webship-js'], '^2.0.6', 'what was there stays');
  const cucumber = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  const lines = cucumber.split('\n');
  const core = lines.findIndex((l) => l.includes('node_modules/webship-js/tests/step-definitions'));
  assert.strictEqual(lines[core + 1], "      'node_modules/@webship-js/drupal-cms-steps/tests/step-definitions/**/*.js',", 'the pack is listed right after webship-js');
  assert.doesNotMatch(cucumber, /node_modules\/@webship-js\/drupal-core-steps\//, 'the Drupal CMS pack loads the core pack by itself: listing it would define every step twice');
  assert.match(cucumber, /admin: \{ username: process\.env\.DRUPAL_ADMIN_USER \|\| 'administrator', password: process\.env\.DRUPAL_ADMIN_PASS \|\| '[^']+', email: process\.env\.DRUPAL_ADMIN_MAIL \|\| 'administrator@example\.com', roles: \['administrator'\] \},/);
  assert.match(cucumber, /'content editor': \{ username: process\.env\.DRUPAL_EDITOR_USER \|\| 'content_editor'.*roles: \['content_editor'\] \},/);
  // Still a module node can load, with everything where the pack reads it.
  const read = (env: Record<string, string>) => {
    const loaded = spawnSync(process.execPath, ['-e', `const c = require(${JSON.stringify(path.join(p.dir, 'cucumber.js'))}).default; const w = c.worldParameters; console.log(JSON.stringify([c.require, Object.keys(w.users), w.siteTemplate, w.recipes, w.acceptCookieConsent, w.blockThirdPartyRequests]))`],
      { encoding: 'utf8', env: { ...process.env, ...env } });
    assert.strictEqual(loaded.status, 0, loaded.stderr);
    return JSON.parse(loaded.stdout);
  };
  const [requires, handles, template, recipes, consent, block] = read({});
  assert.strictEqual(requires.length, 3);
  assert.deepStrictEqual(handles, ['admin', 'content editor', 'authenticated']);
  assert.strictEqual(template, 'drupal_cms_starter');
  assert.deepStrictEqual(recipes, []);
  assert.strictEqual(consent, true);
  assert.strictEqual(block, true);
  const built = read({ DRUPAL_SITE_TEMPLATE: 'drupal_cms_blank', DRUPAL_CMS_RECIPES: 'drupal_cms_forms drupal_cms_search' });
  assert.strictEqual(built[2], 'drupal_cms_blank');
  assert.deepStrictEqual(built[3], ['drupal_cms_forms', 'drupal_cms_search'], 'what the builder recorded, separated by spaces');
  assert.ok(fs.existsSync(path.join(p.dir, 'tests', 'features', 'site.feature')));
  assert.match(fs.readFileSync(log, 'utf8'), /ddev drush user:create content_editor --mail=content_editor@example\.com/, 'an installed site gets the default accounts');
  // Again, after a person changed the feature: nothing is doubled, nothing is reset.
  fs.writeFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'Feature: mine\n');
  assert.strictEqual(run().status, 0);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), cucumber);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'utf8'), 'Feature: mine\n');
});

test('the testing hook leaves alone a Drupal core site and a project of another platform', () => {
  for (const p of [project('drupal11', { require: { 'drupal/core-recommended': '^11' } }), project('wordpress')]) {
    const r = bash(`cd ${p.dir} && testing_configure_drupal_cms ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1' });
    assert.strictEqual(r.status, 0);
    assert.strictEqual(r.stdout, '');
    assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), SCAFFOLD);
    assert.ok(!fs.existsSync(path.join(p.dir, 'tests')));
  }
});

test('the Drush tool refuses a project that is not Drupal CMS, runs a command, and applies and records a recipe', () => {
  const other = project('drupal11', { require: { 'drupal/core-recommended': '^11' } });
  const refused = bash('PROJECT_NAME=site1 ; RUN="pm:list" ; trim_project_name() { :; } ; drupal_cms_cli_tool', { WORKSPACE_ROOT: other.root, doc_name: 'dev' });
  assert.strictEqual(refused.status, 1);
  assert.match(refused.stdout, /is not a Drupal CMS project/);
  const p = project('drupal11');
  const log = path.join(p.root, 'ddev.log');
  const ran = bash('PROJECT_NAME=site1 ; RUN="pm:list --status=enabled" ; trim_project_name() { :; } ; drupal_cms_cli_tool', { WORKSPACE_ROOT: p.root, doc_name: 'dev', DDEV_LOG: log });
  assert.strictEqual(ran.status, 0, ran.stderr);
  assert.match(fs.readFileSync(log, 'utf8'), /ddev exec drush pm:list --status=enabled\n/);
  fs.appendFileSync(path.join(p.dir, '.ddev', 'config.yaml'), 'web_environment:\n    - DRUPAL_CMS_RECIPES=drupal_cms_forms\n');
  const applied = bash('PROJECT_NAME=site1 ; RUN=_none_ ; RECIPE=search,forms ; trim_project_name() { :; } ; drupal_cms_cli_tool', { WORKSPACE_ROOT: p.root, doc_name: 'dev', DDEV_LOG: log });
  assert.strictEqual(applied.status, 0, applied.stderr + applied.stdout);
  const calls = fs.readFileSync(log, 'utf8');
  assert.match(calls, /ddev composer require drupal\/drupal_cms_search --with-all-dependencies --no-interaction/);
  assert.match(calls, /ddev drush recipe \/var\/www\/html\/recipes\/drupal_cms_search\n/);
  assert.match(calls, /ddev config --web-environment-add=DRUPAL_CMS_RECIPES=drupal_cms_forms drupal_cms_search\n/, 'added to what was recorded, nothing twice');
});

test('the first feature names no platform in a step, and no password', () => {
  const feature = fs.readFileSync(path.join(PKG, 'testing', 'site.feature'), 'utf8');
  const steps = feature.split('\n').filter((l) => /^\s*(Given|When|Then|And|But) /.test(l));
  assert.ok(steps.length >= 10);
  for (const s of steps) assert.doesNotMatch(s.replace(/"[^"]*"/g, '""'), /drupal/i, s);
  assert.doesNotMatch(feature, /password "/);
  assert.doesNotMatch(feature, /user:create|I register|testing users/i, 'a suite never creates an account');
});
