SELECT
  colaborador_id,
  nome,
  papel,
  senioridade,
  MAX(custo_hora) AS custo_hora,
  projeto_id,
  nome_projeto,
  ROUND(SUM(horas_apontadas) / SUM(horas_disponiveis), 4) AS utilizacao,
  ROUND(AVG(horas_ociosas), 2) AS horas_paradas_semana,
  ROUND(AVG(custo_ocioso), 2) AS custo_ocioso_semana
FROM lakehouse_vertice.gold.utilizacao_pessoa_semana
WHERE semana > DATE'2026-07-24'
GROUP BY
  colaborador_id,
  nome,
  papel,
  senioridade,
  projeto_id,
  nome_projeto
HAVING SUM(horas_apontadas) / SUM(horas_disponiveis) < 0.20
ORDER BY custo_ocioso_semana DESC

