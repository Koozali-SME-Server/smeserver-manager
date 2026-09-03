# SrvMngr — OpenCode Instructions

## 1. Project Overview

This repository contains **SrvMngr**, a Mojolicious-based web application used as part of the SME Server management interface.

The repository is also a packaging/install tree. The application itself is primarily located under:

    root/usr/share/smanager/

Do not assume that all files in the repository are application source code. Some directories contain packaging files, system configuration, e-smith templates, systemd configuration, or other files that are installed onto an SME Server system.

SrvMngr is a mature application. Prefer understanding and preserving existing behaviour over introducing architectural changes or modernising code unnecessarily.

---

## 2. Important Repository Structure

### Application

    root/usr/share/smanager/

This is the main SrvMngr application.

Its principal components are:

    conf/
    lib/
    script/
    t/
    themes/

### Perl Application Code

    root/usr/share/smanager/lib/SrvMngr/

Main namespaces include:

    Controller/
    Model/
    Plugin/
    I18N/

`Controller/` contains the Mojolicious controllers.

`Model/` contains application models and data-access/application-domain code.

`Plugin/` contains Mojolicious/application plugins.

`I18N/` contains internationalisation support.

### Internationalisation

    root/usr/share/smanager/lib/SrvMngr/I18N/
    root/usr/share/smanager/lib/SrvMngr/I18N/Modules/

The `Modules/` directory contains translations associated with individual application modules, including areas such as:

    Backup
    Bugreport
    Clamav
    Datetime
    Directory
    Dnf
    Domains
    Emailsettings
    General
    Groups
    Hostentries
    Ibays
    Initial
    Localnetworks
    Login
    Mailanalog
    Manual
    Portforwarding
    Printers
    Proxy
    Pseudonyms
    Quota
    Reboot
    Remoteaccess
    Review
    Roundcubepanel
    Support
    Swttheme
    Useraccounts
    Userpassword
    Viewlogfiles
    Workgroup
    Yum

Do not assume that an I18N module corresponds exactly to a controller. Verify relationships from the source when necessary.

### Templates and Theme

The default theme is:

    root/usr/share/smanager/themes/default/

Its templates are under:

    root/usr/share/smanager/themes/default/templates/

with shared:

    layouts/
    partials/

The default theme also contains:

    public/css/
    public/images/
    public/js/

When investigating a controller action, follow the actual rendering logic to determine which template, layout and partials are involved.

### Tests

    root/usr/share/smanager/t/

Tests for the application are located here.

When modifying existing behaviour, look for relevant tests before making changes and add or update tests where appropriate.

### Configuration

Application configuration is primarily associated with:

    root/usr/share/smanager/conf/

There are also system/application configuration files elsewhere in the repository, particularly below:

    root/etc/

Do not confuse packaging/system configuration with the application's own configuration.

---

## 3. Packaging and System Integration

The repository contains files that are installed outside the application directory.

Important areas include:

    root/etc/e-smith/
    root/etc/logrotate.d/
    root/usr/lib/systemd/system/
    additional/

The `root/etc/e-smith/` tree contains SME Server/e-smith configuration, events, templates, localisation and web integration.

The `additional/` directory contains additional installation/configuration material.

When investigating application behaviour, do not automatically scan these areas. Inspect them when the functionality being investigated indicates that the application integrates with the SME Server configuration/event/template system.

---

## 4. Mojolicious Application Structure

SrvMngr is a Mojolicious application.

When investigating a web request or feature, generally follow this path:

    route
      ↓
    controller
      ↓
    controller action
      ↓
    model / plugin / other service code
      ↓
    render()
      ↓
    template
      ↓
    layout / partials
      ↓
    browser

The actual implementation may differ. Treat this as a starting model, not an assumption.

Always verify relationships from the source code.

---

## 5. Exploration Guidelines

### Prefer targeted exploration

Do not routinely scan all controllers, templates or modules for a task concerning one feature.

For a task involving a particular controller:

1. Inspect the controller.
2. Identify the relevant action(s).
3. Identify templates rendered by those actions.
4. Inspect directly related layouts and partials.
5. Inspect models/plugins called by the relevant code.
6. Expand the investigation only when evidence indicates that other parts of the application are involved.

### Controller/template relationships

The controller directory contains many controllers and the default theme contains many templates.

Do not assume that similarly named files are necessarily related.

Use the actual Mojolicious rendering code, routes and template references to establish relationships.

### Avoid unnecessary repository-wide searches

Repository-wide searches are appropriate when investigating things such as:

- route definitions
- configuration used globally
- shared plugins
- common partials
- application-wide hooks
- shared models
- cross-cutting functionality

Otherwise, begin with the smallest relevant part of the application.

---

## 6. Existing Code and Compatibility

SrvMngr is an existing production-oriented application.

When making changes:

- Preserve existing behaviour unless the task explicitly requires changing it.
- Follow existing coding patterns where practical.
- Avoid unnecessary refactoring.
- Avoid changing APIs or interfaces without a clear reason.
- Do not replace established mechanisms merely because a newer approach exists.
- Consider SME Server integration and backwards compatibility.
- Check for existing tests and related code before changing behaviour.

Do not "clean up" unrelated code while implementing a focused change.

---

# 7. Application Module Inventory

The following section is an evolving architectural map of SrvMngr.

**OpenCode may maintain and improve this section.**

The purpose is to record concise, useful information about controllers/modules and their relationships. It is NOT intended to contain a complete copy of the source code or exhaustive documentation of every template.

When adding information:

- Verify it from the source code.
- Prefer concise factual descriptions.
- Do not speculate.
- Mark uncertain information as `Unknown` rather than inventing an explanation.
- Do not rewrite existing entries unnecessarily.
- Preserve useful information already recorded.
- Add information incrementally as it is discovered.
- Do not modify application source code merely to update this inventory.

## Controller Inventory

### Controller: [Name]

**File:** `root/usr/share/smanager/lib/SrvMngr/Controller/[Name].pm`

**Purpose:**
[Brief description of what this controller manages.]

**Actions:**
- `[action]` — [brief description]
- `[action]` — [brief description]

**Templates:**
- `[template path]`
- `[template path]`

**Models / Plugins / Collaborators:**
- `[module]` — [why it is used]

**Routes / Entry Points:**
- `[route or entry point]`

**Important Behaviour:**
- [Concise notes about behaviour, permissions, side effects, etc.]

**Notes:**
- [Useful architectural observations.]

---

## 8. How to Expand the Module Inventory

When asked to document or improve the module inventory, work incrementally.

For each controller:

1. Read the controller source.
2. Identify its actions.
3. Identify routes or other entry points where practical.
4. Identify templates actually rendered.
5. Inspect those templates sufficiently to understand their purpose.
6. Identify important models, plugins and other collaborators.
7. Record only useful architectural information.
8. Move on to the next controller.

Do not attempt to understand every controller in detail before documenting the first one.

If asked to document a particular controller, concentrate on that controller and its directly related code first.

---

## 9. Updating This File

`AGENTS.md` contains two different kinds of information:

### Stable project instructions

Sections 1–6 describe project structure, conventions and exploration strategy.

Do not substantially rewrite these sections unless explicitly asked to change the project instructions.

### OpenCode-maintained knowledge

Section 7 and subsequent module inventory sections are intended to evolve as the application is explored.

OpenCode may:

- add controller entries
- improve descriptions
- add discovered relationships
- correct previously inaccurate information
- add important architectural observations

Keep these entries concise.

Do not turn `AGENTS.md` into a source-code dump.

---

## 10. When Unsure

When the relationship between two parts of the application is unclear:

1. Inspect the relevant source.
2. Follow the actual code path.
3. Check tests or configuration if useful.
4. Do not infer a relationship solely from filenames.
5. Record uncertainty rather than inventing information.

The source code is authoritative; this document is a navigation aid and set of working instructions.