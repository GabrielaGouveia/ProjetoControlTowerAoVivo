SELECT
  COUNT(*) AS projetos_em_andamento,
  SUM(CASE WHEN situacao IN ('atenção', 'crítico') THEN 1 ELSE 0 END) AS projetos_em_risco,
  SUM(CASE WHEN situacao = 'crítico' THEN 1 ELSE 0 END) AS projetos_criticos,
  SUM(CASE WHEN melancia THEN 1 ELSE 0 END) AS projetos_melancia,
  ROUND(SUM(estouro_previsto), 2) AS estouro_previsto,
  ROUND(SUM(valor_contrato), 2) AS carteira
FROM lakehouse_vertice.gold.projeto_situacao_atual
WHERE status = 'em_andamento'

