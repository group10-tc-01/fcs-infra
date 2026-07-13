#!/usr/bin/env bash
set -euo pipefail

# A cancelled Terraform apply can create Kubernetes objects before the remote
# state is written. Adopt only objects that are present in Kubernetes but absent
# from state, so normal clean installs keep creating resources declaratively.
state_resources="$(terraform state list -lock=false)"

is_managed() {
  grep -Fxq "$1" <<<"$state_resources"
}

adopt_manifest() {
  local address="$1"
  local api_version="$2"
  local kind="$3"
  local resource="$4"
  local namespace="$5"
  local name="$6"
  local import_id="apiVersion=${api_version},kind=${kind}"

  if is_managed "$address"; then
    echo "Already managed: $address"
    return
  fi

  if [[ -n "$namespace" ]]; then
    if ! kubectl -n "$namespace" get "$resource" "$name" >/dev/null 2>&1; then
      echo "Not present; Terraform will create: $address"
      return
    fi
    import_id+=",namespace=${namespace}"
  elif ! kubectl get "$resource" "$name" >/dev/null 2>&1; then
    echo "Not present; Terraform will create: $address"
    return
  fi

  import_id+=",name=${name}"
  echo "Adopting: $address"
  terraform import -lock-timeout=5m -var=apply_cluster=true -var=apply_platform=true "$address" "$import_id"
  state_resources+=$'\n'"$address"
}

adopt_helm_release() {
  local address="$1"
  local namespace="$2"
  local name="$3"

  if is_managed "$address"; then
    echo "Already managed: $address"
    return
  fi

  if ! kubectl -n "$namespace" get secret "sh.helm.release.v1.${name}.v1" >/dev/null 2>&1; then
    echo "Not present; Terraform will create: $address"
    return
  fi

  echo "Adopting: $address"
  terraform import -lock-timeout=5m -var=apply_cluster=true -var=apply_platform=true "$address" "${namespace}/${name}"
  state_resources+=$'\n'"$address"
}

adopt_manifest 'module.platform[0].kubernetes_manifest.infisical_connection' 'secrets.infisical.com/v1beta1' 'InfisicalConnection' 'infisicalconnection' 'infisical-operator-system' 'infisical-cloud'
adopt_manifest 'module.platform[0].kubernetes_manifest.letsencrypt' 'cert-manager.io/v1' 'ClusterIssuer' 'clusterissuer' '' 'letsencrypt-production'
adopt_manifest 'module.platform[0].kubernetes_manifest.infisical_auth' 'secrets.infisical.com/v1beta1' 'InfisicalAuth' 'infisicalauth' 'infisical-operator-system' 'fcs-platform-auth'
adopt_manifest 'module.platform[0].kubernetes_manifest.platform_runtime' 'secrets.infisical.com/v1beta1' 'InfisicalStaticSecret' 'infisicalstaticsecret' 'fcs-infra' 'fcs-infra-runtime'
adopt_manifest 'module.platform[0].kubernetes_manifest.datadog_api_key' 'secrets.infisical.com/v1beta1' 'InfisicalStaticSecret' 'infisicalstaticsecret' 'fcs-infra' 'fcs-datadog-api-key'
adopt_helm_release 'module.platform[0].helm_release.datadog' 'fcs-infra' 'fcs-datadog'

adopt_manifest 'module.platform[0].kubernetes_manifest.platform["ConfigMap-fcs-infra-keycloak-realm-config"]' 'v1' 'ConfigMap' 'configmap' 'fcs-infra' 'keycloak-realm-config'
adopt_manifest 'module.platform[0].kubernetes_manifest.platform["Job-fcs-infra-keycloak-bootstrap"]' 'batch/v1' 'Job' 'job' 'fcs-infra' 'keycloak-bootstrap'
adopt_manifest 'module.platform[0].kubernetes_manifest.platform["Service-fcs-infra-sqlserver-service"]' 'v1' 'Service' 'service' 'fcs-infra' 'sqlserver-service'
adopt_manifest 'module.platform[0].kubernetes_manifest.platform["StatefulSet-fcs-infra-sqlserver"]' 'apps/v1' 'StatefulSet' 'statefulset' 'fcs-infra' 'sqlserver'
adopt_manifest 'module.platform[0].kubernetes_manifest.platform["ConfigMap-fcs-infra-sqlserver-init-config"]' 'v1' 'ConfigMap' 'configmap' 'fcs-infra' 'sqlserver-init-config'
adopt_manifest 'module.platform[0].kubernetes_manifest.platform["Job-fcs-infra-sqlserver-init"]' 'batch/v1' 'Job' 'job' 'fcs-infra' 'sqlserver-init'
adopt_manifest 'module.platform[0].kubernetes_manifest.platform["Service-fcs-infra-kafka-service"]' 'v1' 'Service' 'service' 'fcs-infra' 'kafka-service'
adopt_manifest 'module.platform[0].kubernetes_manifest.platform["StatefulSet-fcs-infra-kafka"]' 'apps/v1' 'StatefulSet' 'statefulset' 'fcs-infra' 'kafka'
adopt_manifest 'module.platform[0].kubernetes_manifest.platform["Job-fcs-infra-kafka-topics-init"]' 'batch/v1' 'Job' 'job' 'fcs-infra' 'kafka-topics-init'
adopt_manifest 'module.platform[0].kubernetes_manifest.platform["Service-fcs-infra-mongodb-service"]' 'v1' 'Service' 'service' 'fcs-infra' 'mongodb-service'
adopt_manifest 'module.platform[0].kubernetes_manifest.platform["StatefulSet-fcs-infra-mongodb"]' 'apps/v1' 'StatefulSet' 'statefulset' 'fcs-infra' 'mongodb'
adopt_manifest 'module.platform[0].kubernetes_manifest.platform["Service-fcs-infra-keycloak-service"]' 'v1' 'Service' 'service' 'fcs-infra' 'keycloak-service'
adopt_manifest 'module.platform[0].kubernetes_manifest.platform["Deployment-fcs-infra-keycloak"]' 'apps/v1' 'Deployment' 'deployment' 'fcs-infra' 'keycloak'
adopt_manifest 'module.platform[0].kubernetes_manifest.platform["Service-fcs-infra-kafka-ui-service"]' 'v1' 'Service' 'service' 'fcs-infra' 'kafka-ui-service'
adopt_manifest 'module.platform[0].kubernetes_manifest.platform["Deployment-fcs-infra-kafka-ui"]' 'apps/v1' 'Deployment' 'deployment' 'fcs-infra' 'kafka-ui'
adopt_manifest 'module.platform[0].kubernetes_manifest.platform["ConfigMap-fcs-infra-otel-collector-config"]' 'v1' 'ConfigMap' 'configmap' 'fcs-infra' 'otel-collector-config'
adopt_manifest 'module.platform[0].kubernetes_manifest.platform["Deployment-fcs-infra-otel-collector"]' 'apps/v1' 'Deployment' 'deployment' 'fcs-infra' 'otel-collector'
adopt_manifest 'module.platform[0].kubernetes_manifest.platform["Service-fcs-infra-otel-collector-service"]' 'v1' 'Service' 'service' 'fcs-infra' 'otel-collector-service'
