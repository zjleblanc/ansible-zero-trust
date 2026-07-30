# ansible-zero-trust

## Playbooks

| Playbook | View Details |
| --- | --- |
| Setup Vault | [`pb_setup_vault.yml`](playbooks/pb_setup_vault.yml) |
| Uninstall Vault | [`pb_uninstall_vault.yml`](playbooks/pb_uninstall_vault.yml) |
| Setup Cloudflare Tunnel | [`pb_setup_cloudflare_tunnel.yml`](playbooks/pb_setup_cloudflare_tunnel.yml) |
| Uninstall Cloudflare Tunnel | [`pb_uninstall_cloudflare_tunnel.yml`](playbooks/pb_uninstall_cloudflare_tunnel.yml) |

## Collection

| Content | View Details |
| --- | --- |
| `demo.zero_trust` | [`README`](collections/ansible_collections/demo/zero_trust/README.md) |
| └─ Role: `vault` | [`README`](collections/ansible_collections/demo/zero_trust/roles/vault/README.md) |
| └─ Role: `cloudflared` | [`README`](collections/ansible_collections/demo/zero_trust/roles/cloudflared/README.md) |
| └─ Role: `cloudflare_tunnel` | [`README`](collections/ansible_collections/demo/zero_trust/roles/cloudflare_tunnel/README.md) |
| └─ Role: `cloudflare_hostname` | [`README`](collections/ansible_collections/demo/zero_trust/roles/cloudflare_hostname/README.md) |
| └─ Role: `cloudflare_access_policy` | [`README`](collections/ansible_collections/demo/zero_trust/roles/cloudflare_access_policy/README.md) |
