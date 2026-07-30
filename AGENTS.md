# Agent instructions

## Prefer Ansible modules over shell/command

When developing or changing Ansible tasks, always discover whether a dedicated module exists before using `ansible.builtin.command`, `ansible.builtin.shell`, or similar raw execution.

Run:

```bash
ansible-doc -t module -l | grep <target>
```

Use the listing where &lt;target&gt; is a search term like **podman** (and `ansible-doc <module_name>` for details) to find the right module for the task. Prefer collection modules (for example `containers.podman.*`) over inventing `command`/`shell` wrappers around CLI tools.

## Preferred Key Order for Ansible Tasks

_Skip keys that aren't present, unless explicitly required or mentioned_

- name
- when
- loop
- loop_control
    - loop_var
    - label (for loops, always provide logical label name with prefix _ in place of item)
- miscellaneous keys
- vars
- module
    - module parameters
        - name
        - description
        - state
        - miscellaneous keys in abc order

## Task File Visibility (Public vs Private)

Roles in this collection use `include_role` with `tasks_from` instead of a
`tasks/main.yml` entry point. To distinguish callable entry points from
internal helpers, use a `private/` subdirectory:

    roles/my_role/tasks/
    ├── configure.yml         # public entry point
    ├── destroy.yml           # public entry point
    └── private/
        ├── resolve_creds.yml # internal helper
        └── do_thing.yml      # internal helper

Rules:

- Only files directly under `tasks/` are public entry points and may appear
  in playbook `tasks_from:` directives.
- Files under `tasks/private/` are internal helpers -- include them via
  `ansible.builtin.include_tasks: private/<name>.yml` from within the role.
- Document all public entry points in `meta/argument_specs.yml`.
- Private files do NOT get argument_specs entries.
- Never call a private task from a playbook or from outside the role.

## Exported Facts (Role Return Variables)

When a public task file sets facts intended for consumption by downstream
roles or tasks, document them in both:

1. `meta/argument_specs.yml` -- under the entry point, add a `set_facts` key
   listing each exported fact with a description.
2. The role README -- an "Exports" section.

Only document exports when present. Inputs from upstream roles are enforced
via `argument_specs.yml` options (the standard mechanism); do not duplicate
them as a separate "consumes" section.

Example in `meta/argument_specs.yml`:

```yaml
argument_specs:
  create:
    short_description: Create a Cloudflare Tunnel
    set_facts:
      cloudflare_tunnel_id:
        type: str
        description: UUID of the created or existing tunnel.
      cloudflare_tunnel_token:
        type: str
        description: Connector auth token for the tunnel (sensitive).
    options:
      cloudflare_account_id:
        ...
```

The `set_facts` key is not enforced by Ansible but serves as machine-readable
documentation of the role's contract with downstream consumers.