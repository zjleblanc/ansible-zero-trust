# demo.zero_trust.cloudflare_access_policy

Create, update, and destroy Cloudflare Access applications and policies for tunnel hostnames.

Invoke with `include_role` and `tasks_from` — do not call the role without selecting an entry point.

```yaml
- name: Configure Access policies
  ansible.builtin.include_role:
    name: demo.zero_trust.cloudflare_access_policy
    tasks_from: configure
```

This role is independent of `demo.zero_trust.cloudflare_tunnel` and `demo.zero_trust.cloudflare_hostname` — it only requires `cloudflare_account_id` and matches Access applications by hostname. When `cloudflare_access_policies` is empty, both entry points are a no-op.

## Requirements

- Ansible 2.14+
- Cloudflare API token with Access: Apps and Policies Edit

## Role Variables

| Variable | Default | Description |
| --- | --- | --- |
| `cloudflare_api_token` | env `CLOUDFLARE_API_TOKEN` | Cloudflare API token |
| `cloudflare_account_id` | `""` | Cloudflare account ID (required when policies are non-empty) |
| `cloudflare_api_base` | `https://api.cloudflare.com/client/v4` | Cloudflare API base URL |
| `cloudflare_no_log` | `true` | Suppress sensitive task output |
| `cloudflare_access_policies` | `[]` | Optional Access policies; empty skips both entry points |

Access policy entry shape (native Cloudflare rule objects for include/require/exclude):

```yaml
cloudflare_access_policies:
  - name: Allow corporate users
    hostname: app.example.com
    decision: allow                 # allow | deny | non_identity | bypass
    session_duration: "24h"         # optional
    include:
      - email_domain:
          domain: example.com
    require: []                     # optional
    exclude: []                     # optional
```

## Example Playbook

```yaml
- name: Configure Access policies
  hosts: cloudflare
  vars:
    cloudflare_account_id: "your-account-id"
    cloudflare_access_policies:
      - name: Allow eng
        hostname: vault.example.com
        decision: allow
        include:
          - email_domain:
              domain: example.com
  tasks:
    - name: Configure Access
      ansible.builtin.include_role:
        name: demo.zero_trust.cloudflare_access_policy
        tasks_from: configure
```

## Uninstall / Destroy

`destroy` deletes the Access application matching each `cloudflare_access_policies` hostname. Skipped entirely (no-op) when the list is empty.

## License

GPL-3.0-or-later
