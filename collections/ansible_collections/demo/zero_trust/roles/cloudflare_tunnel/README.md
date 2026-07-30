# demo.zero_trust.cloudflare_tunnel

Create or destroy a Cloudflare Tunnel via the Cloudflare API.

Invoke with `include_role` and `tasks_from` — do not call the role without selecting an entry point.

```yaml
- name: Create tunnel
  ansible.builtin.include_role:
    name: demo.zero_trust.cloudflare_tunnel
    tasks_from: create
```

This role only manages the tunnel resource itself. It does not configure hostnames/DNS (`demo.zero_trust.cloudflare_hostname`), Access policies (`demo.zero_trust.cloudflare_access_policy`), or the local cloudflared connector (`demo.zero_trust.cloudflared`).

## Requirements

- Ansible 2.14+
- Cloudflare API token with Tunnel Edit

## Exported Facts

`create` sets the following facts for downstream roles in the same play:

| Fact | Description | Consumed by |
| --- | --- | --- |
| `cloudflare_tunnel_id` | UUID of the created/existing tunnel | `demo.zero_trust.cloudflare_hostname` |
| `cloudflare_tunnel_token` | Connector auth token (sensitive; `no_log`, not cacheable) | `demo.zero_trust.cloudflared` |

## Role Variables

| Variable | Default | Description |
| --- | --- | --- |
| `cloudflare_api_token` | env `CLOUDFLARE_API_TOKEN` | Cloudflare API token |
| `cloudflare_account_id` | `""` | Cloudflare account ID (required) |
| `cloudflare_api_base` | `https://api.cloudflare.com/client/v4` | Cloudflare API base URL |
| `cloudflare_no_log` | `true` | Suppress sensitive task output |
| `cloudflare_tunnel_name` | `""` | Human-readable tunnel name (required) |
| `cloudflare_tunnel_config_src` | `cloudflare` | Remotely managed tunnel config |

## Example Playbook

```yaml
- name: Create and destroy a tunnel
  hosts: cloudflare
  vars:
    cloudflare_account_id: "your-account-id"
    cloudflare_tunnel_name: demo-tunnel
  tasks:
    - name: Create tunnel
      ansible.builtin.include_role:
        name: demo.zero_trust.cloudflare_tunnel
        tasks_from: create
```

`destroy` looks up the tunnel by `cloudflare_tunnel_name` and soft-deletes it via `DELETE /accounts/{account_id}/cfd_tunnel/{tunnel_id}`. If not found, it is an idempotent no-op. Cloudflare rejects deletion while the connector is still running, so run `demo.zero_trust.cloudflared`'s `uninstall` first during teardown.

## License

GPL-3.0-or-later
