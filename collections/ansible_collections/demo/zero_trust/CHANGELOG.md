# Changelog

## 1.0.0

- Initial release of the `demo.zero_trust` collection
- Add `vault` role with host configuration, RPM and Podman install paths, and Vault initialization
- Add `vault` role `uninstall` entry point with RPM/Podman auto-detection and cleanup
- Prefer `containers.podman` modules for registry login, image pull/remove, and container removal; declare `containers.podman` as a dependency
