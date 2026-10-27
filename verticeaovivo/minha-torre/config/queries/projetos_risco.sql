WITH causas_90d AS (
  SELECT
    projeto_id,
    causa_bloqueio,
    COUNT(*) AS semanas_bloqueio,
    COALESCE(SUM(dias_impacto), 0.0) AS dias_impacto_causa,
    ROW_NUMBER() OVER (
      PARTITION BY projeto_id
      ORDER BY COUNT(*) DESC, COALESCE(SUM(dias_impacto), 0.0) DESC, causa_bloqueio ASC
    ) AS rn
  FROM lakehouse_vertice.gold.status_estruturado
  WHERE data_status >= DATE'2026-07-18'
    AND causa_bloqueio NOT IN ('sem_bloqueio', 'nao_reportado')
  GROUP BY projeto_id, causa_bloqueio
),
impactos_90d AS (
  SELECT
    projeto_id,
    COALESCE(SUM(CASE WHEN causa_bloqueio = 'falta_sre' THEN dias_impacto ELSE 0.0 END), 0.0) AS dias_falta_sre,
    COALESCE(SUM(CASE WHEN causa_bloqueio = 'rotatividade' THEN dias_impacto ELSE 0.0 END), 0.0) AS dias_rotatividade
  FROM lakehouse_vertice.gold.status_estruturado
  WHERE data_status >= DATE'2026-07-18'
  GROUP BY projeto_id
)
SELECT
  p.projeto_id,
  p.nome_projeto,
  p.projeto,
  p.cliente,
  p.segmento,
  p.ferramenta,
  p.gerente_projeto,
  p.situacao,
  p.spi,
  p.cpi,
  p.orcamento,
  p.eac,
  p.estouro_previsto,
  p.atraso_projetado_dias,
  p.farol_do_gerente,
  p.farol_calculado,
  p.melancia,
  COALESCE(c.causa_bloqueio, 'sem_bloqueio') AS causa_principal,
  COALESCE(c.semanas_bloqueio, 0) AS semanas_causa_principal,
  COALESCE(i.dias_falta_sre, 0.0) AS dias_falta_sre,
  COALESCE(i.dias_rotatividade, 0.0) AS dias_rotatividade
FROM lakehouse_vertice.gold.projeto_situacao_atual p
LEFT JOIN causas_90d c
  ON c.projeto_id = p.projeto_id AND c.rn = 1
LEFT JOIN impactos_90d i
  ON i.projeto_id = p.projeto_id
WHERE p.status = 'em_andamento'
ORDER BY
  CASE p.situacao
    WHEN 'crítico' THEN 1
    WHEN 'atenção' THEN 2
    ELSE 3
  END ASC,
  p.spi ASC,
  p.estouro_previsto DESC

