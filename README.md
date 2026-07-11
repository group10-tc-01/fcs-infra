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

## Entrega da infraestrutura da VPS

O workflow `.github/workflows/vps-infrastructure-delivery.yml` publica uma release
versionada no K3s da VPS usando um runner hospedado pelo GitHub e SSH. A API do
Kubernetes continua restrita à própria VPS. O job de entrega usa o environment
`production`, portanto a aprovação configurada nesse environment é obrigatória.

### Configuração única do host

Como `root`, copie os três arquivos abaixo para a VPS e execute o bootstrap uma
única vez. A chave pública deve ser a chave dedicada ao workflow; não reutilize a
chave pessoal.

```bash
bash bootstrap-fcs-infra-deployer.sh \
  fcs-infra-apply \
  fcs-infra-deployer.sudoers \
  fcs-infra-deployer.pub
```

O bootstrap cria o usuário sem senha `fcs-infra-deployer`, instala o wrapper
root-owned em `/usr/local/sbin/fcs-infra-apply`, configura o sudoers sem senha
somente para esse caminho e cria `/opt/fcs-infra/releases`. O wrapper só aceita
um diretório de release cujo nome seja um SHA de 40 caracteres, rejeita links
simbólicos, torna a release imutável antes da execução e não aceita comandos
arbitrários.

### Configuração do GitHub

No environment `production` do repositório, configure:

- variável `VPS_HOST` com o hostname ou IP da VPS;
- variável `VPS_DEPLOY_USER` com `fcs-infra-deployer`;
- secret `FCS_INFRA_SSH_KEY` com a chave privada dedicada, sem passphrase;
- secret `VPS_KNOWN_HOSTS` com a saída de `ssh-keyscan -H <host>`.

O workflow gera os Secrets de SQL Server, Kafka UI, Keycloak e Identity dentro
da VPS. Nenhum valor de senha é versionado ou impresso nos logs. O realm e os
recursos estáticos do Identity ficam neste repositório; o `deployment.yaml` de
cada aplicação permanece no respectivo repositório e é aplicado pela pipeline
da aplicação.

### Purge manual

O purge não é executado pelo workflow. Para remover apenas a plataforma FCS,
preservando K3s base, `kube-system`, StorageClass, Docker, Coolify, DNS e
projetos pessoais, execute manualmente como `root`:

```bash
bash k8s/vps/down.sh --purge PURGE_FCS
```

O token explícito é obrigatório e os PVCs `local-path` serão apagados junto com
os workloads.
