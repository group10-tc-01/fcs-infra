# fcs-infra

Repositório de **Infraestrutura Compartilhada** da plataforma **Conexão Solidária**. Centraliza o ambiente integrado da demo, manifests Kubernetes compartilhados, configurações de plataforma e Terraform para provisionamento.

> Repositório de apoio que compõe o MVP da Conexão Solidária junto a `fcs-identity`, `fcs-campaigns`, `fcs-donations`, `fcs-donation-worker`, `fcs-audit-logs`, `fcs-bff`, `fcs-web` e `fcs-pipelines`.

---

## Provisionamento da VPS

O workflow `.github/workflows/vps-terraform.yml` é a fonte de provisionamento
da VPS. O GitHub Actions executa o Terraform e o HCP Terraform guarda somente
o state criptografado e o lock. Configure o workspace HCP em **Local
execution**.

O primeiro deploy reconstrói o host, instala K3s, Traefik, cert-manager,
Infisical Secrets Operator, Datadog, SQL Server, MongoDB, Kafka, Keycloak e os
componentes compartilhados. Os deployments das aplicações permanecem em seus
respectivos repositórios.

### GitHub Actions

Adicione como **repository secrets**:

| Nome | Finalidade |
|---|---|
| `HCP_TERRAFORM_TOKEN` | Acesso ao state e lock do HCP Terraform. |
| `HOSTINGER_API_TOKEN` | Token da API Hostinger. |
| `VPS_BOOTSTRAP_SSH_KEY` | Chave privada Ed25519 dedicada ao bootstrap. |

Crie o environment `production`, com aprovação obrigatória, e adicione:

| Nome | Finalidade |
|---|---|
| `INFISICAL_UNIVERSAL_AUTH_CLIENT_ID` | Universal Auth da Machine Identity. |
| `INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET` | Credencial da mesma Machine Identity. |
| `VPS_KNOWN_HOSTS` | Chaves públicas SSH da VPS; atualize-o depois de cada reimage. |

Configure as **Variables**:

| Nome | Valor |
|---|---|
| `VPS_HOST` | IP público ou hostname da VPS. |
| `VPS_BOOTSTRAP_USER` | `root` |
| `VPS_DEPLOY_USER` | `fcs-vps-deployer` |
| `VPS_SSH_ALLOWED_CIDRS` | `["0.0.0.0/0"]` para runners GitHub hospedados. |
| `ACME_EMAIL` | E-mail de contato do Let's Encrypt. |
| `HCP_TERRAFORM_ORGANIZATION` | Organização HCP Terraform. |
| `HCP_TERRAFORM_WORKSPACE` | Workspace do state remoto. |
| `INFISICAL_PROJECT_SLUG` | `fcs-platform` |
| `INFISICAL_OPERATOR_CHART_VERSION` | Versão pinada do chart do operador. |

### Infisical

A Machine Identity precisa de leitura no projeto `fcs-platform`, ambiente
`prod`, nos paths abaixo. O operador sincroniza os valores com o Kubernetes;
não coloque valores reais em Terraform, YAML ou state.

| Path | Secrets efetivamente utilizados |
|---|---|
| `/platform` | `sql-sa-password`, `keycloak-admin-password`, `manager-password` |
| `/observability` | `DATADOG_API_KEY` |

Os modelos seguros de importação estão em `infisical/imports/`. Copie o
arquivo `.env.example`, preencha localmente e importe no Infisical no path
correspondente. Arquivos `.env` preenchidos são ignorados pelo Git.

### Primeiro deploy

1. Garanta que o DNS de `fcs-identity.flaviojcf.com.br` aponta para a VPS.
2. Autorize a chave pública correspondente a `VPS_BOOTSTRAP_SSH_KEY` para o
   usuário `root`.
3. Dispare manualmente **FCS VPS Terraform** na branch `main` e aprove o
   environment `production`.

O workflow executa em ordem: host/K3s, fundação do cluster, injeção da
identidade Infisical e plataforma compartilhada. A API Kubernetes não é
exposta publicamente.
