# fcs-infra

Repositório de **Infraestrutura Compartilhada** da plataforma **Conexão Solidária**. Centraliza o ambiente integrado da demo, manifests Kubernetes compartilhados, configurações de plataforma e Terraform para provisionamento na Azure.

> Repositório de apoio que compõe o MVP da Conexão Solidária junto a `fcs-identity`, `fcs-campaigns`, `fcs-donations`, `fcs-donation-worker`, `fcs-audit-logs`, `fcs-bff`, `fcs-web` e `fcs-pipelines`.

---

## Responsabilidades

- Orquestrar o ambiente local completo com **Docker Compose**.
- Manter manifests Kubernetes integrados para **Kind** e **AKS**.
- Declarar namespaces, ConfigMaps e Secrets de referência sem valores sensíveis reais.
- Manter configuração do **Keycloak** para realm, clients e roles canônicas `GestorONG` e `Doador`.
- Manter configuração de **Kafka**, **Kafka UI** e tópicos da plataforma.
- Manter configuração de **MongoDB** para auditoria centralizada.
- Manter **Datadog Agent**, **Datadog Cluster Agent** e dashboards do **Datadog** para observabilidade.
- Provisionar recursos Azure com **Terraform**.
- Representar o **Azure API Management** como borda pública das APIs.
- Documentar o passo a passo do ambiente completo da demo.

O `fcs-infra` orquestra o ambiente integrado, mas não substitui os arquivos de cada aplicação. Cada serviço continua dono do próprio `Dockerfile`, manifests base e pipeline.

Documentação completa da arquitetura: [group10-tc-01/fcs-fase05-docs](https://github.com/group10-tc-01/fcs-fase05-docs).

Referências diretas:

- [Visão geral da arquitetura](https://github.com/group10-tc-01/fcs-fase05-docs/blob/main/architecture/overview.md)
- [Repositórios e infraestrutura](https://github.com/group10-tc-01/fcs-fase05-docs/blob/main/architecture/repositories-and-infra.md)
- [Endpoints consolidados](https://github.com/group10-tc-01/fcs-fase05-docs/blob/main/architecture/endpoints.md)

ADRs relevantes:

- [ADR 0014 - AKS como alvo Kubernetes na Azure](https://github.com/group10-tc-01/fcs-fase05-docs/blob/main/adr/0014-use-aks-as-azure-kubernetes-target.md)
- [ADR 0015 - ACR para imagens de container](https://github.com/group10-tc-01/fcs-fase05-docs/blob/main/adr/0015-use-acr-for-container-images.md)
- [ADR 0016 - SQL gerenciado na Azure](https://github.com/group10-tc-01/fcs-fase05-docs/blob/main/adr/0016-use-managed-sql-on-azure.md)
- [ADR 0017 - Key Vault para segredos](https://github.com/group10-tc-01/fcs-fase05-docs/blob/main/adr/0017-use-key-vault-for-secrets.md)
- [ADR 0018 - Kafka dentro do Kubernetes](https://github.com/group10-tc-01/fcs-fase05-docs/blob/main/adr/0018-run-kafka-inside-kubernetes.md)
- [ADR 0019 - Keycloak dentro do Kubernetes](https://github.com/group10-tc-01/fcs-fase05-docs/blob/main/adr/0019-run-keycloak-inside-kubernetes.md)
- [ADR 0020 - Datadog para observabilidade](https://github.com/group10-tc-01/fcs-fase05-docs/blob/main/adr/0020-use-datadog-for-observability.md)
- [ADR 0026 - Namespaces Kubernetes separados](https://github.com/group10-tc-01/fcs-fase05-docs/blob/main/adr/0026-use-separated-kubernetes-namespaces.md)
- [ADR 0028 - Azure API Management como borda pública](https://github.com/group10-tc-01/fcs-fase05-docs/blob/main/adr/0028-use-azure-api-management-as-public-edge.md)
- [ADR 0029 - Kind para Kubernetes local](https://github.com/group10-tc-01/fcs-fase05-docs/blob/main/adr/0029-use-kind-for-local-kubernetes.md)
- [ADR 0030 - Auditoria explícita de negócio](https://github.com/group10-tc-01/fcs-fase05-docs/blob/main/adr/0030-use-explicit-business-audit-logs.md)

---

## Componentes de plataforma

| Componente | Uso |
|------------|-----|
| SQL Server | Databases `IdentityDb`, `CampaignsDb`, `DonationsDb` e `KeycloakDb` em ambiente local |
| MongoDB | Database `AuditLogsDb` da auditoria centralizada |
| Keycloak | Identidade, emissão de JWT e roles `GestorONG` e `Doador` |
| Kafka | Mensageria dos tópicos `donation-received` e `audit-log-requested` |
| Kafka UI | Apoio operacional para inspeção dos tópicos |
| Datadog Agent | Coleta de métricas, logs, traces e APM em ambiente local e Kubernetes |
| Datadog Cluster Agent | Coleta de métricas e metadados Kubernetes em AKS/Kind |
| Datadog | Dashboards da demo, métricas reais, logs e APM |
| Azure SQL | Bancos SQL gerenciados no ambiente Azure |
| Azure Key Vault | Segredos e configurações sensíveis no ambiente Azure |
| Azure Container Registry | Registro das imagens das aplicações |
| AKS | Cluster Kubernetes do ambiente Azure |
| Azure API Management | Borda pública e rate limiting |

---

## Namespaces Kubernetes

Namespaces confirmados:

| Namespace | Conteúdo |
|-----------|----------|
| `fcs-identity` | API de identidade |
| `fcs-campaigns` | API de campanhas |
| `fcs-donations` | API de doações |
| `fcs-donation-worker` | Worker de processamento de doações |
| `fcs-audit-logs` | Worker/API de auditoria centralizada |
| `fcs-infra` | Keycloak, Kafka, Kafka UI, MongoDB, Datadog Agent, Datadog Cluster Agent e componentes compartilhados |