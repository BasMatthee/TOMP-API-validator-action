# 🔍 TOMP API Validator - Github Action

GitHub Action to compare a candidate OpenAPI spec against the [TOMP-API](https://github.com/TOMP-WG/TOMP-API) reference spec.

Fails your CI if there are breaking changes.

## 💥 Features

- Uses [openapi-diff](https://github.com/OpenAPITools/openapi-diff)
- Downloads TOMP-API reference (latest or tagged version)
- Compares structure and semantics

## 📦 Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `candidate_spec` | ✅ | – | Path to your OpenAPI YAML file |
| `version_tag` | ❌ | latest | TOMP-API release tag (e.g. `v1.3.0`) |
| `fail_on_breaking_changes` | ❌ | `true` | Fail build on breaking changes |
| `fail_on_non_breaking_changes` | ❌ | `false` | Fail build on non-breaking changes |
| `show_unclassified` | ❌ | `true` | Show unclassified changes |

## 🧪 Example Usage

```yaml
jobs:
  openapi-compat:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: basmatthee/TOMP-API-validator-action@v1
        with:
          candidate_spec: api/openapi/generated/openapi.yaml
          version_tag: v1.3.0
