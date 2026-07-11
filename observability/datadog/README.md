# Dashboards Datadog

`fcs-identity-dashboard.json` é um dashboard importável no Datadog. Ele usa as
métricas nativas do Agent Kubernetes para mostrar CPU, memória e réplicas reais
do `fcs-identity` no cluster `fcs-vps-k3s`.

Depois que o workflow de infraestrutura e a pipeline do Identity forem
executados:

1. Abra **Dashboards > New Dashboard > Import dashboard** no Datadog.
2. Cole o conteúdo de `fcs-identity-dashboard.json` ou faça o upload do arquivo.
3. Salve o dashboard e confirme que os três widgets possuem dados.

O dashboard não contém API keys nem é enviado automaticamente pela pipeline.
Isso evita armazenar uma Application Key do Datadog na VPS; a importação é uma
ação única na conta Datadog.
