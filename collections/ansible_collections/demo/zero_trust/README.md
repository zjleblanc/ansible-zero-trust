# demo.zero_trust

Zero-trust infrastructure automation collection.

## Roles

### vault

Install and initialize HashiCorp Vault using discrete task entry points:

- `configure_host` — copy TLS material and open the firewall port
- `install_rpm` — install Vault from the HashiCorp RPM repository
- `install_podman` — install Vault as a Podman Quadlet service
- `init_vault` — initialize, unseal, and report Vault status

Invoke via `include_role` with `tasks_from`, for example:

```yaml
- name: Run vault install
  ansible.builtin.include_role:
    name: demo.zero_trust.vault
    tasks_from: install_rpm
```
