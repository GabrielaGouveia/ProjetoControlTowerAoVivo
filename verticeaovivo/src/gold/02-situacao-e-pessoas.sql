-- gold.projeto_situacao_atual e gold.utilizacao_pessoa_semana.
--
-- projeto_situacao_atual: a fotografia de hoje (DATE'2026-10-16') dos 60 projetos da carteira,
-- combinando o cadastro do PMO com os KPIs calculados diretamente sobre as tarefas das ferramentas
-- (silver.tarefas) e os lançamentos de custo até hoje (silver.custos).
--
-- utilizacao_pessoa_semana: pessoa × projeto × semana com horas disponíveis, apontadas, ociosas,
-- taxa de utilização, custo ocioso e o SPI do projeto naquela semana.

CREATE OR REFRESH MATERIALIZED VIEW lakehouse_vertice.gold.projeto_situacao_atual
COMMENT 'Fotografia de 16/10/2026 dos 60 projetos da carteira: cadastro completo (cliente, segmento, tipo, ferramenta, gerente, contrato, orçamento, prazos) e KPIs de valor agregado sobre as tarefas (PV, EV, AC, SPI, CPI, EAC, estouro previsto, margem projetada, atraso projetado, término projetado, situação, farol do gerente, farol calculado e melancia).'
AS WITH kpis_tarefas AS (
  SELECT
    t.projeto_id,
    SUM(
      t.horas * greatest(
        0.0,
        least(
          1.0,
          try_divide(
            CAST(datediff(DATE'2026-10-16', t.inicio_baseline) AS DOUBLE),
            CAST(nullif(datediff(t.fim_baseline, t.inicio_baseline), 0) AS DOUBLE)
          )
        )
      )
    ) / SUM(t.horas) AS frac_pv,
    SUM(t.horas * (t.pct_concluido / 100.0)) / SUM(t.horas) AS frac_ev
  FROM tarefas t
  GROUP BY t.projeto_id
),
custo_acumulado AS (
  SELECT
    projeto_id,
    SUM(valor) AS ac
  FROM custos
  WHERE data <= DATE'2026-10-16'
  GROUP BY projeto_id
),
ultimo_status AS (
  SELECT
    projeto_id,
    farol,
    row_number() OVER (PARTITION BY projeto_id ORDER BY data_status DESC) AS rn
  FROM status_semanal
  WHERE data_status <= DATE'2026-10-16'
),
calculado AS (
  SELECT
    p.projeto_id,
    p.nome_projeto,
    concat(p.projeto_id, ' · ', p.nome_projeto) AS projeto,
    p.cliente,
    p.segmento,
    p.tipo_projeto,
    p.ferramenta,
    p.gerente_projeto,
    p.valor_contrato,
    p.orcamento,
    p.data_inicio,
    p.data_fim_baseline,
    datediff(p.data_fim_baseline, p.data_inicio) AS duracao_baseline_dias,
    p.status,
    CAST(round(p.orcamento * kt.frac_pv, 2) AS DECIMAL(18,2)) AS pv,
    CAST(round(p.orcamento * kt.frac_ev, 2) AS DECIMAL(18,2)) AS ev,
    coalesce(ca.ac, CAST(0 AS DECIMAL(18,2))) AS ac,
    round(try_divide(kt.frac_ev, kt.frac_pv), 4) AS spi,
    round(
      try_divide(
        CAST(p.orcamento AS DOUBLE) * kt.frac_ev,
        CAST(coalesce(ca.ac, 0) AS DOUBLE)
      ),
      4
    ) AS cpi,
    CAST(
      round(
        try_divide(
          CAST(p.orcamento AS DOUBLE),
          try_divide(
            CAST(p.orcamento AS DOUBLE) * kt.frac_ev,
            CAST(coalesce(ca.ac, 0) AS DOUBLE)
          )
        ),
        2
      ) AS DECIMAL(18,2)
    ) AS eac,
    us.farol AS farol_do_gerente
  FROM projetos p
  JOIN kpis_tarefas kt ON kt.projeto_id = p.projeto_id
  LEFT JOIN custo_acumulado ca ON ca.projeto_id = p.projeto_id
  LEFT JOIN ultimo_status us ON us.projeto_id = p.projeto_id AND us.rn = 1
)
SELECT
  projeto_id,
  nome_projeto,
  projeto,
  cliente,
  segmento,
  tipo_projeto,
  ferramenta,
  gerente_projeto,
  valor_contrato,
  orcamento,
  data_inicio,
  data_fim_baseline,
  duracao_baseline_dias,
  status,
  pv,
  ev,
  ac,
  spi,
  cpi,
  eac,
  greatest(eac - orcamento, CAST(0 AS DECIMAL(18,2))) AS estouro_previsto,
  round(try_divide(CAST(valor_contrato - eac AS DOUBLE), CAST(valor_contrato AS DOUBLE)), 4) AS margem_projetada,
  CAST(round(try_divide(CAST(duracao_baseline_dias AS DOUBLE), spi) - duracao_baseline_dias, 0) AS INT) AS atraso_projetado_dias,
  date_add(
    data_fim_baseline,
    CAST(round(try_divide(CAST(duracao_baseline_dias AS DOUBLE), spi) - duracao_baseline_dias, 0) AS INT)
  ) AS termino_projetado,
  CASE
    WHEN status <> 'em_andamento' THEN 'concluído'
    WHEN spi < 0.8 OR cpi < 0.8 THEN 'crítico'
    WHEN spi < 0.9 OR cpi < 0.9 THEN 'atenção'
    ELSE 'ok'
  END AS situacao,
  farol_do_gerente,
  CASE
    WHEN spi >= 0.95 THEN 'verde'
    WHEN spi >= 0.90 THEN 'amarelo'
    ELSE 'vermelho'
  END AS farol_calculado,
  (status = 'em_andamento' AND farol_do_gerente = 'verde' AND spi < 0.9) AS melancia
FROM calculado;

CREATE OR REFRESH MATERIALIZED VIEW lakehouse_vertice.gold.utilizacao_pessoa_semana
COMMENT 'Utilização semanal por colaborador e projeto: nome, papel, senioridade, horas disponíveis, apontadas e ociosas, taxa de utilização, custo ocioso (horas ociosas × custo/hora) e SPI do projeto naquela semana.'
AS SELECT
  a.colaborador_id,
  c.nome,
  c.papel,
  c.senioridade,
  c.custo_hora,
  a.projeto_id,
  p.nome_projeto,
  a.semana,
  a.horas_disponiveis,
  a.horas_apontadas,
  a.horas_disponiveis - a.horas_apontadas AS horas_ociosas,
  round(try_divide(a.horas_apontadas, a.horas_disponiveis), 4) AS utilizacao,
  CAST(
    round(greatest(a.horas_disponiveis - a.horas_apontadas, 0.0) * CAST(c.custo_hora AS DOUBLE), 2)
    AS DECIMAL(18,2)
  ) AS custo_ocioso,
  f.spi AS spi_do_projeto
FROM apontamentos a
JOIN colaboradores c ON c.colaborador_id = a.colaborador_id
JOIN projetos p ON p.projeto_id = a.projeto_id
LEFT JOIN lakehouse_vertice.gold.fato_projeto_semana f
  ON f.projeto_id = a.projeto_id AND f.semana = a.semana;

