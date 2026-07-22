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
    _ label (for loops, always provide logical label name with prefix _ in place of item)
- miscellaneous keys
- vars
- module
    - module parameters
        - name
        - description
        - state
        - miscellaneous keys in abc order