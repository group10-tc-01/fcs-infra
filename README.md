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

---

## Estrutura do projeto

Estrutura esperada do repositório:

```text
docker/
  docker-compose.yml                 # Ambiente integrado local
  observability/                     # Stack local Datadog Agent e OpenTelemetry Collector
k8s/
  apps/                              # Referências integradas das aplicações
  platform/                          # Keycloak, Kafka, MongoDB e componentes compartilhados
  observability/                     # Datadog Agent, Datadog Cluster Agent e configuracoes de observabilidade
keycloak/
  conexao-solidaria-realm.json       # Realm, clients e roles
kafka/
  topics/                            # Tópicos donation-received e audit-log-requested
mongodb/
  init/                              # Inicialização do AuditLogsDb quando aplicável
datadog/
  dashboards/                        # Definicoes e referencias dos dashboards da demo
terraform/
  environments/
    dev/                             # Ambiente Azure de desenvolvimento/demo
  modules/                           # Módulos reutilizáveis
docs/                                # Notas operacionais do ambiente integrado
```

---

## Superfície pública

O **Azure API Management** é a borda pública da plataforma em Azure.

Rotas públicas esperadas:

- `fcs-bff` como fachada principal consumida pelo `fcs-web`.
- APIs de negócio quando necessário para a demo, sempre com JWT/RBAC validado pelas próprias APIs.

Rotas que **não** devem ser publicadas no APIM:

- `/internal/*`
- `/metrics`
- `/health`

Validação de JWT e autorização por roles continuam dentro das APIs. O APIM aplica centralização de entrada e rate limiting, mas não substitui as políticas de segurança das aplicações.

---

## Pré-requisitos

- [Docker](https://docs.docker.com/get-docker/) e Docker Compose
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Kind](https://kind.sigs.k8s.io/)
- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- Acesso aos repositórios da organização `group10-tc-01`

Para executar o ambiente completo também é necessário ter as imagens dos serviços disponíveis localmente ou publicadas no registry configurado.

---

## Subindo o ambiente local com Docker Compose

O `docker/docker-compose.yml` deste repositório deve subir o ambiente integrado da Conexão Solidária.

```bash
docker compose -f docker/docker-compose.yml up -d
```

As imagens dos backends sao consumidas do GHCR (`ghcr.io/group10-tc-01/*:main`). Se os pacotes estiverem privados, autentique antes com `docker login ghcr.io`.

Serviços esperados:

- SQL Server
- MongoDB
- Keycloak
- Kafka
- Kafka UI
- Seq
- OpenTelemetry Collector
- APIs e workers backend da plataforma

URLs úteis em ambiente local:

- Keycloak Admin Console: `http://localhost:8081`
- Kafka UI: `http://localhost:8082`
- Seq: `http://localhost:5341`
- OpenTelemetry Collector OTLP gRPC: `localhost:4317`
- OpenTelemetry Collector OTLP HTTP: `localhost:4318`
- MongoDB: `localhost:27017`
- SQL Server: `localhost,1433`
- Identity API: `http://localhost:64534`
- Campaign API: `http://localhost:55904`
- Donations API: `http://localhost:5003`
- BFF API: `http://localhost:5004`
- Donation Worker: `http://localhost:5005`
- Audit Logs Worker: `http://localhost:5006`

> Valores de usuário e senha devem ser mantidos em arquivos `.env` locais ou secrets do ambiente. Não versionar credenciais reais.

---

## Subindo apenas a observabilidade local

A stack de observabilidade em Docker Compose fica em `docker/observability` e pode ser usada antes dos manifests Kind estarem completos.

```bash
cd docker/observability
cp .env.example .env
# preencha DD_API_KEY e ajuste DD_SITE conforme sua conta
docker compose --env-file .env up -d
```

Componentes expostos:

- Datadog Agent APM: `localhost:8126`
- Datadog Agent DogStatsD: `localhost:8125/udp`
- OpenTelemetry Collector OTLP gRPC: `localhost:4317`
- OpenTelemetry Collector OTLP HTTP: `localhost:4318`

O Datadog Agent coleta telemetria dos containers locais e o OpenTelemetry Collector recebe OTLP dos serviços instrumentados. Dashboards, logs, métricas e APM são visualizados no Datadog.

Detalhes operacionais: [docker/observability/README.md](docker/observability/README.md).

---

## Subindo o ambiente local com Kind

Kind é o ambiente Kubernetes local padrão da fase 5.

Os manifests locais ficam em [`k8s/`](./k8s) e usam as imagens `ghcr.io/group10-tc-01/*:main` dos repositórios da plataforma.

### Fluxo automatizado

```bash
cd k8s
bash up.sh
```

Se os packages GHCR estiverem privados, exporte `GHCR_USERNAME` e `GHCR_TOKEN` antes de executar o script. Para enviar telemetria ao Datadog, exporte `DD_API_KEY` e `DD_SITE`.

### Fluxo manual

#### 1. Criar o cluster

```bash
kind create cluster --name fcs-local --config k8s/kind-cluster-config.yaml
```

#### 2. Aplicar namespaces

```bash
kubectl apply -f k8s/manifests/00-namespaces.yaml
```

#### 3. Aplicar componentes compartilhados

```bash
kubectl apply -f k8s/manifests/infra
```

#### 4. Aplicar aplicações

```bash
kubectl apply -f k8s/manifests/apps/fcs-identity
kubectl apply -f k8s/manifests/apps/fcs-campaign
kubectl apply -f k8s/manifests/apps/fcs-donations
kubectl apply -f k8s/manifests/apps/fcs-donation-worker
kubectl apply -f k8s/manifests/apps/fcs-audit-logs
kubectl apply -f k8s/manifests/apps/fcs-web
```

#### 5. Verificar pods

```bash
kubectl get pods --all-namespaces
```

---

## Azure e Terraform

O Terraform deste repositório deve provisionar os recursos Azure da demo.

Recursos esperados:

- Resource Group
- Azure Container Registry
- AKS
- Azure SQL Server e databases `IdentityDb`, `CampaignsDb`, `DonationsDb` e `KeycloakDb`
- Azure Key Vault
- Azure API Management
- Integrações necessárias para o AKS consumir imagens do ACR e segredos do Key Vault

Fluxo esperado:

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

As variáveis de ambiente, nomes de recursos, regiões e secrets devem ser parametrizados por ambiente. Segredos reais não devem ser versionados.

---

## Observabilidade

Datadog Agent e Datadog Cluster Agent rodam dentro do Kubernetes no namespace `fcs-infra` na arquitetura final. Para desenvolvimento local imediato, a stack Docker Compose em `docker/observability` fornece Datadog Agent e OpenTelemetry Collector.

Dashboard mínimo esperado:

- CPU e memória dos pods
- Status dos pods
- Contagem de requisições HTTP
- Latência das APIs quando disponível
- Métricas de processamento dos workers
- Estado dos componentes compartilhados

Endpoints operacionais das aplicações:

- `GET /health`
- `GET /metrics`

Destino OTLP padrão para serviços instrumentados em container:

- `http://otel-collector:4318`

Esses endpoints são internos/operacionais e não devem ser expostos pelo APIM.

---

## Mensageria e auditoria

Tópicos Kafka confirmados:

| Tópico | Produtores | Consumidores |
|--------|------------|--------------|
| `donation-received` | `fcs-donations` | `fcs-donation-worker` |
| `audit-log-requested` | Serviços de negócio e workers | `fcs-audit-logs` |

O `fcs-audit-logs` consome `audit-log-requested` e persiste os registros no MongoDB (`AuditLogsDb`). Os serviços de negócio não mantêm tabela `AuditLogs` em seus bancos SQL.

---

## Segurança

- Não versionar credenciais reais.
- Usar `.env` local apenas para desenvolvimento.
- Usar Azure Key Vault para segredos em Azure.
- Usar ConfigMaps e Secrets Kubernetes apenas com valores de referência no repositório.
- Manter endpoints `/internal/*` privados dentro do cluster.
- Manter `/health` e `/metrics` fora do APIM.
- Validar JWT e RBAC dentro das APIs.
- Usar roles canônicas `GestorONG` e `Doador`.

---

## CI/CD

A esteira deste repositório deve reutilizar os workflows do `fcs-pipelines` ([ADR 0022](https://github.com/group10-tc-01/fcs-fase05-docs/blob/main/adr/0022-reuse-fcs-pipelines-for-ci-cd.md)).

Workflow esperado para infraestrutura:

```text
group10-tc-01/fcs-pipelines/.github/workflows/terraform-azure.yml@main
```

Gates principais:

- branch policy
- secret scan com Gitleaks
- validação de Terraform
- plano Terraform
- apply controlado por ambiente quando habilitado

---

## Como este repositório atende ao hackathon

| Requisito do hackathon | Onde é atendido |
|------------------------|-----------------|
| Kubernetes local | Kind e manifests em `k8s/` |
| Kubernetes em cloud | AKS provisionado por Terraform |
| YAMLs de Deployments, Services e ConfigMaps | Manifests integrados em `k8s/` |
| Banco relacional gerenciado | Azure SQL para databases dos serviços |
| Auditoria centralizada | MongoDB `AuditLogsDb` e Kafka `audit-log-requested` |
| Mensageria assíncrona | Kafka e tópicos da plataforma |
| Autenticação e RBAC | Keycloak com roles `GestorONG` e `Doador` |
| Observabilidade | Datadog, `/health` e `/metrics` |
| API Gateway na Azure | Azure API Management |
| CI/CD e IaC | `fcs-pipelines` + Terraform |

Os fluxos de **Identidade**, **Campanhas**, **Intenção de Doação**, **Processamento de Doação**, **Auditoria** e **Frontend** são implementados pelos demais repositórios da plataforma. Veja a [visão geral da arquitetura](https://github.com/group10-tc-01/fcs-fase05-docs/blob/main/architecture/overview.md).
