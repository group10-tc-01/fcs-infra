# FCS Infra

O `fcs-infra` é a fonte declarativa da infraestrutura compartilhada da
Conexão Solidária. Ele provisiona e configura a base da VPS/K3s, os namespaces,
os serviços de plataforma e seus contratos de segredo.

## Responsabilidades

- Terraform e state remoto no HCP Terraform
- K3s, Traefik, cert-manager e Infisical Secrets Operator
- SQL Server, Kafka, MongoDB, Keycloak, OpenTelemetry e Datadog
- Namespaces e contratos consumidos pelos repositórios de aplicação

Consulte o [README](../README.md) e o guia
[`fcs-vps-infra-guide`](https://github.com/group10-tc-01/fcs-vps-infra-guide)
para operação e recuperação.
