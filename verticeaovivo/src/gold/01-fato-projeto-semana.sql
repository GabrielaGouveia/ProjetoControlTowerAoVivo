-- gold.fato_projeto_semana: evolução semanal de cada projeto da carteira.
-- Uma linha por projeto e semana (sempre sexta-feira), da semana do início até DATE'2026-10-16'.
--
-- Regras de negócio:
--   · PV (Planned Value): orçamento × Σ(horas × fração do baseline decorrida até a semana) ÷ Σ(horas)
--   · EV (Earned Value): orçamento × pct_concluido do status_semanal daquela sexta ÷ 100
--     (projetos concluídos não publicam mais status: mantemos o último % publicado com last_value)
--   · AC (Actual Cost): custo real acumulado até aquela semana (silver.custos)
--   · SPI = EV / PV, CPI = EV / AC (4 casas decimais), EAC = orçamento / CPI

CREATE OR REFRESH MATERIALIZED VIEW lakehouse_vertice.gold.fato_projeto_semana (
  CONSTRAINT pv_nao_negativo EXPECT (pv >= 0) ON VIOLATION FAIL UPDATE,
  CONSTRAINT ev_ate_orcamento EXPECT (ev <= orcamento) ON VIOLATION FAIL UPDATE
)
COMMENT 'Evolução semanal de cada projeto (uma linha por projeto e sexta-feira até 16/10/2026): PV, EV, AC, SPI, CPI, EAC, farol do gerente e horas do timesheet (disponíveis, apontadas e ociosas).'
AS WITH calendario AS (
  SELECT
    p.projeto_id,
    p.orcamento,
    explode(
      sequence(
        date_add(date_trunc('WEEK', p.data_inicio), 4),
        DATE'2026-10-16',
        INTERVAL 1 WEEK
      )
    ) AS semana
  FROM projetos p
),
pv_semanal AS (
  SELECT
    c.projeto_id,
    c.semana,
    CAST(
      c.orcamento * try_divide(
        SUM(
          t.horas * greatest(
            0.0,
            least(
              1.0,
              try_divide(
                CAST(datediff(c.semana, t.inicio_baseline) AS DOUBLE),
                CAST(nullif(datediff(t.fim_baseline, t.inicio_baseline), 0) AS DOUBLE)
              )
            )
          )
        ),
        SUM(t.horas)
      ) AS DECIMAL(18,2)
    ) AS pv
  FROM calendario c
  JOIN tarefas t ON t.projeto_id = c.projeto_id
  GROUP BY c.projeto_id, c.semana, c.orcamento
),
custos_semana AS (
  SELECT
    projeto_id,
    semana,
    SUM(valor) AS valor_semana
  FROM custos
  GROUP BY projeto_id, semana
),
horas_semana AS (
  SELECT
    projeto_id,
    semana,
    SUM(horas_disponiveis) AS horas_disponiveis,
    SUM(horas_apontadas) AS horas_apontadas,
    SUM(horas_disponiveis) - SUM(horas_apontadas) AS horas_ociosas
  FROM apontamentos
  GROUP BY projeto_id, semana
),
base_janelas AS (
  SELECT
    c.projeto_id,
    c.semana,
    c.orcamento,
    pv.pv,
    last_value(s.pct_concluido, true) OVER (
      PARTITION BY c.projeto_id
      ORDER BY c.semana
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS pct_concluido,
    last_value(s.farol, true) OVER (
      PARTITION BY c.projeto_id
      ORDER BY c.semana
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS farol_do_gerente,
    coalesce(
      SUM(cs.valor_semana) OVER (
        PARTITION BY c.projeto_id
        ORDER BY c.semana
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      ),
      CAST(0 AS DECIMAL(18,2))
    ) AS ac,
    coalesce(hs.horas_disponiveis, 0.0) AS horas_disponiveis,
    coalesce(hs.horas_apontadas, 0.0) AS horas_apontadas,
    coalesce(hs.horas_ociosas, 0.0) AS horas_ociosas
  FROM calendario c
  LEFT JOIN pv_semanal pv ON pv.projeto_id = c.projeto_id AND pv.semana = c.semana
  LEFT JOIN status_semanal s ON s.projeto_id = c.projeto_id AND s.data_status = c.semana
  LEFT JOIN custos_semana cs ON cs.projeto_id = c.projeto_id AND cs.semana = c.semana
  LEFT JOIN horas_semana hs ON hs.projeto_id = c.projeto_id AND hs.semana = c.semana
),
metricas AS (
  SELECT
    projeto_id,
    semana,
    orcamento,
    pv,
    CAST(orcamento * coalesce(pct_concluido, 0) / 100.0 AS DECIMAL(18,2)) AS ev,
    ac,
    farol_do_gerente,
    horas_disponiveis,
    horas_apontadas,
    horas_ociosas
  FROM base_janelas
)
SELECT
  projeto_id,
  semana,
  orcamento,
  pv,
  ev,
  ac,
  round(try_divide(CAST(ev AS DOUBLE), CAST(pv AS DOUBLE)), 4) AS spi,
  round(try_divide(CAST(ev AS DOUBLE), CAST(ac AS DOUBLE)), 4) AS cpi,
  CAST(
    round(
      try_divide(
        CAST(orcamento AS DOUBLE),
        try_divide(CAST(ev AS DOUBLE), CAST(ac AS DOUBLE))
      ),
      2
    ) AS DECIMAL(18,2)
  ) AS eac,
  farol_do_gerente,
  horas_disponiveis,
  horas_apontadas,
  horas_ociosas
FROM metricas;

