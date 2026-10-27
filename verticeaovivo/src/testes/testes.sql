-- Testes de qualidade da Torre de Controle (silver e gold).
-- Executados após o pipeline vertice_medalhao como sql_task no SQL Warehouse.
-- Se qualquer um dos 10 testes falhar, raise_error() interrompe o job imediatamente.

WITH testes AS (
  -- 1. Os 60 projetos têm cronograma na silver.tarefas
  SELECT
    1 AS ordem,
    '1. 60 projetos têm cronograma na silver.tarefas' AS teste,
    (SELECT COUNT(DISTINCT projeto_id) FROM lakehouse_vertice.silver.tarefas) = 60 AS passou,
    concat('Esperado 60 projetos em silver.tarefas, encontrado: ',
           (SELECT COUNT(DISTINCT projeto_id) FROM lakehouse_vertice.silver.tarefas)) AS detalhe

  UNION ALL

  -- 2. Cada projeto veio de UMA ferramenta, a do cadastro do PMO
  SELECT
    2 AS ordem,
    '2. Cada projeto veio de UMA ferramenta, a do cadastro do PMO' AS teste,
    (
      SELECT COUNT(*)
      FROM (
        SELECT t.projeto_id
        FROM lakehouse_vertice.silver.tarefas t
        LEFT JOIN lakehouse_vertice.silver.projetos p ON p.projeto_id = t.projeto_id
        GROUP BY t.projeto_id, p.ferramenta
        HAVING COUNT(DISTINCT t.ferramenta) <> 1
            OR MAX(t.ferramenta) <> p.ferramenta
            OR p.ferramenta IS NULL
      )
    ) = 0 AS passou,
    'Há projeto com mais de uma ferramenta ou divergente do cadastro do PMO' AS detalhe

  UNION ALL

  -- 3. As horas do Excel na silver = a soma das linhas de TOTAL das planilhas
  SELECT
    3 AS ordem,
    '3. Horas do Excel na silver = soma das linhas de TOTAL das planilhas' AS teste,
    (
      SELECT round(SUM(horas), 2)
      FROM lakehouse_vertice.silver.tarefas
      WHERE ferramenta = 'excel'
    ) = (
      SELECT round(SUM(CAST(replace(horas_previstas, 'h', '') AS DOUBLE)), 2)
      FROM lakehouse_vertice.bronze.excel_tarefas
      WHERE tarefa = 'TOTAL'
    ) AS passou,
    concat(
      'Silver Excel horas = ',
      (SELECT round(SUM(horas), 2) FROM lakehouse_vertice.silver.tarefas WHERE ferramenta = 'excel'),
      ' vs Bronze TOTAL = ',
      (SELECT round(SUM(CAST(replace(horas_previstas, 'h', '') AS DOUBLE)), 2) FROM lakehouse_vertice.bronze.excel_tarefas WHERE tarefa = 'TOTAL')
    ) AS detalhe

  UNION ALL

  -- 4. Uma linha por pessoa na silver
  SELECT
    4 AS ordem,
    '4. Uma linha por pessoa na silver.colaboradores' AS teste,
    (
      SELECT COUNT(*) = COUNT(DISTINCT colaborador_id) AND COUNT(*) = 520
      FROM lakehouse_vertice.silver.colaboradores
    ) AS passou,
    concat(
      'Total linhas = ', (SELECT COUNT(*) FROM lakehouse_vertice.silver.colaboradores),
      ', distintos = ', (SELECT COUNT(DISTINCT colaborador_id) FROM lakehouse_vertice.silver.colaboradores)
    ) AS detalhe

  UNION ALL

  -- 5. A CodeForge virou um fornecedor só
  SELECT
    5 AS ordem,
    '5. A CodeForge virou um fornecedor só' AS teste,
    (
      SELECT COUNT(DISTINCT fornecedor)
      FROM lakehouse_vertice.silver.entregas_fornecedor
      WHERE replace(lower(fornecedor_como_veio), ' ', '') LIKE '%codeforge%'
    ) = 1 AS passou,
    concat(
      'Distintos para CodeForge: ',
      (SELECT COUNT(DISTINCT fornecedor) FROM lakehouse_vertice.silver.entregas_fornecedor WHERE replace(lower(fornecedor_como_veio), ' ', '') LIKE '%codeforge%')
    ) AS detalhe

  UNION ALL

  -- 6. A limpeza não mudou o custo total (bronze com replace = silver)
  SELECT
    6 AS ordem,
    '6. A limpeza não mudou o custo total (bronze com replace = silver)' AS teste,
    (
      SELECT SUM(CAST(replace(valor, ',', '.') AS DECIMAL(18,2)))
      FROM lakehouse_vertice.bronze.custos
    ) = (
      SELECT SUM(valor)
      FROM lakehouse_vertice.silver.custos
    ) AS passou,
    concat(
      'Bronze = ', (SELECT SUM(CAST(replace(valor, ',', '.') AS DECIMAL(18,2))) FROM lakehouse_vertice.bronze.custos),
      ' vs Silver = ', (SELECT SUM(valor) FROM lakehouse_vertice.silver.custos)
    ) AS detalhe

  UNION ALL

  -- 7. Os 60 projetos têm fotografia de hoje
  SELECT
    7 AS ordem,
    '7. Os 60 projetos têm fotografia de hoje em gold.projeto_situacao_atual' AS teste,
    (
      SELECT COUNT(*) = 60 AND COUNT(DISTINCT projeto_id) = 60
      FROM lakehouse_vertice.gold.projeto_situacao_atual
    ) AS passou,
    concat(
      'Linhas em gold.projeto_situacao_atual = ',
      (SELECT COUNT(*) FROM lakehouse_vertice.gold.projeto_situacao_atual)
    ) AS detalhe

  UNION ALL

  -- 8. Todo projeto em andamento tem SPI e CPI
  SELECT
    8 AS ordem,
    '8. Todo projeto em andamento tem SPI e CPI' AS teste,
    (
      SELECT COUNT(*)
      FROM lakehouse_vertice.gold.projeto_situacao_atual
      WHERE status = 'em_andamento' AND (spi IS NULL OR cpi IS NULL)
    ) = 0 AS passou,
    concat(
      'Projetos em andamento sem SPI/CPI: ',
      (SELECT COUNT(*) FROM lakehouse_vertice.gold.projeto_situacao_atual WHERE status = 'em_andamento' AND (spi IS NULL OR cpi IS NULL))
    ) AS detalhe

  UNION ALL

  -- 9. O EV de hoje do status semanal bate com o das ferramentas (diferença < 1%)
  SELECT
    9 AS ordem,
    '9. EV de hoje do status semanal bate com o das ferramentas (diferença < 1%)' AS teste,
    abs(
      (SELECT SUM(CAST(ev AS DOUBLE)) FROM lakehouse_vertice.gold.fato_projeto_semana WHERE semana = DATE'2026-10-16')
      - (SELECT SUM(CAST(ev AS DOUBLE)) FROM lakehouse_vertice.gold.projeto_situacao_atual)
    ) / (SELECT SUM(CAST(ev AS DOUBLE)) FROM lakehouse_vertice.gold.projeto_situacao_atual) < 0.01 AS passou,
    concat(
      'EV Fato = ',
      (SELECT round(SUM(ev), 2) FROM lakehouse_vertice.gold.fato_projeto_semana WHERE semana = DATE'2026-10-16'),
      ' vs EV Ferramentas = ',
      (SELECT round(SUM(ev), 2) FROM lakehouse_vertice.gold.projeto_situacao_atual)
    ) AS detalhe

  UNION ALL

  -- 10. AC de hoje no fato = soma dos lançamentos até hoje
  SELECT
    10 AS ordem,
    '10. AC de hoje no fato = soma dos lançamentos até hoje' AS teste,
    (
      SELECT SUM(ac)
      FROM lakehouse_vertice.gold.fato_projeto_semana
      WHERE semana = DATE'2026-10-16'
    ) = (
      SELECT SUM(valor)
      FROM lakehouse_vertice.silver.custos
      WHERE data <= DATE'2026-10-16'
    ) AS passou,
    concat(
      'Fato AC = ', (SELECT SUM(ac) FROM lakehouse_vertice.gold.fato_projeto_semana WHERE semana = DATE'2026-10-16'),
      ' vs Custos = ', (SELECT SUM(valor) FROM lakehouse_vertice.silver.custos WHERE data <= DATE'2026-10-16')
    ) AS detalhe
)
SELECT
  ordem,
  teste,
  CASE
    WHEN passou THEN 'ok'
    ELSE raise_error(concat('FALHA NO TESTE [', teste, ']: ', detalhe))
  END AS resultado
FROM testes
ORDER BY ordem;

