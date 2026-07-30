# demo.zero_trust.cloudflared

Install and uninstall the `cloudflared` connector on a managed host via Podman Quadlet.

Invoke with `include_role` and `tasks_from` — do not call the role without selecting an entry point.

```yaml
- name: Install cloudflared
  ansible.builtin.include_role:
    name: demo.zero_trust.cloudflared
    tasks_from: install
```

This role has no knowledge of the Cloudflare API — it only deploys the connector container using a tunnel token supplied by `demo.zero_trust.cloudflare_tunnel`. Typical usage:

1. Run `demo.zero_trust.cloudflare_tunnel`'s `create` task first to obtain a tunnel token (sets the `cloudflare_tunnel_token` fact)
2. Run `install` here — `cloudflared_tunnel_token` defaults to that fact

## Requirements

- Ansible 2.14+
- Target: EL 8 or EL 9 (MVP); package-based Podman install is otherwise platform-agnostic
- Collections: `containers.podman`
- Podman with systemd Quadlet support
- For rootless install/uninstall: `loginctl`/`systemd-logind` on the target (used to enable lingering for `cloudflared_podman_user`)

## Rootful vs. Rootless Podman

By default (`cloudflared_podman_rootless: true`), cloudflared runs as a **rootless** Podman Quadlet owned by `cloudflared_podman_user` (defaults to `ansible_user`). Setting `cloudflared_podman_rootless: false` switches to a **rootful** Quadlet under `/etc/containers/systemd/` managed at the `system` scope:

| Concern | Rootless (default) | Rootful |
| --- | --- | --- |
| Quadlet path | `~{{ cloudflared_podman_user }}/.config/containers/systemd/` | `/etc/containers/systemd/` |
| systemd scope | `user` (requires `loginctl enable-linger`, handled automatically) | `system` |
| `[Install] WantedBy` | `default.target` | `multi-user.target default.target` |

`uninstall` detects and removes the Quadlet unit in the same location `install` would have used, so `cloudflared_podman_rootless` and `cloudflared_podman_user` must be set the same way for both install and uninstall.

## Podman Networking

Set `cloudflared_podman_network` to join cloudflared to a named Podman network (created automatically if it does not exist). This is useful for reaching other containers — such as `demo.zero_trust.vault` — by container name instead of `127.0.0.1`, which resolves to the cloudflared container's own loopback (not the host) on the default bridge network:

```yaml
cloudflared_podman_network: zt-network
```

For this to work, deploy the origin service with the same network name (e.g. `vault_podman_network: zt-network`) so both containers join it.

## Security

`cloudflared_tunnel_token` is stored only in the Podman secret store (`cloudflared_podman_secret_name`). It is injected into the container as `TUNNEL_TOKEN`, never written to the Quadlet unit file or CLI args, and handled with `no_log`.

## Role Variables

| Variable | Default | Description |
| --- | --- | --- |
| `cloudflared_tunnel_token` | `{{ cloudflare_tunnel_token \| default('') }}` | Tunnel connector token (required) |
| `cloudflared_container_image` | `docker.io/cloudflare/cloudflared:latest` | Container image |
| `cloudflared_container_name` | `cloudflared` | Container / Quadlet unit name |
| `cloudflared_podman_secret_name` | `cloudflare_tunnel_token` | Podman secret name for the tunnel token |
| `cloudflared_uninstall_remove_image` | `true` | Remove the container image during `uninstall` |
| `cloudflared_podman_network` | `""` | Podman network to join; empty disables custom networking |
| `cloudflared_podman_rootless` | `true` | Run cloudflared as a rootless Podman Quadlet under `cloudflared_podman_user` (set `false` for rootful) |
| `cloudflared_podman_user` | `{{ ansible_user }}` | User account that owns the rootless Podman Quadlet when `cloudflared_podman_rootless` is true |
| `cloudflared_no_log` | `true` | Suppress sensitive task output |

## Example Playbook

```yaml
- name: Deploy cloudflared
  hosts: cloudflare
  tasks:
    - name: Create tunnel
      ansible.builtin.include_role:
        name: demo.zero_trust.cloudflare_tunnel
        tasks_from: create

    - name: Install cloudflared
      ansible.builtin.include_role:
        name: demo.zero_trust.cloudflared
        tasks_from: install
```

## License

GPL-3.0-or-later
