-- gold.status_estruturado: transforma o texto livre do boletim semanal em colunas estruturadas.
--
-- Estratégia em 3 níveis (custo e velocidade):
--   1. 'regra'         : status_vazio ou texto explícito sem bloqueio ('bloqueios: nenhum', 'sem bloqueios', 'nada relevante')
--   2. 'ia'            : status com bloqueio dos últimos 90 dias (data_status >= DATE'2026-07-18', ~163 linhas)
--                        usando ai_classify e ai_extract na versão 2.0
--   3. 'palavra_chave' : histórico anterior a 18/07/2026 classificado por RLIKE e regex
--
-- A carga é incremental (CREATE TABLE IF NOT EXISTS + MERGE INTO ... WHEN NOT MATCHED)
-- para nunca reprocessar os textos já classificados pela IA em execuções futuras.

CREATE TABLE IF NOT EXISTS lakehouse_vertice.gold.status_estruturado (
  projeto_id STRING COMMENT 'Identificador do projeto (ex.: PRJ-011)',
  data_status DATE COMMENT 'Data da sexta-feira do boletim semanal',
  farol STRING COMMENT 'Farol reportado pelo gerente (verde, amarelo, vermelho)',
  causa_bloqueio STRING COMMENT 'Causa padronizada do bloqueio (change_freeze, falta_sre, dependencia_fornecedor, rotatividade, mudanca_escopo, bug_retrabalho, aprovacao_cliente, sem_bloqueio, nao_reportado)',
  bloqueio STRING COMMENT 'Resumo do bloqueio extraído pela IA nos últimos 90 dias',
  quem_destrava STRING COMMENT 'Responsável ou área que destrava o bloqueio segundo o texto',
  dias_impacto DOUBLE COMMENT 'Impacto estimado em dias (1 semana = 7 dias)',
  metodo STRING COMMENT 'Método de classificação aplicado: regra, ia ou palavra_chave',
  texto_status STRING COMMENT 'Texto livre original publicado pelo gerente no status semanal',
  _classificado_em TIMESTAMP COMMENT 'Timestamp de quando o registro foi classificado e inserido'
)
COMMENT 'Status semanal estruturado por projeto: causa do bloqueio, resumo do bloqueio, quem destrava e dias de impacto estimado, combinando regras determinísticas, regex no histórico e IA generativa (ai_classify + ai_extract v2.0) nos últimos 90 dias.';

MERGE INTO lakehouse_vertice.gold.status_estruturado AS destino
USING (
  WITH novos AS (
    SELECT
      s.projeto_id,
      s.data_status,
      s.farol,
      s.texto_status,
      s.status_vazio,
      CASE
        WHEN s.status_vazio
          OR lower(s.texto_status) LIKE '%bloqueios: nenhum%'
          OR lower(s.texto_status) LIKE '%sem bloqueios%'
          OR lower(s.texto_status) LIKE '%nada relevante%'
        THEN 'regra'
        WHEN s.data_status >= DATE'2026-07-18'
        THEN 'ia'
        ELSE 'palavra_chave'
      END AS metodo
    FROM lakehouse_vertice.silver.status_semanal s
    LEFT ANTI JOIN lakehouse_vertice.gold.status_estruturado e
      ON e.projeto_id = s.projeto_id AND e.data_status = s.data_status
  ),
  processados AS (
    SELECT
      projeto_id,
      data_status,
      farol,
      texto_status,
      status_vazio,
      metodo,
      CASE
        WHEN status_vazio THEN 'nao_reportado'
        WHEN metodo = 'regra' THEN 'sem_bloqueio'
        WHEN metodo = 'ia' THEN
          ai_classify(
            texto_status,
            '["change_freeze","falta_sre","dependencia_fornecedor","rotatividade","mudanca_escopo","bug_retrabalho","aprovacao_cliente","sem_bloqueio"]',
            map('version', '2.0')
          ):response[0]::STRING
        ELSE
          CASE
            WHEN lower(texto_status) RLIKE 'freeze|congelamento|janela de deploy' THEN 'change_freeze'
            WHEN lower(texto_status) RLIKE 'sre|infraestrutura|ambiente de homologação' THEN 'falta_sre'
            WHEN lower(texto_status) RLIKE 'forge|consultoria|fornecedor' THEN 'dependencia_fornecedor'
            WHEN lower(texto_status) RLIKE 'saída de|rotatividade|onboarding' THEN 'rotatividade'
            WHEN lower(texto_status) RLIKE 'escopo|change request|regra de negócio' THEN 'mudanca_escopo'
            WHEN lower(texto_status) RLIKE 'bugs|regressão|refazendo' THEN 'bug_retrabalho'
            WHEN lower(texto_status) RLIKE 'aprovação do cliente|homologação do cliente' THEN 'aprovacao_cliente'
            ELSE 'sem_bloqueio'
          END
      END AS causa_bloqueio,
      CASE
        WHEN metodo = 'ia' THEN
          ai_extract(
            texto_status,
            '{"bloqueio":{"type":"string","description":"Resumo do bloqueio"},"quem_destrava":{"type":"string","description":"Quem ou qual área destrava"},"dias_impacto":{"type":"number","description":"Impacto estimado em dias, onde 1 semana = 7"}}',
            map('version', '2.0')
          )
        ELSE NULL
      END AS extraido_ia
    FROM novos
  )
  SELECT
    projeto_id,
    data_status,
    farol,
    causa_bloqueio,
    extraido_ia:response:bloqueio::STRING AS bloqueio,
    extraido_ia:response:quem_destrava::STRING AS quem_destrava,
    CASE
      WHEN metodo = 'ia' THEN extraido_ia:response:dias_impacto::DOUBLE
      WHEN lower(texto_status) LIKE '%impacto estimado: 1 semana%' THEN 7.0
      ELSE CAST(nullif(regexp_extract(lower(texto_status), 'impacto estimado de ([0-9]+) dias', 1), '') AS DOUBLE)
    END AS dias_impacto,
    metodo,
    texto_status,
    current_timestamp() AS _classificado_em
  FROM processados
) AS origem
ON destino.projeto_id = origem.projeto_id
   AND destino.data_status = origem.data_status
WHEN NOT MATCHED THEN INSERT (
  projeto_id,
  data_status,
  farol,
  causa_bloqueio,
  bloqueio,
  quem_destrava,
  dias_impacto,
  metodo,
  texto_status,
  _classificado_em
) VALUES (
  origem.projeto_id,
  origem.data_status,
  origem.farol,
  origem.causa_bloqueio,
  origem.bloqueio,
  origem.quem_destrava,
  origem.dias_impacto,
  origem.metodo,
  origem.texto_status,
  origem._classificado_em
);

SELECT
  metodo,
  causa_bloqueio,
  COUNT(*) AS quantidade
FROM lakehouse_vertice.gold.status_estruturado
GROUP BY metodo, causa_bloqueio
ORDER BY metodo, quantidade DESC;

