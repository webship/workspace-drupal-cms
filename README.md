# @webship.co/workspace-drupal-cms

Drupal CMS for the [Webship Workspace](https://github.com/webship/workspace) dashboard: one builder
that makes a real Drupal CMS site in a container (a release, a site template, add-on recipes), a
Drush tool for the sites it built, the default accounts, the
[Drupal CMS step pack](https://github.com/webship/drupal-cms-steps) wired into the workspace's
testing setup, and two AI agents that know all of it.

The workspace is container-based (DDEV by default): a Drupal CMS project is a row like any other, so
the row menus the core draws (start, stop, launch, backup, clone, remove, tests) work on it unchanged.

It is made from the reference platform plugin,
[`@webship.co/workspace-wordpress`](https://github.com/webship/workspace-wordpress), and it is the
whole of the platform: the build, the accounts and the testing hook are the plugin's own functions.

## Use it

```bash
cd ~/workspace
bash core/scripts/plugins.sh --require github:webship/workspace-drupal-cms   # npm install into the dashboard
bash core/scripts/plugins.sh --activate drupal-cms                            # plugins.drupal-cms in settings.yml
bash core/scripts/plugins.sh --install drupal-cms                             # commands, functions, args, agents
bash core/scripts/plugins.sh --configure drupal-cms                           # nothing to configure: it has no settings file
```

The same four steps are buttons on the dashboard's **Settings → Plugins** page. `--install` is
idempotent. `--uninstall` removes what it placed; an agent you edited stays.

The commands land in the sites folders that are in the workspace (`dev`, `test`, `sandboxes`,
`demos`); the agents land in the AI Agents folder (`ai-agents/`) when the workspace has one, and are
installed into `~/.claude/agents` from there like any other agent.

It needs a Webship Workspace 1.0.7 or later.

## What it needs

A workspace starts empty, so the manifest says what else this plugin needs (`needs`):

- one sites folder, for the builder and the tool: `dev`, `test`, `sandboxes`, `demos` (`dev` is the one added when none is there). The folder also carries `cmd-tools-testing.sh` and the Users tools this plugin's hooks answer to.
- `ai-agents`, the AI Agents folder its two agents are placed in.

`--require` says so, `--activate` and `--install` stop until the workspace has them, and `--with-needs` adds what is missing first:

```bash
bash core/scripts/plugins.sh --activate drupal-cms --with-needs   # dev and ai-agents are required, activated and installed first
bash core/scripts/plugins.sh --install drupal-cms
```

Everything the builder runs for a site runs in the site's own container, through the container tool the workspace already needs; the plugin asks for no command of its own on the machine.

A workspace that knows none of this (Webship Workspace 1.0.8 and older) ignores the keys: add a sites folder and the AI Agents folder yourself, then `--install drupal-cms` again.

## What the package holds

| Path | What it is |
| --- | --- |
| `commands/cmd-drupal-cms-project.sh` | The builder, in the Build list as **Drupal CMS (a site template and recipes)**, installed into every sites folder |
| `commands/cmd-tools-drupal-cms-cli.sh` | Drush for one project: what the site is, a command, an add-on recipe, updates, the cache, a one-time login link, the default accounts |
| `scripts/functions/fun-drupal-cms.sh` | The bash functions behind both, sourced by bootstrap once installed; the names the core's tools look for (`set_drupal_cms_users`, `add_drupal_cms_users`, `cancel_drupal_cms_users`, `testing_configure_drupal_cms`) |
| `scripts/args/arg-drupal-cms.sh`, `arg-drupal-cms-cli.sh` | Their argparse; the Build form draws the builder's flags from the first |
| `testing/site.feature` | The first feature a Drupal CMS project gets when testing is set up |
| `agents/drupal-cms-site-builder.md` | The agent that builds and maintains Drupal CMS sites with these commands |
| `agents/drupal-cms-tester.md` | The agent that writes and runs scenarios with the Drupal CMS step pack |
| `src/index.ts` | `register(api)`: what the assistant is told about Drupal CMS here |
| `features/drupal-cms.feature` | Scenarios for the dashboard's own browser suite |

The `workspacePlugin` block in `package.json` is the manifest the installer reads. The plugin is
`drupal-cms`; its functions and its user list are called `drupal_cms`, because a bash function name
takes no hyphen.

## How this relates to the folder builders

The sites folders (`dev`, `test`, `sandboxes`, `demos`) are plugins too, and they place builders of
their own: `cmd-drupalcms2-x-project.sh` and `cmd-drupalcms2-1-0-project.sh`, one file per release.
Those builders call build functions that the workspace base still carries, and they install the
Starter template only. This plugin does not move, replace or change any of them, and a workspace
that never installs it works as before.

This plugin sits beside them as the platform's own package:

- **One builder, with arguments.** `cmd-drupal-cms-project.sh <name> --version … --template …
  --recipes …` is one file for every release, site template and set of add-on recipes. Its name
  collides with no file a folder places, so both sets are in the Build list of a folder at the same
  time and `--uninstall` leaves the folder's files as they were.
- **Its own functions.** The build (`drupal_cms_build`), the accounts and the testing hook are in
  `fun-drupal-cms.sh`. They call only the workspace's general helpers (the project name, the clean
  slate of a rebuild, the start of the container, the Node.js of the workspace) and none of the
  Drupal functions of the base, so the base can drop its own later without touching this plugin.
- **One shared name, on purpose.** The core's account tools look for `add_<name>_users` and
  `cancel_<name>_users`. With this plugin installed, `cmd-tools-add-users.sh <project> drupal_cms`
  and `--add-users` of a folder builder for Drupal CMS add **this plugin's accounts** (below) in
  place of the base's older list. Uninstall the plugin and the older list is back.
- **The testing setup.** The base adds no step pack to a Drupal project. With this plugin,
  `cmd-tools-testing.sh <project>` adds the Drupal CMS step pack to a Drupal CMS site, whichever
  builder made it.

### And the Drupal plugin

[`@webship.co/workspace-drupal`](https://github.com/webship/workspace-drupal) is the plugin for a
Drupal core site. The two are independent: either works without the other, and neither calls a
function of the other.

- **Each has its Drush tool.** `cmd-tools-drupal-cms-cli.sh` is this plugin's, so the platform is
  complete with this plugin alone; it also applies add-on recipes (`--recipe`), which the Drupal
  plugin's tool does not. With both installed, `cmd-tools-drupal-cli.sh` works on a Drupal CMS site
  too, since it works on any Drupal project.
- **Each tests its own sites.** The Drupal plugin's testing hook leaves a Drupal CMS site alone, and
  this one leaves a Drupal core site alone. The Drupal CMS step pack loads the Drupal core pack by
  itself, so `cucumber.js` lists the Drupal CMS pack only; both packs are in `package.json`.

## The commands

Run them from a sites folder. `--help` is safe on both.

### Build a site

```bash
cd ~/workspace/dev
bash cmd-drupal-cms-project.sh mysite --install --add-users
bash cmd-drupal-cms-project.sh mysite --recipes forms,search --install --add-users
bash cmd-drupal-cms-project.sh mysite --template blank --install
bash cmd-drupal-cms-project.sh mysite --version 2.2.9 --dry-run        # what would be built, and nothing built
```

| Flag | What it does |
| --- | --- |
| `--version <x>` | A release line for its latest release (`2.x`, the default), a release (`2.2.9`) or a development branch (`2.x-dev`) |
| `--template <name>` | The site template the installer applies: `starter` (the default, `drupal_cms_starter`), `blank` (`drupal_cms_blank`), or the recipe name of another template |
| `--template-package <package>` | The composer package of a template that is not `drupal/<its recipe name>` |
| `--recipes <names>` | With `--install`: add-on recipes applied after the install, separated by commas; `forms` stands for `drupal_cms_forms` |
| `--install` | Install the site, with the workspace account as its administrator |
| `--add-users` | With `--install`: add the default accounts |
| `--php-version <x>` | The PHP of the project container; empty is the one the project template names |
| `--dry-run` | Say the code, the container, the site template and the recipes, and build nothing |
| `--launch` | Open the site when it is ready |

The site answers at `https://mysite.ddev.site`, the login at `/user/login`, the dashboard at
`/admin/dashboard`. The build runs `ddev config` with the Node.js of the workspace (24), creates the
code from `drupal/cms` with composer in the container, and installs with Drush through the
platform's own installer, which applies the site template. The database settings are the container
tool's (`settings.ddev.php`): the build writes none and hands the installer no database address.
A project of the same name is deleted first. The platform's installer names the first account and
sets its password by itself on some releases; the build sets the name, the password and the
address of the workspace account again once the site is installed.

The project template ships a container configuration of its own. After the code is there, the
build puts the project's name back, keeps the database the container started with, and starts
again. When the template asks for a newer container tool than the machine has, the build takes
that line out, says so, and goes on.

The project template brings the installer and no site template, so the build requires the
template's package with composer before the install: `drupal/<its recipe name>` (the Starter
template is `drupal/drupal_cms_starter`), or the package `--template-package` names. Only what
composer can require without an account anywhere: no marketplace, no key.

A site built here is a local one: the build keeps it out of the install statistics the platform
reports (`DRUPAL_CMS_TELEMETRY=0` in the project's container). It also keeps the site template and
the recipes of the build there (`DRUPAL_SITE_TEMPLATE`, `DRUPAL_CMS_RECIPES`), which is where the
test suite reads them.

### Work on a site

```bash
bash cmd-tools-drupal-cms-cli.sh mysite                                    # version, template, recipes, accounts, pending updates
bash cmd-tools-drupal-cms-cli.sh mysite --recipe forms,search              # apply add-on recipes
bash cmd-tools-drupal-cms-cli.sh mysite --run "pm:list --status=enabled"
bash cmd-tools-drupal-cms-cli.sh mysite --update                           # composer update, the database updates, the cache
bash cmd-tools-drupal-cms-cli.sh mysite --cache-rebuild
bash cmd-tools-drupal-cms-cli.sh mysite --login                            # a one-time login link
bash cmd-tools-drupal-cms-cli.sh mysite --add-users                        # the default accounts
bash cmd-tools-drupal-cms-cli.sh mysite --cancel-users                     # delete them, and what they wrote
```

The tool works on any Drupal CMS project of the folder, whichever builder made it.

### The default accounts

| Account | Role | Handle in the tests |
| --- | --- | --- |
| `administrator` | administrator | `admin` |
| `content_editor` | content_editor | `content editor` |
| `authenticated` | none | `authenticated` |

Each has the address `<account>@example.com` and the password of the workspace's other default
lists. They are for local sites and for tests; the site's own administrator is the workspace
account and is never written into a test. `bash cmd-tools-add-users.sh mysite drupal_cms` and
`bash cmd-tools-cancel-users.sh mysite drupal_cms` add and remove the same list. The row's Users menu
names this list for a Drupal CMS site once the workspace carries
[webship/workspace#178](https://github.com/webship/workspace/issues/178); a Workspace 1.0.7 names
another one there, so use the commands.

### Test a site

```bash
bash cmd-tools-testing.sh mysite                 # webship-js, the step packs, the users registry, a first feature
bash cmd-tools-testing.sh mysite --run           # run the suite in the container
bash cmd-tools-testing.sh mysite --run --path tests/features/site.feature
```

`cmd-tools-testing.sh` is the workspace's own. For a Drupal CMS project it also adds
`@webship-js/drupal-cms-steps` and the `@webship-js/drupal-core-steps` it depends on to
`package.json`, lists the Drupal CMS pack's step definitions in `cucumber.js` after webship-js's
own, writes what the pack reads (the users registry with the handles above, overridable with
`DRUPAL_<NAME>_USER`, `DRUPAL_<NAME>_PASS` and `DRUPAL_<NAME>_MAIL` for `ADMIN`, `EDITOR` and
`AUTHENTICATED`; the site template and the recipes; the cookie consent accepted before every
scenario), places `tests/features/site.feature` when the project has none, and makes sure the
default accounts are on the site. Run it again and it adds what is missing and keeps what you
changed.

**What was proven.** A site was built, installed and tested with this builder (Drupal CMS 2.2.9 on
Drupal 11.4.12, the Starter template with the Forms and Search recipes, PHP 8.3, DDEV 1.24.7): the
site answers, the accounts log in, the first feature is green. The Blank template and a template
of another package were not built: what is verified for them is the plan the builder makes
(`--dry-run`) and the unit tests.

The first feature covers the front page, the login page, each default account, the dashboard, the
home page as a page of the page builder (on the Starter template; skipped on another) and the
consent notice.

## The agents

| Agent | Use it to |
| --- | --- |
| `drupal-cms-site-builder` | Build, update, maintain or remove a Drupal CMS site with the commands above, in containers only |
| `drupal-cms-tester` | Set the testing stack up, look at the site in the Playwright MCP browser first, write scenarios from the packs' steps and run them; it never creates an account in a suite and never writes a platform name into a step phrase |

After `--install` they are in the AI Agents folder of the dashboard; **Install** there puts one into
`~/.claude/agents`, or from the command line:

```bash
cd ~/workspace/ai-agents
bash cmd-tools-ai-items.sh drupal-cms-tester --install
```

## Develop it

```bash
npm install     # builds dist/ (TypeScript)
npm run lint
npm test        # the manifest, the commands, the agents, the functions against a scaffolded project
```
