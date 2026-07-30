# demo.zero_trust

Zero-trust infrastructure automation for Ansible. Reusable roles and patterns for deploying and managing control-plane building blocks such as secrets management, with a layout that can grow as more components are added.

| | |
| --- | --- |
| **Namespace** | `demo` |
| **Name** | `zero_trust` |
| **Version** | `1.0.0` |
| **License** | GPL-3.0-or-later |
| **Repository** | [zacharyleblanc/ansible-zero-trust](https://github.com/zacharyleblanc/ansible-zero-trust) |

## Contents

### Roles

| Role | Description | Documentation |
| --- | --- | --- |
| [`vault`](roles/vault/) | Install and initialize HashiCorp Vault (RPM or Podman Quadlet) via discrete task entry points | [README](roles/vault/README.md) |
| [`cloudflared`](roles/cloudflared/) | Install and uninstall the cloudflared connector on a managed host via Podman Quadlet | [README](roles/cloudflared/README.md) |
| [`cloudflare_tunnel`](roles/cloudflare_tunnel/) | Create or destroy a Cloudflare Tunnel via the Cloudflare API | [README](roles/cloudflare_tunnel/README.md) |
| [`cloudflare_hostname`](roles/cloudflare_hostname/) | Configure Cloudflare Tunnel public hostnames (ingress) and DNS CNAME records | [README](roles/cloudflare_hostname/README.md) |
| [`cloudflare_access_policy`](roles/cloudflare_access_policy/) | Create, update, and destroy Cloudflare Access applications and policies | [README](roles/cloudflare_access_policy/README.md) |

### Modules

None yet.

### Plugins

None yet.

### Playbooks

None packaged in this collection. Example playbooks that consume these roles live in the [repository root](https://github.com/zacharyleblanc/ansible-zero-trust/tree/main/playbooks).

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
