# demo.zero_trust.cloudflare_hostname

Configure Cloudflare Tunnel public hostnames (ingress rules) and their proxied DNS CNAME records.

Invoke with `include_role` and `tasks_from` — do not call the role without selecting an entry point.

```yaml
- name: Configure hostnames
  ansible.builtin.include_role:
    name: demo.zero_trust.cloudflare_hostname
    tasks_from: configure
```

This role requires `cloudflare_tunnel_id`, which is normally set as a fact by `demo.zero_trust.cloudflare_tunnel`'s `create` task earlier in the same play.

## Requirements

- Ansible 2.14+
- Collections: `community.general`
- Cloudflare API token with Tunnel Edit and DNS Edit

## Role Variables

| Variable | Default | Description |
| --- | --- | --- |
| `cloudflare_api_token` | env `CLOUDFLARE_API_TOKEN` | Cloudflare API token |
| `cloudflare_account_id` | `""` | Cloudflare account ID (required) |
| `cloudflare_zone` | `""` | DNS zone domain name, e.g. `example.com` (required) |
| `cloudflare_api_base` | `https://api.cloudflare.com/client/v4` | Cloudflare API base URL |
| `cloudflare_no_log` | `true` | Suppress sensitive task output |
| `cloudflare_tunnel_hostnames` | `[]` | Public hostname definitions (required for `configure`) |

Hostname entry shape:

```yaml
cloudflare_tunnel_hostnames:
  - hostname: app.example.com
    service: http://127.0.0.1:8080
  - hostname: api.example.com
    service: https://127.0.0.1:3000
    path: ""              # optional
    no_tls_verify: false  # optional shorthand for originRequest.noTLSVerify
    originRequest:        # optional native Cloudflare originRequest object (merged with no_tls_verify)
      originServerName: api.example.com
```

## Example Playbook

```yaml
- name: Configure tunnel hostnames
  hosts: cloudflare
  vars:
    cloudflare_account_id: "your-account-id"
    cloudflare_zone: example.com
    cloudflare_tunnel_hostnames:
      - hostname: vault.example.com
        service: https://127.0.0.1:8200
        no_tls_verify: true
  tasks:
    - name: Create tunnel
      ansible.builtin.include_role:
        name: demo.zero_trust.cloudflare_tunnel
        tasks_from: create

    - name: Configure hostnames
      ansible.builtin.include_role:
        name: demo.zero_trust.cloudflare_hostname
        tasks_from: configure
```

## Uninstall / Destroy

`destroy` deletes the proxied CNAME records for `cloudflare_tunnel_hostnames` (requires `cloudflare_zone`; skipped when the list is empty) and resets the tunnel ingress config to a catch-all 404 rule. It does not delete the tunnel itself — run `demo.zero_trust.cloudflare_tunnel`'s `destroy` task afterward.

## License

GPL-3.0-or-later
