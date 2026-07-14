# demo.zero_trust.vault

Install and initialize HashiCorp Vault on EL hosts via discrete task entry points (RPM or Podman Quadlet).

Invoke with `include_role` and `tasks_from` — do not call the role without selecting an entry point.

```yaml
- name: Run vault install
  ansible.builtin.include_role:
    name: demo.zero_trust.vault
    tasks_from: install_rpm
```

Typical sequence:

1. `configure_host` — copy TLS material and open the firewall port
2. `install_rpm` **or** `install_podman` — install and start Vault
3. `init_vault` — initialize, unseal, and report status

```yaml
- name: "Run demo.zero_trust.vault | {{ action }}"
  loop:
    - configure_host
    - install_podman
    - init_vault
  loop_control:
    loop_var: action
  ansible.builtin.include_role:
    name: demo.zero_trust.vault
    tasks_from: "{{ action }}"
```

## Requirements

- Ansible 2.14+
- Target: EL 8 or EL 9
- For `configure_host`: `firewalld` on the target
- For `install_podman`: Podman with systemd Quadlet support
- For TLS: certificate and key available on the controller (and/or already on the host)

## Role Variables

Defaults live in `defaults/main.yml`. Entry-point requirements are defined in `meta/argument_specs.yml`.

### Shared defaults

| Variable | Default | Description |
| --- | --- | --- |
| `vault_port` | `"8200"` | TCP port Vault listens on |
| `vault_tls_enabled` | `true` | Whether TLS is enabled for Vault |
| `vault_storage_path` | `/opt/vault/data` | Host path for Vault file storage |
| `vault_config_path` | `/opt/vault/config` | Host path for Vault configuration |
| `vault_no_log` | `true` | Suppress sensitive task output |
| `vault_addr` | derived | `http(s)://{{ vault_fqdn }}:{{ vault_port }}` |

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
- `vault_tls_cert_dest` / `vault_tls_key_dest`
- `vault_registry` / `vault_registry_username` / `vault_registry_password`
- `vault_cli` / `vault_cli_addr` (normally set by `install_rpm` or `install_podman`)

---

## Entry points

### `configure_host`

Copy TLS certs and configure firewall for Vault.

| Option | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `vault_port` | `str` | yes | `"8200"` | TCP port Vault listens on (also opened in firewalld) |
| `vault_tls_enabled` | `bool` | yes | `true` | Whether TLS is enabled for Vault |
| `vault_tls_cert_dest` | `path` | no | — | Destination path for the TLS certificate on the host |
| `vault_tls_key_dest` | `path` | no | — | Destination path for the TLS private key on the host |
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
    vault_tls_cert_dest: /opt/vault/tls/tls.crt
    vault_tls_key_dest: /opt/vault/tls/tls.key
```

### `install_rpm`

Install Vault via the HashiCorp RPM repository.

| Option | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `vault_fqdn` | `str` | no | — | Fully qualified domain name for Vault |
| `vault_port` | `str` | yes | `"8200"` | TCP port Vault listens on |
| `vault_storage_path` | `path` | yes | `/opt/vault/data` | Host path for Vault file storage |
| `vault_tls_enabled` | `bool` | yes | `true` | Whether TLS is enabled for Vault |
| `vault_tls_cert_dest` | `path` | no | — | Destination path for the TLS certificate on the host |
| `vault_tls_key_dest` | `path` | no | — | Destination path for the TLS private key on the host |

Sets `vault_cli` and `vault_cli_addr` for a subsequent `init_vault` run.

```yaml
- name: Install Vault via RPM
  ansible.builtin.include_role:
    name: demo.zero_trust.vault
    tasks_from: install_rpm
  vars:
    vault_fqdn: vault.example.com
    vault_tls_cert_dest: /opt/vault/tls/tls.crt
    vault_tls_key_dest: /opt/vault/tls/tls.key
```

### `install_podman`

Install Vault via Podman Quadlet.

| Option | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `vault_port` | `str` | yes | `"8200"` | TCP port Vault listens on |
| `vault_storage_path` | `path` | yes | `/opt/vault/data` | Host path for Vault file storage |
| `vault_config_path` | `path` | yes | `/opt/vault/config` | Host path for Vault configuration |
| `vault_tls_enabled` | `bool` | yes | `true` | Whether TLS is enabled for Vault |
| `vault_tls_cert_dest` | `path` | no | — | Destination path for the TLS certificate on the host |
| `vault_tls_key_dest` | `path` | no | — | Destination path for the TLS private key on the host |
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

If either registry username or password is set, both must be provided (and optionally `vault_registry`). Sets `vault_cli` and `vault_cli_addr` for a subsequent `init_vault` run.

```yaml
- name: Install Vault via Podman
  ansible.builtin.include_role:
    name: demo.zero_trust.vault
    tasks_from: install_podman
  vars:
    vault_tls_cert_dest: /opt/vault/tls/tls.crt
    vault_tls_key_dest: /opt/vault/tls/tls.key
    vault_registry_username: "{{ vault_pull_user }}"
    vault_registry_password: "{{ vault_pull_password }}"
```

### `init_vault`

Initialize, unseal, and report Vault status.

| Option | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `vault_cli` | `str` | yes | set by install | Vault CLI invocation (binary or `podman exec` wrapper) |
| `vault_cli_addr` | `str` | yes | set by install | `VAULT_ADDR` value for CLI operations |
| `vault_storage_path` | `path` | yes | `/opt/vault/data` | Host path where `init_data.json` is written |
| `vault_no_log` | `bool` | no | `true` | Suppress sensitive task output |

Writes initialization output to `{{ vault_storage_path }}/init_data.json`. Prefer running this after `install_rpm` or `install_podman` so `vault_cli` / `vault_cli_addr` are already set.

```yaml
- name: Initialize Vault
  ansible.builtin.include_role:
    name: demo.zero_trust.vault
    tasks_from: init_vault
```

## License

GPL-3.0-or-later

## Author

Zachary LeBlanc
