# Observabilidade local

Stack local de observabilidade da Conexao Solidaria com Grafana, Prometheus,
Tempo, Loki e OpenTelemetry Collector.

## Subir a stack

```bash
cd docker/observability
docker compose --env-file .env.example up -d
```

URLs locais:

- Grafana: <http://localhost:3000>
- Prometheus: <http://localhost:9090>
- Tempo: <http://localhost:3200>
- Loki: <http://localhost:3100>
- OTLP gRPC: `localhost:4317`
- OTLP HTTP: `localhost:4318`

Credenciais padrao do Grafana:

- Usuario: `admin`
- Senha: `admin`

Dashboard provisionado:

- FCS Operational Overview: <http://localhost:3000/d/fcs-operational-overview/fcs-operational-overview>

## Enviar telemetria dos servicos

Esta primeira entrega prepara a infra para receber telemetria. A padronizacao
dos microservicos sera feita depois. Quando um servico estiver configurado para
OTLP, aponte para o collector:

```text
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

Para containers que nao estejam na rede `fcs-observability`, use o endpoint do
host:

```text
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
```

## Datadog opcional

Por padrao, nada e enviado para Datadog. Para espelhar traces, metricas e logs
para Datadog, copie `.env.example` para `.env`, preencha `DD_API_KEY`, mantenha
`DD_SITE` conforme sua conta e suba com o override:

```bash
cd docker/observability
docker compose --env-file .env \
  -f docker-compose.yml \
  -f docker-compose.datadog.yml \
  up -d
```

Com o override do Datadog ativo, logs continuam no Loki local e tambem sao
enviados para o Datadog. Use isso com cuidado em ambientes com volume alto.

## Validacao rapida

```bash
docker compose --env-file .env.example config
docker compose --env-file .env.example up -d
docker compose --env-file .env.example ps
```

O collector expoe metricas internas em `http://localhost:8888/metrics` e as
metricas recebidas via OTLP em `http://localhost:9464/metrics`.

## Validar o dashboard com telemetria sintetica

Com a stack no ar, envie traces, metricas e logs para o collector:

```bash
docker run --rm --network fcs-observability \
  ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest \
  traces --otlp-endpoint=fcs-otel-collector:4317 --otlp-insecure \
  --service fcs-telemetrygen --traces 3

docker run --rm --network fcs-observability \
  ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest \
  metrics --otlp-endpoint=fcs-otel-collector:4317 --otlp-insecure \
  --service fcs-telemetrygen --metrics 3 \
  --otlp-metric-name fcs_telemetrygen_metric

docker run --rm --network fcs-observability \
  ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest \
  logs --otlp-endpoint=fcs-otel-collector:4317 --otlp-insecure \
  --service fcs-telemetrygen --logs 3 \
  --body "fcs observability synthetic log"
```

O servico `fcs-telemetrygen` deve aparecer na variavel `Service` do dashboard.

## Proxima etapa: fcs-identity

Para conectar o `fcs-identity` ao collector sem mudar a instrumentacao, anexe o
servico `api` a rede externa `fcs-observability` e configure:

```text
Observability__EnableOtlpExporter=true
Observability__OtlpEndpoint=http://otel-collector:4318
Observability__OtlpAuthHeader=
```

O endpoint `/metrics` do Identity pode continuar disponivel, mas o caminho
principal para a stack local passa a ser OTLP via collector.
