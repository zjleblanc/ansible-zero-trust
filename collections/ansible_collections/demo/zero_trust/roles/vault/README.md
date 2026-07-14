# demo.zero_trust.vault

Install, initialize, and configure HashiCorp Vault on EL hosts via discrete task entry points (RPM or Podman Quadlet). Supports AAP OIDC JWT workload identity, KV secrets, and userpass auth.

Invoke with `include_role` and `tasks_from` — do not call the role without selecting an entry point.

```yaml
- name: Run vault install
  ansible.builtin.include_role:
    name: demo.zero_trust.vault
    tasks_from: install_rpm
```

Typical setup sequence:

1. `configure_host` — copy TLS material and open the firewall port
2. `install_rpm` **or** `install_podman` — install and start Vault
3. `init_vault` — initialize, unseal, and report status
4. `configure_jwt_auth` — enable JWT auth for AAP OIDC (optional)
5. `configure_kv_engine` — enable KV v2 and seed sample secrets (optional)
6. `configure_userpass_auth` — enable userpass and create users (optional)

Uninstall with `uninstall` (detects RPM or Podman and removes artifacts).

## Requirements

- Ansible 2.14+
- Target: EL 8 or EL 9
- For `configure_host` / `uninstall`: `firewalld` on the target
- For `install_podman` / Podman uninstall: Podman with systemd Quadlet support; `containers.podman` collection
- For TLS: certificate and key available on the controller (and/or already on the host)
- For `configure_jwt_auth`: AAP OIDC discovery URL (`vault_jwt_oidc_discovery_url`)

## Role Variables

Defaults live in `defaults/main/` (split by concern). Entry-point requirements are defined in `meta/argument_specs.yml`.

### Shared defaults

| Variable | Default | Description |
| --- | --- | --- |
| `vault_port` | `"8200"` | TCP port Vault listens on |
| `vault_tls_enabled` | `true` | Whether TLS is enabled for Vault |
| `vault_storage_path` | `/opt/vault/data` | Host path for Vault file storage |
| `vault_config_path` | `/opt/vault/config` | Host path for Vault configuration |
| `vault_no_log` | `true` | Suppress sensitive task output |
| `vault_addr` | derived | `http(s)://{{ vault_fqdn }}:{{ vault_port }}` |
| `vault_tls_cert_dest` | `/opt/vault/tls/fullchain_{{ vault_fqdn }}.pem` | Destination path for the TLS certificate |
| `vault_tls_key_dest` | `/opt/vault/tls/{{ vault_fqdn }}.key` | Destination path for the TLS private key |

### Podman defaults

| Variable | Default | Description |
| --- | --- | --- |
| `vault_container_name` | `vault` | Podman container / Quadlet unit name |
| `vault_container_image` | `registry.connect.redhat.com/hashicorp/vault:latest` | Container image reference |
| `vault_container_uid` | `"100"` | UID owning Vault data inside the container |
| `vault_container_gid` | `"100"` | GID owning Vault data inside the container |
| `vault_container_storage_path` | `/vault/data` | In-container path for Vault file storage |
| `vault_container_config_path` | `/vault/config` | In-container path for Vault configuration |
| `vault_container_tls_dir` | `/vault/tls` | In-container directory for TLS material |

Variables without defaults (set in inventory/playbook as needed):

- `vault_fqdn`
- `vault_tls_cert_src` / `vault_tls_key_src`
- `vault_registry` / `vault_registry_username` / `vault_registry_password`
- `vault_cli` / `vault_cli_addr` (normally set by `install_rpm` or `install_podman`)
- `vault_token` (optional; set by `init_vault` or loaded from `init_data.json`)
- `vault_jwt_oidc_discovery_url` (required for `configure_jwt_auth`)

---

## AAP JWT claims preview

When AAP authenticates to Vault with OIDC workload identity, Vault receives a JWT whose claims describe the job that requested the token. The role ships an example payload at `files/aap_claims.example.json`:

```json
{
    "jti": "12345678-90ab-cdef-0808-aabbccddeeff",
    "iss": "https://app.ansible.com/o",
    "aud": "https://vault.example.com:8200",
    "iat": 1234567890,
    "exp": 1234567890,
    "sub": "workload_type:aap_controller_automation_job:organization:my-org:job_template:my-template",
    "aap_controller_job_id": "42",
    "aap_controller_job_name": "Deploy Web Server",
    "aap_controller_job_type": "run",
    "aap_controller_launch_type": "manual",
    "aap_controller_playbook_name": "deploy.yml",
    "aap_controller_launched_by_name": "alice",
    "aap_controller_launched_by_id": "7",
    "aap_controller_organization_name": "Default",
    "aap_controller_organization_id": "1",
    "aap_controller_inventory_name": "Production Inventory",
    "aap_controller_inventory_id": "5",
    "aap_controller_execution_environment_name": "Default EE",
    "aap_controller_execution_environment_id": "3",
    "aap_controller_project_name": "Infrastructure Project",
    "aap_controller_project_id": "17",
    "aap_controller_job_template_name": "Deploy Template",
    "aap_controller_job_template_id": "21",
    "aap_controller_unified_job_template_name": "Unified Deploy Template",
    "aap_controller_unified_job_template_id": "55",
    "aap_controller_instance_group_name": "Group 1",
    "aap_controller_instance_group_id": "9"
}
```

How `configure_jwt_auth` uses these claims by default:

| Claim / field | Vault usage |
| --- | --- |
| `sub` | `user_claim` for both JWT roles |
| `aud` | Must match `vault_jwt_bound_audiences` (defaults to `vault_addr`) |
| `aap_controller_organization_name` | `bound_claims` for static and dynamic roles (default orgs: `Default`, `Autodotes`) |
| `aap_controller_organization_name` → `org` | Dynamic role `claim_mappings` for templated secret paths |
| `aap_controller_job_template_name` → `job_template` | Dynamic role `claim_mappings` (available for policy templates) |

With the example claims above and default policies:

- **Static role** (`aap-role-static`): grants read on `secret/data/aap/*` when the org is allowed
- **Dynamic role** (`aap-role-dynamic`): grants read on `secret/data/aap/{{ identity.entity.aliases.<jwt-accessor>.metadata.org }}/*` — for org `Default`, that resolves under `secret/data/aap/Default/*`

---

## Sample playbooks

Repo playbooks under `playbooks/` wrap the role for common flows. Targets default to the `vault` inventory group (`_hosts` override supported).

### Setup

```yaml
---
- name: Vault Automation
  hosts: "{{ _hosts | default('vault') }}"

  vars:
    vault_tasks:
      - configure_host
      - install_podman
      - init_vault
      - configure_jwt_auth
      - configure_kv_engine
      - configure_userpass_auth

  tasks:
    - name: "Run demo.zero_trust.vault"
      loop: "{{ vault_tasks }}"
      loop_control:
        loop_var: function
      ansible.builtin.include_role:
        name: demo.zero_trust.vault
        tasks_from: "{{ function }}"
```

Run (example):

```bash
ansible-playbook -i inventory/local.yml playbooks/pb_setup_vault.yml
```

**Expected outcome**

| Step | Result |
| --- | --- |
| `configure_host` | TLS cert/key copied (when sources set); firewalld opens `vault_port` |
| `install_podman` | Quadlet unit installed; Vault container running; `vault_cli` / `vault_cli_addr` set |
| `init_vault` | Vault initialized (or existing init reloaded); unsealed; `{{ vault_storage_path }}/init_data.json` present; status printed |
| `configure_jwt_auth` | `jwt/` auth enabled; OIDC discovery configured; static and dynamic policies/roles created |
| `configure_kv_engine` | KV v2 mounted at `secret/`; sample secrets seeded under `secret/data/aap/...` |
| `configure_userpass_auth` | `userpass/` enabled; admin/user policies written; users from `files/vault_users.json` created; auto-generated passwords saved to `{{ vault_storage_path }}/userpass_credentials.json` when needed |

Inventory must supply at least `vault_fqdn` and `vault_jwt_oidc_discovery_url`. TLS source paths are required when copying certs in `configure_host`.

### Uninstall

```yaml
---
- name: Vault Uninstall
  hosts: "{{ _hosts | default('vault') }}"

  tasks:
    - name: Uninstall Vault
      ansible.builtin.include_role:
        name: demo.zero_trust.vault
        tasks_from: uninstall
```

Run (example):

```bash
ansible-playbook -i inventory/local.yml playbooks/pb_uninstall_vault.yml
```

**Expected outcome**

- Detects RPM and/or Podman install
- Stops services, removes package or Quadlet/container/image
- Removes TLS material (when enabled), `vault_storage_path`, `vault_config_path`, and the firewalld port rule
- Host no longer runs Vault; init data and generated credentials under storage are deleted

---

## Entry points

### `configure_host`

Copy TLS certs and configure firewall for Vault.

| Option | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `vault_port` | `str` | yes | `"8200"` | TCP port Vault listens on (also opened in firewalld) |
| `vault_tls_enabled` | `bool` | yes | `true` | Whether TLS is enabled for Vault |
| `vault_tls_cert_dest` | `path` | no | see shared defaults | Destination path for the TLS certificate on the host |
| `vault_tls_key_dest` | `path` | no | see shared defaults | Destination path for the TLS private key on the host |
| `vault_tls_cert_src` | `path` | no | — | Controller-side path to the TLS certificate to copy |
| `vault_tls_key_src` | `path` | no | — | Controller-side path to the TLS private key to copy |

TLS files are copied only when `vault_tls_enabled` is true and both `vault_tls_cert_src` and `vault_tls_key_src` are defined.

```yaml
- name: Configure host for Vault
  ansible.builtin.include_role:
    name: demo.zero_trust.vault
    tasks_from: configure_host
  vars:
    vault_tls_cert_src: "{{ playbook_dir }}/files/vault.crt"
    vault_tls_key_src: "{{ playbook_dir }}/files/vault.key"
```

### `install_rpm`

Install Vault via the HashiCorp RPM repository.

| Option | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `vault_fqdn` | `str` | no | — | Fully qualified domain name for Vault |
| `vault_port` | `str` | yes | `"8200"` | TCP port Vault listens on |
| `vault_storage_path` | `path` | yes | `/opt/vault/data` | Host path for Vault file storage |
| `vault_tls_enabled` | `bool` | yes | `true` | Whether TLS is enabled for Vault |
| `vault_tls_cert_dest` | `path` | no | see shared defaults | Destination path for the TLS certificate on the host |
| `vault_tls_key_dest` | `path` | no | see shared defaults | Destination path for the TLS private key on the host |

Sets `vault_cli` and `vault_cli_addr` for subsequent entry points.

```yaml
- name: Install Vault via RPM
  ansible.builtin.include_role:
    name: demo.zero_trust.vault
    tasks_from: install_rpm
  vars:
    vault_fqdn: vault.example.com
```

### `install_podman`

Install Vault via Podman Quadlet.

| Option | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `vault_port` | `str` | yes | `"8200"` | TCP port Vault listens on |
| `vault_storage_path` | `path` | yes | `/opt/vault/data` | Host path for Vault file storage |
| `vault_config_path` | `path` | yes | `/opt/vault/config` | Host path for Vault configuration |
| `vault_tls_enabled` | `bool` | yes | `true` | Whether TLS is enabled for Vault |
| `vault_tls_cert_dest` | `path` | no | see shared defaults | Destination path for the TLS certificate on the host |
| `vault_tls_key_dest` | `path` | no | see shared defaults | Destination path for the TLS private key on the host |
| `vault_container_image` | `str` | yes | see defaults | Container image reference for Vault |
| `vault_container_name` | `str` | yes | `vault` | Podman container / Quadlet unit name |
| `vault_container_uid` | `str` | yes | `"100"` | UID owning Vault data inside the container |
| `vault_container_gid` | `str` | yes | `"100"` | GID owning Vault data inside the container |
| `vault_container_storage_path` | `path` | yes | `/vault/data` | In-container path for Vault file storage |
| `vault_container_config_path` | `path` | yes | `/vault/config` | In-container path for Vault configuration |
| `vault_container_tls_dir` | `path` | no | `/vault/tls` | In-container directory for TLS material |
| `vault_no_log` | `bool` | no | `true` | Suppress sensitive task output |
| `vault_registry` | `str` | no | — | Container registry hostname for authenticated pulls |
| `vault_registry_username` | `str` | no | — | Username for container registry authentication |
| `vault_registry_password` | `str` | no | — | Password for container registry authentication |

If either registry username or password is set, both must be provided (and optionally `vault_registry`). Sets `vault_cli` and `vault_cli_addr` for subsequent entry points.

```yaml
- name: Install Vault via Podman
  ansible.builtin.include_role:
    name: demo.zero_trust.vault
    tasks_from: install_podman
  vars:
    vault_registry_username: "{{ vault_pull_user }}"
    vault_registry_password: "{{ vault_pull_password }}"
```

### `init_vault`

Initialize, unseal, and report Vault status. Idempotent: skips init when already initialized and reloads `init_data.json`.

| Option | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `vault_cli` | `str` | yes | set by install | Vault CLI invocation (binary or `podman exec` wrapper) |
| `vault_cli_addr` | `str` | yes | set by install | `VAULT_ADDR` value for CLI operations |
| `vault_storage_path` | `path` | yes | `/opt/vault/data` | Host path where `init_data.json` is written |
| `vault_no_log` | `bool` | no | `true` | Suppress sensitive task output |

Writes initialization output to `{{ vault_storage_path }}/init_data.json` and sets `vault_token` from `root_token` when unset. Prefer running after `install_rpm` or `install_podman`.

```yaml
- name: Initialize Vault
  ansible.builtin.include_role:
    name: demo.zero_trust.vault
    tasks_from: init_vault
```

### `configure_jwt_auth`

Enable JWT auth for AAP OIDC workload identity with a static role/policy and a dynamic (templated) role/policy.

| Option | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `vault_cli` / `vault_cli_addr` | `str` | yes | set by install | Vault CLI invocation and address |
| `vault_token` | `str` | no | from init | Root/admin token; optional if `init_data.json` exists |
| `vault_storage_path` | `path` | yes | `/opt/vault/data` | Host path for token lookup |
| `vault_jwt_oidc_discovery_url` | `str` | yes | — | AAP OIDC discovery URL (AAP base URL with `/o` suffix) |
| `vault_jwt_oidc_discovery_ca_pem` | `path` | no | — | Controller-side CA PEM for AAP TLS discovery |
| `vault_jwt_bound_audiences` | `list` | no | `[vault_addr]` | Audiences accepted by JWT roles |
| `vault_jwt_static_role_name` | `str` | no | `aap-role-static` | Static JWT role name |
| `vault_jwt_static_policy_name` | `str` | no | `aap-policy-static` | Static policy name |
| `vault_jwt_static_secret_path` | `str` | no | `secret/data/aap/*` | KV path granted read by the static policy |
| `vault_jwt_static_bound_claims` | `dict` | no | org allow-list | `bound_claims` for the static role |
| `vault_jwt_dynamic_role_name` | `str` | no | `aap-role-dynamic` | Dynamic JWT role name |
| `vault_jwt_dynamic_policy_name` | `str` | no | `aap-policy-dynamic` | Templated policy name |
| `vault_jwt_dynamic_bound_claims` | `dict` | no | org allow-list | `bound_claims` for the dynamic role |
| `vault_jwt_dynamic_claim_mappings` | `dict` | no | org / job_template | JWT claim → metadata mappings |
| `vault_jwt_dynamic_secret_path_template` | `str` | no | see defaults | Templated KV path (`JWT_ACCESSOR`, `[[ ]]` placeholders) |

```yaml
- name: Configure JWT auth for AAP
  ansible.builtin.include_role:
    name: demo.zero_trust.vault
    tasks_from: configure_jwt_auth
  vars:
    vault_jwt_oidc_discovery_url: https://aap.example.com/o
```

### `configure_kv_engine`

Enable the KV secrets engine and seed sample secrets for e2e testing (paths align with JWT policies).

| Option | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `vault_cli` / `vault_cli_addr` | `str` | yes | set by install | Vault CLI invocation and address |
| `vault_token` | `str` | no | from init | Root/admin token; optional if `init_data.json` exists |
| `vault_kv_engine_path` | `str` | no | `secret` | Mount path for the KV engine |
| `vault_kv_engine_version` | `str` | no | `"2"` | KV version (`1` or `2`) |
| `vault_kv_sample_secrets` | `list` | no | see defaults | List of `{path, data}` secrets to seed |

Default sample secrets:

- `secret/data/aap/Default/ansible-sa`
- `secret/data/aap/Autodotes/autodotes-sa`

```yaml
- name: Configure KV engine
  ansible.builtin.include_role:
    name: demo.zero_trust.vault
    tasks_from: configure_kv_engine
```

### `configure_userpass_auth`

Enable userpass auth and create users from a JSON config under `files/` (default `vault_users.json`).

| Option | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `vault_cli` / `vault_cli_addr` | `str` | yes | set by install | Vault CLI invocation and address |
| `vault_token` | `str` | no | from init | Root/admin token; optional if `init_data.json` exists |
| `vault_userpass_users_file` | `str` | no | `vault_users.json` | Filename under role `files/` |
| `vault_userpass_credentials_file` | `str` | no | `userpass_credentials.json` | Filename under `vault_storage_path` for generated passwords |
| `vault_userpass_admin_policy_name` | `str` | no | `admin-policy` | Policy for `role: admin` |
| `vault_userpass_user_policy_name` | `str` | no | `user-policy` | Policy for `role: user` |
| `vault_userpass_user_secret_path` | `str` | no | `secret/data/*` | KV data path for user policy |
| `vault_userpass_user_secret_metadata_path` | `str` | no | `secret/metadata/*` | KV metadata path for user policy |
| `vault_userpass_password_length` | `int` | no | `24` | Length of auto-generated passwords |
| `vault_userpass_password_chars` | `str` | no | `ascii_letters,digits` | Character classes for generated passwords |

Each user entry needs `username` and `role` (`admin` or `user`). Omit `password` to auto-generate one.

```yaml
- name: Configure userpass auth
  ansible.builtin.include_role:
    name: demo.zero_trust.vault
    tasks_from: configure_userpass_auth
```

### `uninstall`

Detect install type (RPM and/or Podman) and remove Vault services, packages/images, TLS material, storage/config directories, and the firewall rule.

| Option | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `vault_port` | `str` | yes | `"8200"` | TCP port to close in firewalld |
| `vault_tls_enabled` | `bool` | yes | `true` | Whether TLS material should be removed |
| `vault_tls_cert_dest` / `vault_tls_key_dest` | `path` | no | see shared defaults | TLS paths to remove |
| `vault_storage_path` | `path` | yes | `/opt/vault/data` | Host storage directory to remove |
| `vault_config_path` | `path` | yes | `/opt/vault/config` | Host config directory to remove |
| `vault_container_name` | `str` | yes | `vault` | Quadlet/container name for detection and cleanup |
| `vault_container_image` | `str` | yes | see defaults | Container image to remove when Podman install is detected |

```yaml
- name: Uninstall Vault
  ansible.builtin.include_role:
    name: demo.zero_trust.vault
    tasks_from: uninstall
```

## License

GPL-3.0-or-later

## Author

Zachary LeBlanc
