# Zero Trust Automation: Vault + AAP OIDC Workload Identity with Ansible

> **Tags:** ansible, vault, aap, oidc, zero-trust, podman, workload-identity
>
> **Source:** [ansible-zero-trust](https://github.com/zjleblanc/ansible-zero-trust)

---

## Introduction

- Open with the zero-trust trend in enterprise automation — static credentials are the norm, but they create risk (rotation burden, leakage surface, over-privileged tokens sitting in credential stores)
- Introduce AAP 2.7's OIDC workload identity feature: the platform can now act as an OpenID Connect Identity Provider, issuing short-lived JWTs per job instead of storing long-lived Vault tokens
- State the goal of the post: walk through an Ansible-driven approach to deploy HashiCorp Vault, configure the OIDC trust relationship with AAP, and validate the integration end-to-end — all from code in a single repository
- Mention the `demo.zero_trust` collection and the modular role design (entry-point-per-concern) that makes each step independently reusable

## Prerequisites

- AAP 2.7+ with `FEATURE_OIDC_WORKLOAD_IDENTITY_ENABLED` set to `True`
- RHEL/EL 8 or 9 target host for Vault (Podman with Quadlet support)
- TLS certificate and key for the Vault FQDN (self-signed is fine for a demo)
- `containers.podman` collection installed (collection dependency handles this)
- Ansible 2.17+ (required by the collection)
- A container registry credential for the Red Hat Connect registry (optional — only needed for authenticated image pulls)

## Architecture Overview

- Diagram or description of the flow:
  1. Ansible deploys and initializes Vault on the target host
  2. Ansible configures Vault JWT auth with AAP's OIDC discovery URL
  3. Ansible seeds KV secrets and policies aligned to AAP JWT claims
  4. At job time, AAP issues a JWT → authenticates to Vault → fetches a KV secret → injects it into the playbook as `generic_token`
- Emphasize that no static Vault token is stored in AAP at any point
- Reference the example JWT claims payload (`files/aap_claims.example.json`) and explain which claims map to Vault roles and policies

## Step 1 — Prepare the Host (`configure_host`)

- Explain the entry-point pattern: `include_role` with `tasks_from` instead of a monolithic role
- Walk through what `configure_host` does:
  - Copies TLS cert and key to the target when sources are provided
  - Opens `vault_port/tcp` in `firewalld`
- Show the relevant variables (`vault_tls_cert_src`, `vault_tls_key_src`, `vault_port`)
- Note: TLS is optional for a quick demo but recommended for production

## Step 2 — Install Vault via Podman Quadlet (`install_podman`)

- Explain the two install paths (RPM vs Podman) and why the post uses Podman Quadlet
- Walk through the task flow:
  - Installs `podman`, optionally authenticates to the container registry
  - Pulls the Vault image from `registry.connect.redhat.com/hashicorp/vault`
  - Creates host directories with the correct container UID/GID (100:100)
  - Templates `vault.hcl` (file storage, listener config, TLS) and the Quadlet unit file
  - Enables and starts `vault.service` via systemd
  - Sets `vault_cli` (a `podman exec` wrapper) and `vault_cli_addr` for downstream tasks
- Highlight the Quadlet approach as a rootful systemd-native container pattern

## Step 3 — Initialize and Unseal (`init_vault`)

- Describe the idempotent init logic:
  - Checks `vault status` — skips init if already initialized
  - Writes `init_data.json` to the storage path (root token + unseal keys)
  - Unseals with the first three keys when sealed
  - Sets `vault_token` from the root token for subsequent API calls
- Mention that `vault_no_log: true` suppresses sensitive output by default
- Show the debug output that confirms Vault is initialized and unsealed

## Step 4 — Configure JWT Auth for AAP OIDC (`configure_jwt_auth`)

- This is the core of the zero-trust integration — spend the most time here
- Walk through each sub-step:
  1. **Enable JWT auth** — idempotent check against `auth list`
  2. **Set OIDC discovery** — points Vault at AAP's `/.well-known/openid-configuration` endpoint via `vault_jwt_oidc_discovery_url`; optionally provides a CA PEM for self-signed AAP certs
  3. **Static policy and role** — `aap-policy-static` grants read on `secret/data/aap/*`; `aap-role-static` binds to the AAP audience and allowed orgs
  4. **Dynamic (templated) policy and role** — `aap-policy-dynamic` uses Vault identity metadata (`org` mapped from `aap_controller_organization_name`) to scope secret paths per organization at runtime
- Explain the difference between static and dynamic roles with a concrete example:
  - Static: any job from an allowed org can read anything under `secret/data/aap/*`
  - Dynamic: a job from org `Default` can only read `secret/data/aap/Default/*`
- Reference the default variables and how to customize bound claims, audiences, and path templates

## Step 5 — Seed KV Secrets (`configure_kv_engine`)

- Enables KV v2 at `secret/`
- Seeds sample secrets that align with the JWT policy paths:
  - `secret/data/aap/Default/ansible-sa`
  - `secret/data/aap/Autodotes/autodotes-sa`
- Explain why the paths matter — they must match the policy grants so the OIDC lookup succeeds

## Step 6 — Configure Userpass Auth (`configure_userpass_auth`)

- Brief section — this is complementary, not OIDC-specific
- Creates admin and viewer users from `files/vault_users.json`
- Auto-generates passwords when omitted, saves them to `userpass_credentials.json`
- Useful for Vault UI access during the demo or day-2 operations

## Running the Setup Playbook

- Show `pb_setup_vault.yml` and explain the loop-driven design (iterates `vault_tasks` and calls `include_role` for each entry point)
- Minimum inventory requirements: `vault_fqdn` and `vault_jwt_oidc_discovery_url`
- Example run command:

  ```bash
  ansible-playbook -i inventory/local.yml playbooks/pb_setup_vault.yml
  ```

- Summarize expected outcomes in a table (host configured → Vault running → initialized → JWT auth wired → secrets seeded → users created)

## Configuring the AAP Credential

- This is an AAP UI step (not automated by the repo) — walk through it briefly:
  1. Navigate to **Credentials** → **Add** in AAP
  2. Select the **HashiCorp Vault Secret Lookup (OIDC)** credential type
  3. Fill in the Vault address, JWT role name (e.g. `aap-role-static`), KV path, and key
  4. Attach the credential to a job template that runs `pb_demo_oidc.yml`
- Mention the Signed SSH (OIDC) credential type as an alternative for SSH certificate workflows

## Validating the Integration (`pb_demo_oidc.yml`)

- Explain that this playbook is designed to run **on AAP**, not from a local terminal
- Walk through the two tasks:
  1. **Assert** — confirms `generic_token` was injected by the OIDC credential; if not, the fail message tells the operator exactly what to attach
  2. **Debug** — prints the secret value to prove the full OIDC chain worked (AAP issued JWT → Vault validated → KV secret returned → injected as extra var)
- Emphasize the simplicity: no Vault address, no token, no auth code in the playbook — AAP handles everything transparently
- Show what a successful job output looks like (assert passes, secret prints)

## Conclusion

- Recap the zero-trust value: ephemeral, job-scoped credentials replace static tokens; secrets access is authenticated, authorized, and time-bound
- Highlight that the entire Vault stack — install, init, OIDC config, secrets, and users — is automated and idempotent, making it reproducible across environments
- Call out the modular entry-point design as a pattern worth adopting: each concern (host prep, install, init, auth, secrets) is independently testable and composable
- Close with a recommendation: start with the static role for simplicity, then graduate to the dynamic (templated) role when you need per-org or per-team secret scoping
- Link to the repository and the [Red Hat documentation for AAP 2.7 OIDC credential types](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.7/whats_new-oidc_authentication_for_hashicorp_vault)
