import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';

import { register, assistantContext, PLATFORM, COMMANDS, AGENTS } from '../src/index';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const read = (f: string) => fs.readFileSync(path.join(PKG, f), 'utf8');
const manifest = JSON.parse(read('package.json')).workspacePlugin;

test('the manifest names the platform, and every file it names ships', () => {
  assert.strictEqual(manifest.name, PLATFORM);
  const named = [...manifest.commands.files, ...manifest.scripts.functions, ...manifest.scripts.args, ...manifest.scripts.machine,
    ...manifest.ai.agents, ...manifest.features];
  for (const f of named) assert.ok(fs.existsSync(path.join(PKG, f)), `${f} is in the package`);
  assert.deepStrictEqual(manifest.commands.files.map((f: string) => path.basename(f)), COMMANDS);
  assert.deepStrictEqual(manifest.ai.agents.map((f: string) => path.basename(f, '.md')), AGENTS);
  assert.deepStrictEqual(manifest.commands.types, ['sites'], 'the commands go to sites folders only');
  const files: string[] = JSON.parse(read('package.json')).files;
  for (const f of named) assert.ok(files.includes(f.split('/')[0]), `${f} is published with the package`);
});

test('every command finds the workspace by itself, names its folder, and sources its args from where the installer puts them', () => {
  for (const f of manifest.commands.files) {
    const src = read(f);
    assert.match(src, /^#!\/usr\/bin\/env bash/, `${f} is a bash script`);
    assert.match(src, /WORKSPACE_SCRIPTS="\$\{WORKSPACE_SCRIPTS:-\$\(cd "\$\(dirname "\$\{BASH_SOURCE\[0\]\}"\)\/\.\.\/core\/scripts" && pwd\)\}"/, `${f} locates the tooling from its own path`);
    assert.match(src, /workspace\.__WORKSPACE__\.settings\.yml/, `${f} loads the settings of the folder it is installed into`);
    assert.match(src, /source \$\{WORKSPACE_SCRIPTS\}\/plugins\/drupal-cms\/args\/arg-[a-z-]+\.sh \|\| exit 1 ;/, `${f} reads its arguments from the plugin's args`);
    const last = src.trim().split('\n').pop() as string;
    assert.match(read('scripts/functions/fun-drupal-cms.sh'), new RegExp(`^function ${last.replace(/ ;$/, '')}\\(\\)`, 'm'), `${f} ends by calling a function the plugin defines`);
  }
  assert.match(read('commands/cmd-drupal-cms-project.sh'), /^# workspace-name: Drupal CMS/m, 'the builder carries the name the Build list shows');
  assert.doesNotMatch(read('commands/cmd-tools-drupal-cms-cli.sh'), /^# workspace-name:/m, 'a tool is not a builder');
});

test('every shell script parses', () => {
  for (const f of [...manifest.commands.files, ...manifest.scripts.functions, ...manifest.scripts.args]) {
    const r = spawnSync('bash', ['-n', path.join(PKG, f)], { encoding: 'utf8' });
    assert.strictEqual(r.status, 0, `${f}: ${r.stderr}`);
  }
});

test('the functions carry the names the core\'s tools look for, and never write database settings', () => {
  const src = read('scripts/functions/fun-drupal-cms.sh');
  for (const fn of ['set_drupal_cms_users', 'add_drupal_cms_users', 'cancel_drupal_cms_users', 'testing_configure_drupal_cms', 'drupal_cms_build', 'drupal_cms_cli_tool']) {
    assert.match(src, new RegExp(`^function ${fn}\\(\\) \\{`, 'm'), `${fn} is defined`);
  }
  assert.doesNotMatch(src, /\$databases\[|--db-url/, 'the container tool owns the database settings');
  assert.match(src, /--project-type=drupal /);
  assert.match(src, /--nodejs-version=\$\(ddev_nodejs_version\)/, 'the build runs the Node.js of the workspace rule');
  assert.doesNotMatch(src, /ddev stop -y/, 'ddev stop takes no -y');
});

test('the plugin is the whole of the platform: it calls none of the Drupal functions the workspace base or the Drupal plugin carry', () => {
  const code = read('scripts/functions/fun-drupal-cms.sh').split('\n').filter((l) => !/^\s*#/.test(l)).join('\n');
  for (const fn of ['build_distribution', 'composer_create_project', 'composer_install_retry', 'install_drupal_cms_with_drush', 'enable_drupal_cms_extra_components', 'ddev_telemetry_off',
    'drupal_build', 'drupal_default_users', 'drupal_is_project', 'drupal_add_drush', 'add_drupal_users',
    'add_drush', 'drush_cr', 'drush_set_debug_on', 'set_default_settings', 'load_distribution_users', 'add_users', 'cancel_users']) {
    assert.doesNotMatch(code, new RegExp(`(^|[^a-z_])${fn}([^a-z_]|$)`, 'm'), `${fn} is the base's: the plugin has its own`);
  }
  assert.doesNotMatch(code, /functions\/fun-distribution-|args\/arg-drupal_cms\.sh"? *$/m, 'no file of the base is sourced');
  for (const f of manifest.commands.files) {
    assert.doesNotMatch(read(f), /WORKSPACE_SCRIPTS\}\/args\/|build_distribution/, `${f} uses the plugin's own args and build`);
  }
});

test('no command carries the name of a builder a workspace folder or the Drupal plugin ships', () => {
  for (const c of COMMANDS) {
    assert.doesNotMatch(c, /^cmd-drupal\d.*-recommended-project\.sh$|^cmd-drupalcms|^cmd-drupal-project\.sh$|^cmd-tools-drupal-cli\.sh$/, `${c} is not a folder builder's name, nor the Drupal plugin's`);
  }
});

test('each agent is a definition the AI Agents folder can list: named after its file, described, on the fable model', () => {
  for (const f of manifest.ai.agents) {
    const src = read(f);
    const head = src.split('\n---\n')[0];
    assert.match(head, /^---\n/, `${f} opens with frontmatter`);
    assert.match(head, new RegExp(`^name: ${path.basename(f, '.md')}$`, 'm'));
    assert.match(head, /^description: .{80,}$/m, `${f} says when to use it`);
    assert.match(head, /^model: fable$/m);
    assert.match(head, /^tools:\n(  - \S+\n?)+/m);
    assert.match(src, /cmd-tools-testing\.sh|cmd-drupal-cms-project\.sh/, `${f} names the plugin's commands`);
  }
  const tester = read('agents/drupal-cms-tester.md');
  assert.match(tester, /Never create an account in a suite/);
  assert.match(tester, /No platform name in a step phrase/);
  assert.match(tester, /Playwright MCP browser first/);
});

test('register() adds the assistant context and nothing else', () => {
  const calls: string[] = [];
  const api: any = { name: 'drupal-cms', addAssistantContext: (fn: () => string) => calls.push(fn()) };
  register(api);
  assert.strictEqual(calls.length, 1);
  assert.strictEqual(calls[0], assistantContext());
  for (const c of COMMANDS) assert.ok(calls[0].includes(c), `the assistant is told about ${c}`);
  for (const a of AGENTS) assert.ok(calls[0].includes(a), `the assistant is told about ${a}`);
});

test('the docs say container-based, name only what ships, and carry no personal value', () => {
  const docs = ['README.md', ...manifest.ai.agents, 'scripts/functions/fun-drupal-cms.sh'];
  for (const f of docs) {
    const src = read(f);
    assert.doesNotMatch(src, /DDEV-only/i, `${f}: the workspace is container-based, DDEV by default`);
    assert.doesNotMatch(src, /\/home\/(?!YOUR_USER)[a-z]/, `${f} carries no personal path`);
    const mails = src.match(/[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[a-z]{2,}/g) || [];
    for (const m of mails) assert.match(m, /@example\.(com|org)$/, `${f}: ${m} is not an example address`);
  }
  for (const c of COMMANDS) assert.ok(read('README.md').includes(c), `the README lists ${c}`);
  assert.match(read('README.md'), /^## How this relates to the folder builders$/m);
});
