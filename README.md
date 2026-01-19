# mise-env-fnox

A [mise](https://mise.jdx.dev) env plugin that loads secrets from [fnox](https://github.com/jdx/fnox) into your development environment.

## Installation

Add the plugin to your project's `mise.toml`:

```toml
[plugins]
fnox-env = "https://github.com/jdx/mise-env-fnox"

[env]
_.fnox-env = {}
```

## Configuration Options

| Option     | Description         | Default   |
| ---------- | ------------------- | --------- |
| `profile`  | fnox profile to use | `default` |
| `fnox_bin` | Path to fnox binary | `fnox`    |

### Examples

```toml
[plugins]
fnox-env = "https://github.com/jdx/mise-env-fnox"

[env]
# Use default profile
_.fnox-env = {}
```

```toml
[plugins]
fnox-env = "https://github.com/jdx/mise-env-fnox"

[env]
# Use production profile
_.fnox-env = { profile = "production" }
```

## Environment-Specific Configuration

Combine with mise's environment system for different profiles per environment:

```toml
[plugins]
fnox-env = "https://github.com/jdx/mise-env-fnox"

[env]
_.fnox-env = { profile = "dev" }

[env.production]
_.fnox-env = { profile = "production" }

[env.staging]
_.fnox-env = { profile = "staging" }
```

Then activate different environments:

```bash
# Development (default)
mise env

# Production
MISE_ENV=production mise env

# Staging
MISE_ENV=staging mise env
```

## How It Works

When mise activates your environment, the fnox plugin:

1. Searches for `fnox.toml` in the current directory and parent directories
2. Resolves secrets using your configured providers
3. Exports the secrets as environment variables
4. Watches `fnox.toml` for changes to invalidate the cache

## Caching

This plugin supports mise's environment caching (when `MISE_ENV_CACHE=1`). Secrets are:

- Cached encrypted on disk for fast subsequent loads
- Automatically refreshed when `fnox.toml` changes
- Scoped to your shell session for security

To enable caching:

```bash
export MISE_ENV_CACHE=1
```

## License

MIT
