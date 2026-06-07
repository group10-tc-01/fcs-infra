# Observabilidade local

Stack local de observabilidade da Conexao Solidaria com Datadog Agent e
OpenTelemetry Collector.

## Subir a stack

```bash
cd docker/observability
cp .env.example .env
# preencha DD_API_KEY e ajuste DD_SITE conforme sua conta
docker compose --env-file .env up -d
```

Componentes locais:

- Datadog Agent APM: `localhost:8126`
- Datadog Agent DogStatsD: `localhost:8125/udp`
- OTLP gRPC: `localhost:4317`
- OTLP HTTP: `localhost:4318`
- OpenTelemetry Collector metrics: <http://localhost:8888/metrics>

Dashboards e APM ficam no Datadog:

- US1: <https://app.datadoghq.com>
- US5: <https://us5.datadoghq.com>
- EU: <https://app.datadoghq.eu>

## Enviar telemetria dos servicos

Quando um servico estiver configurado para OTLP, aponte para o collector:

```text
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_SERVICE_NAME=fcs-identity
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=local,service.namespace=fcs
```

Para containers que nao estejam na rede `fcs-observability`, use o endpoint do
host:

```text
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
```

Tambem e possivel enviar traces diretamente para o Datadog Agent:

```text
DD_TRACE_AGENT_URL=http://datadog-agent:8126
```

Para containers fora da rede `fcs-observability`, use `http://localhost:8126`.

## Validacao rapida

```bash
docker compose --env-file .env config
docker compose --env-file .env up -d
docker compose --env-file .env ps
```

O collector expoe metricas internas em `http://localhost:8888/metrics`.

## Validar com telemetria sintetica

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

O servico `fcs-telemetrygen` deve aparecer no Datadog em APM, Metrics e Logs.

## Proxima etapa: fcs-identity

Para conectar o `fcs-identity` ao collector sem mudar a instrumentacao, anexe o
servico `api` a rede externa `fcs-observability` e configure:

```text
Observability__EnableOtlpExporter=true
Observability__OtlpEndpoint=http://otel-collector:4318
Observability__OtlpAuthHeader=
```

O endpoint `/metrics` do Identity pode continuar disponivel, mas o caminho
principal para a stack local passa a ser OTLP via collector e Datadog Agent.
