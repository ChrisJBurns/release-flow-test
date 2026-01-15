
# Release Flow Test Helm Chart

![Version: 0.8.0](https://img.shields.io/badge/Version-0.8.0-informational?style=flat-square)
![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square)

Release Flow Test - Simple HTTP server for testing release workflows

**Homepage:** <https://github.com/ChrisJBurns/release-flow-test>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Chris Burns |  | <https://github.com/ChrisJBurns> |

## Source Code

* <https://github.com/ChrisJBurns/release-flow-test>

---

## TL;DR

```console
helm upgrade -i release-flow-test oci://ghcr.io/chrisjburns/release-flow-test/release-flow-test -n release-flow-test --create-namespace
```

## Prerequisites

- Kubernetes 1.25+
- Helm 3.10+

## Usage

### Installing the Chart

```shell
helm upgrade -i <release_name> oci://ghcr.io/chrisjburns/release-flow-test/release-flow-test --version=<version> -n <namespace> --create-namespace
```

> **Tip**: List all releases using `helm list`

### Uninstalling the Chart

To uninstall/delete the deployment:

```console
helm uninstall <release_name>
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Values

| Key | Type | Default | Description |
|-----|-------------|------|---------|
| affinity | object | `{}` |  |
| image.imageTagWithPrefixAndQuotes | string | `"ghcr.io/chrisjburns/release-flow-test:v0.8.0"` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `"ghcr.io/chrisjburns/release-flow-test"` |  |
| image.tag | string | `"0.8.0"` |  |
| image.tagUnquoted | string | `"0.8.0"` |  |
| image.tagWithPrefixAndQuotes | string | `"v0.8.0"` |  |
| image.tagWithPrefixAndUnquoted | string | `"v0.8.0"` |  |
| initContainers | list | `[]` | Init containers to run before the main container Use this for setup tasks like preparing pgpass files, waiting for dependencies, etc. Init containers share the same volumes as the main container (extraVolumes) |
| nodeSelector | object | `{}` |  |
| replicaCount | int | `1` |  |
| resources | object | `{}` |  |
| service.port | int | `8080` |  |
| service.type | string | `"ClusterIP"` |  |
| tolerations | list | `[]` |  |

