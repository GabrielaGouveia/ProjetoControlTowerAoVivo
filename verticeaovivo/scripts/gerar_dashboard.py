"""Gera o arquivo resources/dashboard-portfolio.lvdash.json (AI/BI Dashboard, GRID_V1)."""

import json
from pathlib import Path


def counter_widget(name: str, dataset: str, field: str, title: str, fmt: dict | None = None) -> dict:
    value_enc: dict = {
        "fieldName": field,
        "displayName": title,
    }
    if fmt is not None:
        value_enc["format"] = fmt

    return {
        "name": name,
        "queries": [
            {
                "name": "main_query",
                "query": {
                    "datasetName": dataset,
                    "fields": [{"name": field, "expression": f"`{field}`"}],
                    "disaggregated": True,
                },
            }
        ],
        "spec": {
            "version": 2,
            "widgetType": "counter",
            "encodings": {"value": value_enc},
            "frame": {"showTitle": True, "title": title},
        },
    }


def table_widget(name: str, dataset: str, title: str, columns: list[tuple[str, str]]) -> dict:
    return {
        "name": name,
        "queries": [
            {
                "name": "main_query",
                "query": {
                    "datasetName": dataset,
                    "fields": [{"name": col, "expression": f"`{col}`"} for col, _ in columns],
                    "disaggregated": True,
                },
            }
        ],
        "spec": {
            "version": 2,
            "widgetType": "table",
            "encodings": {
                "columns": [{"fieldName": col, "displayName": label} for col, label in columns]
            },
            "frame": {"showTitle": True, "title": title},
        },
    }


def build_dashboard() -> dict:
    datasets = [
        {
            "name": "ds_kpis_carteira",
            "displayName": "KPIs da Carteira em Andamento",
            "queryLines": [
                "SELECT\n",
                "  ROUND(SUM(valor_contrato), 2) AS carteira_em_andamento,\n",
                "  ROUND(SUM(ev) / SUM(pv), 4) AS spi_carteira,\n",
                "  ROUND(SUM(ev) / SUM(ac), 4) AS cpi_carteira,\n",
                "  ROUND(SUM(estouro_previsto), 2) AS estouro_previsto_total,\n",
                "  SUM(CASE WHEN situacao IN ('atenção', 'crítico') THEN 1 ELSE 0 END) AS projetos_em_risco,\n",
                "  SUM(CASE WHEN situacao = 'crítico' THEN 1 ELSE 0 END) AS projetos_criticos,\n",
                "  SUM(CASE WHEN melancia THEN 1 ELSE 0 END) AS projetos_melancia\n",
                "FROM projeto_situacao_atual\n",
                "WHERE status = 'em_andamento'\n",
            ],
        },
        {
            "name": "ds_projetos_andamento",
            "displayName": "Projetos em Andamento (Fotografia Atual)",
            "queryLines": [
                "SELECT\n",
                "  projeto_id,\n",
                "  projeto,\n",
                "  cliente,\n",
                "  segmento,\n",
                "  ferramenta,\n",
                "  gerente_projeto,\n",
                "  valor_contrato,\n",
                "  orcamento,\n",
                "  pv,\n",
                "  ev,\n",
                "  ac,\n",
                "  spi,\n",
                "  cpi,\n",
                "  eac,\n",
                "  estouro_previsto,\n",
                "  margem_projetada,\n",
                "  atraso_projetado_dias,\n",
                "  termino_projetado,\n",
                "  situacao,\n",
                "  farol_do_gerente,\n",
                "  farol_calculado,\n",
                "  melancia\n",
                "FROM projeto_situacao_atual\n",
                "WHERE status = 'em_andamento'\n",
                "ORDER BY estouro_previsto DESC, spi ASC\n",
            ],
        },
        {
            "name": "ds_evolucao_semanal",
            "displayName": "SPI e CPI Semanais da Carteira",
            "queryLines": [
                "SELECT\n",
                "  semana,\n",
                "  ROUND(SUM(ev) / SUM(pv), 4) AS spi_semanal,\n",
                "  ROUND(SUM(ev) / SUM(ac), 4) AS cpi_semanal\n",
                "FROM fato_projeto_semana\n",
                "WHERE semana >= DATE'2025-03-07'\n",
                "GROUP BY semana\n",
                "ORDER BY semana\n",
            ],
        },
        {
            "name": "ds_top_pessoas_ociosas",
            "displayName": "Top 15 Pessoas por Custo da Hora Parada (12 Semanas)",
            "queryLines": [
                "SELECT\n",
                "  concat(colaborador_id, ' · ', nome, ' (', upper(papel), ')') AS pessoa,\n",
                "  colaborador_id,\n",
                "  nome,\n",
                "  papel,\n",
                "  senioridade,\n",
                "  projeto_id,\n",
                "  nome_projeto,\n",
                "  ROUND(SUM(horas_disponiveis), 1) AS horas_disponiveis,\n",
                "  ROUND(SUM(horas_apontadas), 1) AS horas_apontadas,\n",
                "  ROUND(SUM(horas_ociosas), 1) AS horas_ociosas,\n",
                "  ROUND(SUM(horas_apontadas) / SUM(horas_disponiveis), 4) AS utilizacao,\n",
                "  ROUND(SUM(custo_ocioso), 2) AS custo_hora_parada\n",
                "FROM utilizacao_pessoa_semana\n",
                "WHERE semana > DATE'2026-07-24'\n",
                "GROUP BY colaborador_id, nome, papel, senioridade, projeto_id, nome_projeto\n",
                "ORDER BY custo_hora_parada DESC\n",
                "LIMIT 15\n",
            ],
        },
        {
            "name": "ds_utilizacao_pessoas",
            "displayName": "Utilização por Pessoa e Projeto (12 Semanas)",
            "queryLines": [
                "SELECT\n",
                "  colaborador_id,\n",
                "  nome,\n",
                "  papel,\n",
                "  senioridade,\n",
                "  projeto_id,\n",
                "  nome_projeto,\n",
                "  ROUND(SUM(horas_disponiveis), 1) AS horas_disponiveis,\n",
                "  ROUND(SUM(horas_apontadas), 1) AS horas_apontadas,\n",
                "  ROUND(SUM(horas_ociosas), 1) AS horas_ociosas,\n",
                "  ROUND(SUM(horas_apontadas) / SUM(horas_disponiveis), 4) AS utilizacao,\n",
                "  ROUND(SUM(custo_ocioso), 2) AS custo_ocioso,\n",
                "  ROUND(AVG(spi_do_projeto), 4) AS spi_medio_projeto\n",
                "FROM utilizacao_pessoa_semana\n",
                "WHERE semana > DATE'2026-07-24'\n",
                "GROUP BY colaborador_id, nome, papel, senioridade, projeto_id, nome_projeto\n",
                "ORDER BY utilizacao ASC, custo_ocioso DESC\n",
            ],
        },
        {
            "name": "ds_causas_bloqueio",
            "displayName": "Causas de Bloqueio por Projeto (Últimos 90 Dias)",
            "queryLines": [
                "SELECT\n",
                "  projeto_id,\n",
                "  causa_bloqueio,\n",
                "  COUNT(*) AS semanas_com_bloqueio,\n",
                "  COALESCE(SUM(dias_impacto), 0) AS dias_impacto_declarado\n",
                "FROM status_estruturado\n",
                "WHERE data_status >= DATE'2026-07-18'\n",
                "  AND causa_bloqueio NOT IN ('sem_bloqueio', 'nao_reportado')\n",
                "GROUP BY projeto_id, causa_bloqueio\n",
                "ORDER BY semanas_com_bloqueio DESC\n",
            ],
        },
        {
            "name": "ds_fornecedores_resumo",
            "displayName": "Desempenho por Fornecedor",
            "queryLines": [
                "SELECT\n",
                "  fornecedor,\n",
                "  COUNT(DISTINCT fornecedor_como_veio) AS grafias_no_cadastro,\n",
                "  COUNT(*) AS entregas,\n",
                "  ROUND(AVG(try_divide(CAST(prazo_real_dias AS DOUBLE), CAST(prazo_prometido_dias AS DOUBLE))), 2) AS prazo_real_div_prometido,\n",
                "  ROUND(AVG(CASE WHEN NOT em_aberto AND dias_de_atraso_na_entrega <= 0 THEN 1.0 WHEN NOT em_aberto THEN 0.0 END), 4) AS pct_no_prazo,\n",
                "  SUM(CASE WHEN em_atraso THEN 1 ELSE 0 END) AS em_atraso_hoje\n",
                "FROM lakehouse_vertice.silver.entregas_fornecedor\n",
                "GROUP BY fornecedor\n",
                "ORDER BY em_atraso_hoje DESC, prazo_real_div_prometido DESC\n",
            ],
        },
        {
            "name": "ds_entregas_atrasadas",
            "displayName": "Entregas de Consultoria em Atraso Hoje",
            "queryLines": [
                "SELECT\n",
                "  entrega_id,\n",
                "  projeto_id,\n",
                "  fornecedor,\n",
                "  fornecedor_como_veio,\n",
                "  item,\n",
                "  valor,\n",
                "  data_pedido,\n",
                "  data_prometida,\n",
                "  datediff(DATE'2026-10-16', data_prometida) AS dias_em_atraso_hoje\n",
                "FROM lakehouse_vertice.silver.entregas_fornecedor\n",
                "WHERE em_atraso = true\n",
                "ORDER BY dias_em_atraso_hoje DESC\n",
            ],
        },
    ]

    fmt_brl = {
        "type": "number-currency",
        "currencyCode": "BRL",
        "abbreviation": "compact",
        "decimalPlaces": {"type": "max", "places": 2},
    }
    fmt_dec = {
        "type": "number-plain",
        "decimalPlaces": {"type": "exact", "places": 2},
    }

    situacao_mappings = [
        {"value": "crítico", "color": "#FF5F46"},
        {"value": "atenção", "color": "#F6C344"},
        {"value": "ok", "color": "#22C2F4"},
    ]

    page_portfolio = {
        "name": "portfolio",
        "displayName": "Portfólio",
        "pageType": "PAGE_TYPE_CANVAS",
        "layoutVersion": "GRID_V1",
        "layout": [
            {
                "widget": {
                    "name": "header-portfolio",
                    "multilineTextboxSpec": {
                        "lines": [
                            "## Portfólio · Quais projetos estão atrasados, de quais clientes, e quanto esse atraso vai me custar?\n",
                            "\n",
                            "Fotografia em **16/10/2026** dos 41 projetos em andamento na carteira da Vértice Tecnologia (SPI e CPI ponderados por razão de somas `SUM(ev)/SUM(pv)` e `SUM(ev)/SUM(ac)`).",
                        ]
                    },
                },
                "position": {"x": 0, "y": 0, "width": 12, "height": 2},
            },
            {
                "widget": counter_widget(
                    "kpi-carteira", "ds_kpis_carteira", "carteira_em_andamento", "Carteira (Em Andamento)", fmt_brl
                ),
                "position": {"x": 0, "y": 2, "width": 2, "height": 3},
            },
            {
                "widget": counter_widget("kpi-spi", "ds_kpis_carteira", "spi_carteira", "SPI da Carteira", fmt_dec),
                "position": {"x": 2, "y": 2, "width": 2, "height": 3},
            },
            {
                "widget": counter_widget("kpi-cpi", "ds_kpis_carteira", "cpi_carteira", "CPI da Carteira", fmt_dec),
                "position": {"x": 4, "y": 2, "width": 2, "height": 3},
            },
            {
                "widget": counter_widget(
                    "kpi-estouro", "ds_kpis_carteira", "estouro_previsto_total", "Estouro Previsto", fmt_brl
                ),
                "position": {"x": 6, "y": 2, "width": 2, "height": 3},
            },
            {
                "widget": counter_widget(
                    "kpi-em-risco", "ds_kpis_carteira", "projetos_em_risco", "Projetos em Risco"
                ),
                "position": {"x": 8, "y": 2, "width": 2, "height": 3},
            },
            {
                "widget": counter_widget(
                    "kpi-criticos", "ds_kpis_carteira", "projetos_criticos", "Projetos Críticos"
                ),
                "position": {"x": 10, "y": 2, "width": 1, "height": 3},
            },
            {
                "widget": counter_widget(
                    "kpi-melancias", "ds_kpis_carteira", "projetos_melancia", "Melancias"
                ),
                "position": {"x": 11, "y": 2, "width": 1, "height": 3},
            },
            {
                "widget": {
                    "name": "bar-estouro-projeto",
                    "queries": [
                        {
                            "name": "main_query",
                            "query": {
                                "datasetName": "ds_projetos_andamento",
                                "fields": [
                                    {"name": "projeto_id", "expression": "`projeto_id`"},
                                    {"name": "estouro_previsto", "expression": "`estouro_previsto`"},
                                    {"name": "situacao", "expression": "`situacao`"},
                                ],
                                "disaggregated": True,
                            },
                        }
                    ],
                    "spec": {
                        "version": 3,
                        "widgetType": "bar",
                        "encodings": {
                            "x": {
                                "fieldName": "projeto_id",
                                "displayName": "Projeto",
                                "scale": {"type": "categorical"},
                            },
                            "y": {
                                "fieldName": "estouro_previsto",
                                "displayName": "Estouro Previsto (R$)",
                                "scale": {"type": "quantitative"},
                            },
                            "color": {
                                "fieldName": "situacao",
                                "displayName": "Situação",
                                "scale": {
                                    "type": "categorical",
                                    "mappings": situacao_mappings,
                                },
                            },
                        },
                        "frame": {"showTitle": True, "title": "Estouro Previsto por Projeto e Situação"},
                    },
                },
                "position": {"x": 0, "y": 5, "width": 6, "height": 6},
            },
            {
                "widget": {
                    "name": "scatter-spi-cpi",
                    "queries": [
                        {
                            "name": "main_query",
                            "query": {
                                "datasetName": "ds_projetos_andamento",
                                "fields": [
                                    {"name": "spi", "expression": "`spi`"},
                                    {"name": "cpi", "expression": "`cpi`"},
                                    {"name": "situacao", "expression": "`situacao`"},
                                    {"name": "projeto", "expression": "`projeto`"},
                                ],
                                "disaggregated": True,
                            },
                        }
                    ],
                    "spec": {
                        "version": 3,
                        "widgetType": "scatter",
                        "encodings": {
                            "x": {
                                "fieldName": "spi",
                                "displayName": "SPI (Prazo)",
                                "scale": {"type": "quantitative"},
                            },
                            "y": {
                                "fieldName": "cpi",
                                "displayName": "CPI (Custo)",
                                "scale": {"type": "quantitative"},
                            },
                            "color": {
                                "fieldName": "situacao",
                                "displayName": "Situação",
                                "scale": {
                                    "type": "categorical",
                                    "mappings": situacao_mappings,
                                },
                            },
                            "label": {"fieldName": "projeto", "show": False},
                        },
                        "frame": {"showTitle": True, "title": "Dispersão SPI × CPI por Projeto"},
                    },
                },
                "position": {"x": 6, "y": 5, "width": 6, "height": 6},
            },
            {
                "widget": {
                    "name": "line-spi-cpi-semanal",
                    "queries": [
                        {
                            "name": "main_query",
                            "query": {
                                "datasetName": "ds_evolucao_semanal",
                                "fields": [
                                    {"name": "semana", "expression": "`semana`"},
                                    {"name": "spi_semanal", "expression": "`spi_semanal`"},
                                    {"name": "cpi_semanal", "expression": "`cpi_semanal`"},
                                ],
                                "disaggregated": True,
                            },
                        }
                    ],
                    "spec": {
                        "version": 3,
                        "widgetType": "line",
                        "encodings": {
                            "x": {
                                "fieldName": "semana",
                                "displayName": "Semana",
                                "scale": {"type": "temporal"},
                            },
                            "y": {
                                "scale": {"type": "quantitative"},
                                "fields": [
                                    {"fieldName": "spi_semanal", "displayName": "SPI Semanal"},
                                    {"fieldName": "cpi_semanal", "displayName": "CPI Semanal"},
                                ],
                            },
                        },
                        "frame": {
                            "showTitle": True,
                            "title": "Evolução Semanal de SPI e CPI da Carteira (a partir de 07/03/2025)",
                        },
                    },
                },
                "position": {"x": 0, "y": 11, "width": 12, "height": 5},
            },
            {
                "widget": table_widget(
                    "tabela-projetos-andamento",
                    "ds_projetos_andamento",
                    "Projetos em Andamento — Farol do Gerente vs. Farol Calculado e Melancias",
                    [
                        ("projeto", "Projeto"),
                        ("cliente", "Cliente"),
                        ("segmento", "Segmento"),
                        ("ferramenta", "Ferramenta"),
                        ("gerente_projeto", "Gerente"),
                        ("situacao", "Situação"),
                        ("farol_do_gerente", "Farol do Gerente"),
                        ("farol_calculado", "Farol Calculado"),
                        ("melancia", "Melancia"),
                        ("spi", "SPI"),
                        ("cpi", "CPI"),
                        ("orcamento", "Orçamento (R$)"),
                        ("eac", "EAC (R$)"),
                        ("estouro_previsto", "Estouro Previsto (R$)"),
                        ("atraso_projetado_dias", "Atraso Projetado (dias)"),
                    ],
                ),
                "position": {"x": 0, "y": 16, "width": 12, "height": 7},
            },
        ],
    }

    page_pessoas = {
        "name": "pessoas",
        "displayName": "Pessoas",
        "pageType": "PAGE_TYPE_CANVAS",
        "layoutVersion": "GRID_V1",
        "layout": [
            {
                "widget": {
                    "name": "header-pessoas",
                    "multilineTextboxSpec": {
                        "lines": [
                            "## Pessoas · Tenho gente parada enquanto outro projeto pede gente?\n",
                            "\n",
                            "Análise das últimas 12 semanas (`semana > 2026-07-24`) no timesheet combinada com as causas de bloqueio reportadas nos últimos 90 dias.",
                        ]
                    },
                },
                "position": {"x": 0, "y": 0, "width": 12, "height": 2},
            },
            {
                "widget": {
                    "name": "bar-top15-custo-ocioso",
                    "queries": [
                        {
                            "name": "main_query",
                            "query": {
                                "datasetName": "ds_top_pessoas_ociosas",
                                "fields": [
                                    {"name": "pessoa", "expression": "`pessoa`"},
                                    {"name": "custo_hora_parada", "expression": "`custo_hora_parada`"},
                                    {"name": "papel", "expression": "`papel`"},
                                ],
                                "disaggregated": True,
                            },
                        }
                    ],
                    "spec": {
                        "version": 3,
                        "widgetType": "bar",
                        "encodings": {
                            "x": {
                                "fieldName": "custo_hora_parada",
                                "displayName": "Custo da Hora Parada (R$)",
                                "scale": {"type": "quantitative"},
                            },
                            "y": {
                                "fieldName": "pessoa",
                                "displayName": "Colaborador",
                                "scale": {"type": "categorical"},
                            },
                            "color": {
                                "fieldName": "papel",
                                "displayName": "Papel",
                                "scale": {"type": "categorical"},
                            },
                        },
                        "frame": {
                            "showTitle": True,
                            "title": "Top 15 Pessoas por Custo da Hora Parada (Últimas 12 Semanas)",
                        },
                    },
                },
                "position": {"x": 0, "y": 2, "width": 6, "height": 7},
            },
            {
                "widget": {
                    "name": "bar-causas-bloqueio",
                    "queries": [
                        {
                            "name": "main_query",
                            "query": {
                                "datasetName": "ds_causas_bloqueio",
                                "fields": [
                                    {"name": "projeto_id", "expression": "`projeto_id`"},
                                    {"name": "semanas_com_bloqueio", "expression": "`semanas_com_bloqueio`"},
                                    {"name": "causa_bloqueio", "expression": "`causa_bloqueio`"},
                                ],
                                "disaggregated": True,
                            },
                        }
                    ],
                    "spec": {
                        "version": 3,
                        "widgetType": "bar",
                        "encodings": {
                            "x": {
                                "fieldName": "projeto_id",
                                "displayName": "Projeto",
                                "scale": {"type": "categorical"},
                            },
                            "y": {
                                "fieldName": "semanas_com_bloqueio",
                                "displayName": "Semanas com Bloqueio",
                                "scale": {"type": "quantitative"},
                            },
                            "color": {
                                "fieldName": "causa_bloqueio",
                                "displayName": "Causa do Bloqueio",
                                "scale": {"type": "categorical"},
                            },
                        },
                        "frame": {
                            "showTitle": True,
                            "title": "Causas de Bloqueio por Projeto (Últimos 90 Dias)",
                        },
                    },
                },
                "position": {"x": 6, "y": 2, "width": 6, "height": 7},
            },
            {
                "widget": table_widget(
                    "tabela-utilizacao-pessoas",
                    "ds_utilizacao_pessoas",
                    "Utilização por Pessoa e Projeto (Da Mais Parada à Mais Ocupada — Últimas 12 Semanas)",
                    [
                        ("colaborador_id", "ID"),
                        ("nome", "Nome"),
                        ("papel", "Papel"),
                        ("senioridade", "Senioridade"),
                        ("projeto_id", "Projeto ID"),
                        ("nome_projeto", "Projeto"),
                        ("utilizacao", "Taxa de Utilização"),
                        ("horas_disponiveis", "Horas Disponíveis"),
                        ("horas_apontadas", "Horas Apontadas"),
                        ("horas_ociosas", "Horas Ociosas"),
                        ("custo_ocioso", "Custo Ocioso (R$)"),
                        ("spi_medio_projeto", "SPI Médio do Projeto"),
                    ],
                ),
                "position": {"x": 0, "y": 9, "width": 12, "height": 7},
            },
        ],
    }

    page_fornecedores = {
        "name": "fornecedores",
        "displayName": "Fornecedores",
        "pageType": "PAGE_TYPE_CANVAS",
        "layoutVersion": "GRID_V1",
        "layout": [
            {
                "widget": {
                    "name": "header-fornecedores",
                    "multilineTextboxSpec": {
                        "lines": [
                            "## Fornecedores · O que vai dar errado no próximo mês com as entregas de consultoria?\n",
                            "\n",
                            "Auditoria das entregas contratadas em `lakehouse_vertice.silver.entregas_fornecedor` após a unificação das 4 grafias da **CodeForge Consultoria Ltda**.",
                        ]
                    },
                },
                "position": {"x": 0, "y": 0, "width": 12, "height": 2},
            },
            {
                "widget": table_widget(
                    "tabela-fornecedores-resumo",
                    "ds_fornecedores_resumo",
                    "Desempenho por Fornecedor (Grafias, Entregas, Prazo Real ÷ Prometido, % no Prazo e Em Atraso Hoje)",
                    [
                        ("fornecedor", "Fornecedor"),
                        ("grafias_no_cadastro", "Grafias no Cadastro"),
                        ("entregas", "Total de Entregas"),
                        ("prazo_real_div_prometido", "Prazo Real ÷ Prometido"),
                        ("pct_no_prazo", "% no Prazo"),
                        ("em_atraso_hoje", "Em Atraso Hoje"),
                    ],
                ),
                "position": {"x": 0, "y": 2, "width": 12, "height": 5},
            },
            {
                "widget": table_widget(
                    "tabela-entregas-atrasadas",
                    "ds_entregas_atrasadas",
                    "Entregas em Atraso Hoje (Referência: 16/10/2026)",
                    [
                        ("entrega_id", "Entrega ID"),
                        ("projeto_id", "Projeto ID"),
                        ("fornecedor", "Fornecedor Normalizado"),
                        ("fornecedor_como_veio", "Fornecedor Como Veio"),
                        ("item", "Item Contratado"),
                        ("valor", "Valor (R$)"),
                        ("data_pedido", "Data do Pedido"),
                        ("data_prometida", "Data Prometida"),
                        ("dias_em_atraso_hoje", "Dias em Atraso Hoje"),
                    ],
                ),
                "position": {"x": 0, "y": 7, "width": 12, "height": 6},
            },
        ],
    }

    ui_settings = {
        "theme": {
            "canvasBackgroundColor": {"light": "#F7F9FC", "dark": "#14141A"},
            "widgetBackgroundColor": {"light": "#FFFFFF", "dark": "#1C1C24"},
            "widgetBorderColor": {"light": "#E2E8F0", "dark": "#282834"},
            "fontColor": {"light": "#14141A", "dark": "#F0F4F8"},
            "selectionColor": {"light": "#0059DB", "dark": "#22C2F4"},
            "visualizationColors": [
                "#0059DB",
                "#22C2F4",
                "#F6C344",
                "#FF5F46",
                "#8B5CF6",
                "#10B981",
                "#F97316",
            ],
            "widgetHeaderAlignment": "LEFT",
        }
    }

    return {
        "datasets": datasets,
        "pages": [page_portfolio, page_pessoas, page_fornecedores],
        "uiSettings": ui_settings,
    }


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    out_path = root / "resources" / "dashboard-portfolio.lvdash.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    dashboard = build_dashboard()
    out_path.write_text(json.dumps(dashboard, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Dashboard gerado com sucesso em: {out_path}")
    print(f"  Datasets : {len(dashboard['datasets'])}")
    print(f"  Páginas  : {len(dashboard['pages'])} ({', '.join(p['displayName'] for p in dashboard['pages'])})")


if __name__ == "__main__":
    main()

