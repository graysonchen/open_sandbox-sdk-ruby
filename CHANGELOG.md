## [Unreleased]

## [0.1.0] - 2026-04-29

### Added
- Initial release
- `OpenSandbox::Client` with global `configure` block and singleton `OpenSandbox.client`
- `Sandboxes` resource: `list`, `get`, `create`, `delete`, `pause`, `resume`, `renew_expiration`, `endpoint`, `proxy`, `wait_until`
- `Sandboxes` diagnostics: `logs`, `inspect_container`, `events`, `diagnostics`
- `Pools` resource: `list`, `get`, `create`, `update`, `delete`
- Typed value objects: `Sandbox`, `SandboxStatus`, `Endpoint`, `Pool`, `PoolCapacitySpec`, `SandboxList`, `PaginationInfo`
- Full error hierarchy: `InvalidRequestError`, `AuthenticationError`, `ForbiddenError`, `NotFoundError`, `ConflictError`, `ValidationError`, `ServerError`, `ConnectionError`
- Configurable `Logger` (silent by default)
- Docker timestamp stripping utility (`OpenSandbox::LogUtils.strip_timestamps`)
