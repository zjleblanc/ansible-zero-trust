# Agent instructions

## Prefer Ansible modules over shell/command

When developing or changing Ansible tasks, always discover whether a dedicated module exists before using `ansible.builtin.command`, `ansible.builtin.shell`, or similar raw execution.

Run:

```bash
ansible-doc -t module -l | grep <target>
```

Use the listing where &lt;target&gt; is a search term like **podman** (and `ansible-doc <module_name>` for details) to find the right module for the task. Prefer collection modules (for example `containers.podman.*`) over inventing `command`/`shell` wrappers around CLI tools.
