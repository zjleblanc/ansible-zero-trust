# Zero Trust Automation: Vault + AAP OIDC Workload Identity with Ansible

If you are running automation at scale with Ansible Automation Platform, you probably have a HashiCorp Vault token sitting in a credential store somewhere. It works, but that token is long-lived, broadly scoped, and one leak away from exposing your secrets. AAP 2.7 introduces a better pattern: OIDC workload identity. Instead of storing a static Vault token, AAP issues a short-lived JWT for each job and authenticates to Vault on the fly. No credentials to rotate. No tokens to leak.

In this post, I will walk through an automated approach to deploy Vault, wire up the OIDC trust with AAP, and validate the integration — all driven by a single Ansible collection.

## How It Works

The flow is straightforward:

1. AAP launches a job and issues a JWT scoped to that specific run
2. Vault validates the JWT against AAP's OIDC discovery endpoint
3. Vault grants read access based on the claims in the token (org, job template, etc.)
4. The secret is injected into the playbook as a variable — no Vault address or token in sight

At no point does a static Vault credential exist in AAP. The trust relationship lives in Vault's JWT auth configuration, and every token is ephemeral.

## Prerequisites

- AAP 2.7+ with `FEATURE_OIDC_WORKLOAD_IDENTITY_ENABLED` set to `True`
- RHEL 8 or 9 target host with Podman (Quadlet support)
- TLS certificate and key for the Vault FQDN
- `containers.podman` collection (handled as a collection dependency)

## The Setup Playbook

The repo is built around a single collection, `demo.zero_trust`, with a `vault` role that uses discrete entry points instead of a monolithic `tasks/main.yml`. Each concern — host prep, install, init, auth config — is a separate `tasks_from` target. The setup playbook loops through them:

```yaml
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

Run it with at least `vault_fqdn` and `vault_jwt_oidc_discovery_url` in your inventory:

```bash
ansible-playbook -i inventory/local.yml playbooks/pb_setup_vault.yml
```

Here is what each step does.

### Host Prep & Install

`configure_host` copies TLS material to the target and opens the Vault port in `firewalld`. Then `install_podman` pulls the Vault image from the Red Hat Connect registry, templates a `vault.hcl` config and a Quadlet unit file, and starts `vault.service` via systemd. The role also supports an RPM install path if you prefer running Vault natively.

### Initialize & Unseal

`init_vault` is idempotent. It checks `vault status`, skips initialization if Vault is already set up, and otherwise writes the root token and unseal keys to `init_data.json` on disk. It then unseals with the first three keys and sets `vault_token` for downstream tasks. All sensitive output is suppressed by default (`vault_no_log: true`).

### JWT Auth — The Core of the Integration

This is where the zero-trust relationship gets established. `configure_jwt_auth` enables the `jwt` auth method in Vault and points it at AAP's OIDC discovery URL:

```yaml
vault_jwt_oidc_discovery_url: https://aap.example.com/o
```

From there, it creates two policy/role pairs:

**Static** — `aap-role-static` grants read on `secret/data/aap/*` for any job from an allowed organization. Simple and broad.

```hcl
path "secret/data/aap/*" {
  capabilities = ["read"]
}
```

**Dynamic** — `aap-role-dynamic` uses Vault identity templating to scope secrets per organization at runtime. The policy path resolves using the `org` metadata mapped from the JWT's `aap_controller_organization_name` claim:

```hcl
path "secret/data/aap/{{identity.entity.aliases.<jwt-accessor>.metadata.org}}/*" {
  capabilities = ["read"]
}
```

A job from the `Default` org can only read secrets under `secret/data/aap/Default/*`. A job from `Autodotes` gets `secret/data/aap/Autodotes/*`. Same role, different access — driven entirely by the JWT claims.

Both roles bind on `aap_controller_organization_name` to restrict which orgs can authenticate at all. The defaults allow `Default` and `Autodotes`, but you can override `vault_jwt_static_bound_claims_organization` for your environment.

### KV Secrets & Userpass

`configure_kv_engine` mounts KV v2 at `secret/` and seeds sample secrets that align with the policy paths — one under `Default`, one under `Autodotes`. These exist so you can validate the OIDC lookup end-to-end without manually creating secrets first.

`configure_userpass_auth` is optional and not OIDC-specific. It creates admin and viewer accounts from a JSON file and auto-generates passwords when omitted. Handy for Vault UI access during the demo.

## Configuring the AAP Credential

This is the one manual step. In the AAP UI:

1. Navigate to **Credentials** > **Add**
2. Select **HashiCorp Vault Secret Lookup (OIDC)** as the credential type
3. Fill in the Vault address, JWT role name (e.g. `aap-role-static`), the KV secret path, and the key to look up
4. Attach the credential to a job template

AAP handles the rest — issuing the JWT, authenticating to Vault, and injecting the secret — before your playbook even starts executing.

## Validating the Setup

The demo playbook is intentionally minimal. It runs on AAP as `localhost` and does two things:

```yaml
- name: Require generic_token from AAP OIDC credential injection
  ansible.builtin.assert:
    that:
      - generic_token is defined
      - (generic_token | string | length) > 0
    fail_msg: >-
      generic_token is not set. Attach a HashiCorp Vault Secret Lookup
      (OIDC) credential to the job template and re-run.
    success_msg: generic_token was injected via AAP Vault OIDC auth

- name: Print generic_token (OIDC secret lookup succeeded)
  ansible.builtin.debug:
    var: generic_token
```

If the assert passes and the secret prints, the full chain worked: AAP issued a JWT, Vault validated it, the KV secret was fetched, and it landed in the playbook as `generic_token`. No Vault address, no token, no auth logic in the playbook itself.

If it fails, the error message tells you exactly what to attach. That is the entire playbook — the complexity lives in the infrastructure setup, not in the automation that consumes it.

## A Case for Ephemeral Credentials

Static credentials are easy to set up but expensive to maintain. They need rotation policies, access reviews, and incident response plans for when they inevitably leak. OIDC workload identity sidesteps all of that. Every token is scoped to a single job and expires automatically.

The setup I have outlined here is fully automated and idempotent. You can tear it down with `pb_uninstall_vault.yml` and rebuild it in minutes. The modular entry-point design means you can also pick and choose — maybe you only need `configure_jwt_auth` because Vault is already running in your environment.

I would recommend starting with the static role for simplicity, then graduating to the dynamic role when you need per-org or per-team secret scoping. The infrastructure is the same; the only difference is the policy template.

[View Source](https://github.com/zjleblanc/ansible-zero-trust) | [AAP 2.7 OIDC Documentation](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/whats_new-oidc_authentication_for_hashicorp_vault)

ansible vault aap oidc zero-trust podman workload-identity
