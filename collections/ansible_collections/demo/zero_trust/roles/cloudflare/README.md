# demo.zero_trust.cloudflare

Create Cloudflare Tunnels, deploy the `cloudflared` connector via Podman Quadlet, configure public hostnames, and optionally secure them with Cloudflare Access policies.

Invoke with `include_role` and `tasks_from` — do not call the role without selecting an entry point.

```yaml
- name: Create tunnel
  ansible.builtin.include_role:
    name: demo.zero_trust.cloudflare
    tasks_from: create_tunnel
```

Typical setup sequence:

1. `create_tunnel` — create or find the tunnel; register `cloudflare_tunnel_id` and `cloudflare_tunnel_token`
2. `install_podman` — install Podman, store the tunnel token as a Podman secret, start the Quadlet unit
3. `configure_hostnames` — PUT remote ingress config and create proxied CNAME records
4. `configure_access` — create Access apps and policies (skipped when `cloudflare_access_policies` is empty)

## Requirements

- Ansible 2.14+
- Target: EL 8 or EL 9 (MVP); package-based Podman install is otherwise platform-agnostic
- Collections: `containers.podman`, `community.general`
- Cloudflare API token with Tunnel Edit, DNS Edit, and (optionally) Access Apps and Policies Edit
- For `install_podman`: Podman with systemd Quadlet support

## Security

Sensitive values are handled as follows:

| Secret | Handling |
| --- | --- |
| `cloudflare_api_token` | Prefer `CLOUDFLARE_API_TOKEN` env; fall back to ansible-vault vars. All API tasks use `no_log`. |
| `cloudflare_tunnel_token` | Stored only in the Podman secret store (`cloudflare_podman_secret_name`). Injected into the container as `TUNNEL_TOKEN`. Never written to the Quadlet unit file or CLI args. Facts are non-cacheable and `no_log`. |

## Role Variables

Defaults live in `defaults/main/` (split by concern). Entry-point requirements are defined in `meta/argument_specs.yml`.

### Shared defaults

| Variable | Default | Description |
| --- | --- | --- |
| `cloudflare_api_token` | env `CLOUDFLARE_API_TOKEN` | Cloudflare API token |
| `cloudflare_account_id` | `""` | Cloudflare account ID (required) |
| `cloudflare_zone` | `""` | DNS zone domain name, e.g. `example.com` (required for hostnames) |
| `cloudflare_api_base` | `https://api.cloudflare.com/client/v4` | Cloudflare API base URL |
| `cloudflare_no_log` | `true` | Suppress sensitive task output |

### Tunnel defaults

| Variable | Default | Description |
| --- | --- | --- |
| `cloudflare_tunnel_name` | `""` | Human-readable tunnel name (required) |
| `cloudflare_tunnel_config_src` | `cloudflare` | Remotely managed tunnel config |
| `cloudflare_tunnel_hostnames` | `[]` | Public hostname definitions (required for `configure_hostnames`) |

Hostname entry shape:

```yaml
cloudflare_tunnel_hostnames:
  - hostname: app.example.com
    service: http://127.0.0.1:8080
  - hostname: api.example.com
    service: https://127.0.0.1:3000
    path: ""              # optional
    no_tls_verify: false  # optional origin TLS setting
```

### Podman defaults

| Variable | Default | Description |
| --- | --- | --- |
| `cloudflare_container_image` | `docker.io/cloudflare/cloudflared:latest` | Container image |
| `cloudflare_container_name` | `cloudflared` | Container / Quadlet unit name |
| `cloudflare_podman_secret_name` | `cloudflare_tunnel_token` | Podman secret name for the tunnel token |

### Access defaults

| Variable | Default | Description |
| --- | --- | --- |
| `cloudflare_access_policies` | `[]` | Optional Access policies; empty skips `configure_access` |

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

Facts set by `create_tunnel`:

- `cloudflare_tunnel_id`
- `cloudflare_tunnel_token` (sensitive; `no_log`, not cacheable)

## Example Playbook

```yaml
- name: Cloudflare Tunnel Automation
  hosts: cloudflare
  vars_files:
    - vars/secrets.yml   # optional cloudflare_api_token when env is unset
  vars:
    cloudflare_account_id: "your-account-id"
    cloudflare_zone: example.com
    cloudflare_tunnel_name: demo-tunnel
    cloudflare_tunnel_hostnames:
      - hostname: vault.example.com
        service: https://127.0.0.1:8200
        no_tls_verify: true
    cloudflare_access_policies:
      - name: Allow eng
        hostname: vault.example.com
        decision: allow
        include:
          - email_domain:
              domain: example.com
    cloudflare_tasks:
      - create_tunnel
      - install_podman
      - configure_hostnames
      - configure_access
  tasks:
    - name: Run demo.zero_trust.cloudflare
      loop: "{{ cloudflare_tasks }}"
      loop_control:
        loop_var: function
      ansible.builtin.include_role:
        name: demo.zero_trust.cloudflare
        tasks_from: "{{ function }}"
```

Run with an env token (preferred):

```bash
export CLOUDFLARE_API_TOKEN=...
ansible-playbook -i inventory/local.yml playbooks/pb_setup_cloudflare_tunnel.yml
```

Or with ansible-vault:

```bash
ansible-playbook -i inventory/local.yml playbooks/pb_setup_cloudflare_tunnel.yml --ask-vault-pass
```

## License

GPL-3.0-or-later
