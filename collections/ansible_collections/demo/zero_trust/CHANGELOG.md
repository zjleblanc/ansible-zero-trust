# Changelog

## 1.0.0

- Initial release of the `demo.zero_trust` collection
- Add `vault` role with host configuration, RPM and Podman install paths, and Vault initialization
- Add `vault` role `uninstall` entry point with RPM/Podman auto-detection and cleanup
- Prefer `containers.podman` modules for registry login, image pull/remove, and container removal; declare `containers.podman` as a dependency
- Add `vault` role `configure_jwt_auth` entry point for AAP OIDC JWT auth with static and dynamic policies/roles
- Add `vault` role `configure_userpass_auth` entry point for userpass users from JSON config (admin/user policies, optional auto-generated passwords)
- Add `vault` role `configure_kv_engine` entry point to enable KV v2 secrets engine and seed sample secrets for e2e testing
- Make `init_vault` idempotent with preflight status check and saved-data reload
- Add `cloudflare` role with `create_tunnel`, `install_podman`, `configure_hostnames`, and `configure_access` entry points
- Declare `community.general` dependency for `cloudflare_dns` CNAME management
