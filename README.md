# ansible-zero-trust

Ansible automation for zero-trust implementations in an AIOps and agentic world.

As infrastructure and operations increasingly involve autonomous agents, LLM-driven workflows, and continuous change, trust boundaries cannot be assumed. This repository collects playbooks, roles, and patterns that encode least privilege, verified identity, and controlled access into automation that can run alongside—or under—agentic systems.

The goal is practical, reusable Ansible content: deploy and manage the control planes that make zero trust operational (secrets, identity, policy, and related building blocks), with a layout suited for growth as more components are added.

## Directory of contents

| Path | Description |
|------|-------------|
| [`playbooks/pb_setup_vault.yml`](playbooks/pb_setup_vault.yml) | Playbook to configure the host, install HashiCorp Vault (Podman by default), and initialize/unseal Vault |
| [`collections/ansible_collections/demo/zero_trust/roles/vault`](collections/ansible_collections/demo/zero_trust/roles/vault) | `demo.zero_trust.vault` role — discrete task entry points for host TLS/firewall setup, RPM or Podman install, and Vault init/unseal |

Collection details and role usage live in [`collections/ansible_collections/demo/zero_trust/README.md`](collections/ansible_collections/demo/zero_trust/README.md).
