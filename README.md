# 🔍 TOMP API Validator - Github Action

GitHub Action to validate OpenAPI specifications against the [TOMP-API](https://github.com/TOMP-WG/TOMP-API) reference specification. This action ensures your API implementation remains compatible with the TOMP (Transport Operator Mobility-as-a-Service Provider) standard by detecting breaking changes during CI/CD.

## 📋 Overview

This action performs semantic comparison between your OpenAPI specification and the official TOMP-API reference, helping you:
- Detect breaking changes before they reach production
- Ensure compliance with TOMP mobility standards
- Maintain backward compatibility in your API implementation
- Automate API validation in your CI/CD pipeline

## 💥 Features

- **Semantic Validation**: Uses [openapi-diff](https://github.com/OpenAPITools/openapi-diff) for deep semantic comparison
- **Version Flexibility**: Compare against latest TOMP-API release or specific version tags
- **Change Classification**: Detects breaking, non-breaking, and unclassified changes
- **Docker-based**: Runs in isolated container environment for consistency
- **Configurable Strictness**: Choose whether to fail on breaking changes only or also on non-breaking changes
- **Detailed Reporting**: Provides clear output about detected changes and their impact

## 📦 Inputs

| Name | Required | Default | Description |
|------|----------|---------|-------------|
| `candidate_spec` | ✅ | – | Path to your OpenAPI YAML file |
| `version_tag` | ❌ | latest | TOMP-API release tag (e.g. `v1.3.0`) |
| `fail_on_breaking_changes` | ❌ | `true` | Fail build on breaking changes |
| `fail_on_non_breaking_changes` | ❌ | `false` | Fail build on non-breaking changes |
| `show_unclassified` | ❌ | `true` | Show unclassified changes |

## 🧪 Example Usage

### Basic Usage (compares against latest TOMP-API)
```yaml
jobs:
  openapi-compat:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: basmatthee/TOMP-API-validator-action@v1
        with:
          candidate_spec: api/openapi/generated/openapi.yaml
```

### Specific Version Comparison
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
```

### Strict Mode (fail on any changes)
```yaml
jobs:
  openapi-compat:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: basmatthee/TOMP-API-validator-action@v1
        with:
          candidate_spec: api/openapi/generated/openapi.yaml
          fail_on_breaking_changes: true
          fail_on_non_breaking_changes: true
```

## 🔧 How It Works

1. **Reference Download**: The action fetches the TOMP-API reference specification from the official repository
2. **Docker Execution**: Runs openapi-diff in a Docker container to ensure consistent environment
3. **Semantic Comparison**: Analyzes differences between your spec and the reference
4. **Result Classification**: Categorizes changes as breaking, non-breaking, or unclassified
5. **CI Integration**: Exits with appropriate status codes based on your configuration

## 🛡️ Recent Improvements

The validation script has been enhanced with:
- **Better Change Detection**: Improved pattern matching to correctly distinguish between BREAKING and NON_BREAKING changes
- **Robust Error Handling**: Docker command failures are now properly caught and reported
- **Path Safety**: Files outside the current directory are handled safely via temporary copies
- **JSON Parsing**: Uses `jq` when available for reliable GitHub API parsing, with improved fallback
- **File Validation**: Added checks for file readability and basic YAML format validation
- **Automatic Cleanup**: Temporary files are cleaned up after execution

## 🤝 Credits

This action is powered by [openapi-diff](https://github.com/OpenAPITools/openapi-diff) from OpenAPITools.
