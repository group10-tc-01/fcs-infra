# FCS Fase 05 - Kubernetes local

Este diretorio sobe um ambiente Kubernetes local da Conexao Solidaria usando Kind.

## Componentes

Infra em `fcs-infra`:

- SQL Server com `IdentityDb`, `CampaignsDb`, `DonationsDb` e `KeycloakDb`
- Keycloak com realm `conexao-solidaria`
- Kafka em modo KRaft
- Kafka UI
- MongoDB para `AuditLogsDb`
- OpenTelemetry Collector exportando para Datadog

Aplicacoes:

- `fcs-identity`
- `fcs-campaign`
- `fcs-donations`
- `fcs-donation-worker`
- `fcs-audit-logs`
- `fcs-web`

O ambiente local sobe apenas os componentes necessarios para a arquitetura atual da Fase 05.

## Requisitos

- Docker
- Kind
- kubectl
- Repos `fcs-infra` e `fcs-identity` clonados lado a lado
- `DD_API_KEY` valida para enviar telemetria ao Datadog
- Acesso ao GHCR se os packages estiverem privados

## Variaveis opcionais

```bash
export GHCR_USERNAME="seu-usuario"
export GHCR_TOKEN="token-com-read-packages"
export DD_API_KEY="datadog-api-key"
export DD_SITE="us5.datadoghq.com"
```

`DD_API_KEY` e obrigatoria porque o OpenTelemetry Collector local exporta diretamente para o Datadog.

Valores locais podem ser sobrescritos:

```bash
export FCS_LOCAL_SQL_PASSWORD="Your_password123"
export FCS_LOCAL_KEYCLOAK_ADMIN_PASSWORD="admin"
export FCS_LOCAL_MANAGER_PASSWORD="Gestor123!"
export FCS_LOCAL_JWT_SECRET_KEY="local-development-jwt-secret-key-for-fcs-fase05-1234567890"
```

## Subir

```bash
cd fcs-infra/k8s
bash up.sh
```

O script:

1. Cria o cluster Kind `fcs-local` se ele nao existir.
2. Aplica namespaces.
3. Cria secrets locais.
4. Cria `imagePullSecret` nos namespaces se `GHCR_USERNAME` e `GHCR_TOKEN` forem informados.
5. Cria ConfigMap do realm do Keycloak a partir de `../../fcs-identity/keycloak/conexao-solidaria-realm.json`.
6. Sobe infraestrutura.
7. Cria topicos Kafka.
8. Sobe aplicacoes usando imagens `ghcr.io/group10-tc-01/*:main`.

## Endpoints acessiveis localmente

Depois do `bash up.sh`, os servicos abaixo ficam acessiveis pelo host por meio dos `NodePort` mapeados no Kind.

| Componente | Tipo | URL base | Endpoints uteis |
| --- | --- | --- | --- |
| `fcs-web` | Frontend | `http://localhost:4200` | `/` |
| `fcs-identity` | API | `http://localhost:64534` | `/swagger`, `/health`, `/metrics`, `/api/v1/auth/register/donor`, `/api/v1/auth/login`, `/api/v1/auth/refresh`, `/api/v1/me` |
| `fcs-campaign` | API | `http://localhost:55904` | `/swagger`, `/health`, `/metrics`, `/api/v1/campaigns`, `/api/v1/transparency/campaigns` |
| `fcs-donations` | API | `http://localhost:5003` | `/swagger`, `/health`, `/metrics`, `/api/v1/donations` |
| Keycloak | Ferramenta | `http://localhost:8081` | `/admin`, `/realms/conexao-solidaria` |
| Kafka UI | Ferramenta | `http://localhost:8082` | `/` |

Os workers `fcs-donation-worker` e `fcs-audit-logs` tambem expõem `/health` e `/metrics`, mas ficam acessiveis apenas dentro do cluster por `ClusterIP`.

| Componente | URL interna |
| --- | --- |
| `fcs-donation-worker` | `http://fcs-donation-worker-service.fcs-donation-worker.svc.cluster.local` |
| `fcs-audit-logs` | `http://fcs-audit-logs-service.fcs-audit-logs.svc.cluster.local` |

Essas portas preservam o comportamento atual do `fcs-web`, que ainda referencia `64534` para identity e `55904` para campaign.

## Conferencia rapida

```bash
kubectl get pods --all-namespaces
curl http://localhost:64534/health
curl http://localhost:55904/health
curl http://localhost:5003/health
```

Ver logs:

```bash
kubectl logs -n fcs-identity deployment/fcs-identity -f
kubectl logs -n fcs-campaign deployment/fcs-campaign -f
kubectl logs -n fcs-donations deployment/fcs-donations -f
kubectl logs -n fcs-donation-worker deployment/fcs-donation-worker -f
kubectl logs -n fcs-audit-logs deployment/fcs-audit-logs -f
```

## Derrubar

Remover namespaces e manter o cluster:

```bash
bash down.sh
```

Remover o cluster Kind inteiro:

```bash
bash down.sh --cluster
```
