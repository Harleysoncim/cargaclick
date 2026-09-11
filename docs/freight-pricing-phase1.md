# Fase 1 — Motor tarifario configurável

A flag `NATIONAL_FREIGHT_PRICING_ENABLED=false` mantém a fórmula operacional existente como fallback. O fallback é exibido como `Estimativa provisória — tabela de mercado ainda não ativada` e não é uma média nacional.

## Estrutura aprovada

A configuração versionada está em `config/freight_rates.yml`. Ela reserva campos para:

- versão, fonte, data de referência e tamanho da amostra;
- tipo de veículo e número de eixos;
- faixas de distância;
- tipo de carga e região;
- peso real, peso cubado e peso tarifável;
- volume, pedágio, retorno e urgência;
- piso operacional, mediana, P25 e P75.

Os valores comerciais estão vazios de propósito. Nenhum coeficiente foi inventado.

## Fórmula futura

Quando houver parâmetros aprovados e amostra suficiente:

```text
peso_cubado = volume * fator_cubagem_do_veiculo
peso_tarifavel = max(peso_real, peso_cubado)
valor_sugerido = max(
  piso_operacional,
  custo_deslocamento + adicional_peso + adicional_volume
  + pedagio + retorno + regiao + tipo_carga + urgencia
)
```

A mediana, P25 e P75 serão calculados somente sobre cotações/fretes compatíveis com os critérios aprovados. A fonte, data, versão e tamanho da amostra deverão acompanhar cada resultado.

## Pendências comerciais

Antes de habilitar a flag, aprovar valores e critérios para veículos/eixos, cubagem, distância, peso, volume, regiões, tipos de carga, pedágio, retorno, urgência e piso operacional. Também é necessário definir a amostra mínima e a política de uso de P25, mediana e P75.

Nenhuma migration é necessária na Fase 1. A configuração pode evoluir para banco somente após aprovação separada, backup e plano de rollback.
