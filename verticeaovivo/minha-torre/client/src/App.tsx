import { createBrowserRouter, RouterProvider, NavLink, Outlet } from 'react-router';
import { useEffect, useMemo, useState } from 'react';
import {
  Alert,
  AlertDescription,
  AlertTitle,
  Badge,
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyTitle,
  Input,
  Label,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  Skeleton,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  useAnalyticsQuery,
  useIsMobile,
} from '@databricks/appkit-ui/react';
import { Menu } from 'lucide-react';

interface ScoreLinha {
  projeto_id: string;
  data_referencia?: string;
  prob_estouro_30d: number | string;
  ranking?: number | string;
  faixa_risco: string;
  principais_fatores?: string;
}

interface ScoreEstouroResponse {
  disponivel: boolean;
  linhas: ScoreLinha[];
}

function isRecord(val: unknown): val is Record<string, unknown> {
  return typeof val === 'object' && val !== null;
}

function parseScoreResponse(raw: unknown): ScoreEstouroResponse {
  if (!isRecord(raw) || raw.disponivel !== true || !Array.isArray(raw.linhas)) {
    return { disponivel: false, linhas: [] };
  }
  const linhas: ScoreLinha[] = [];
  for (const item of raw.linhas) {
    if (isRecord(item) && typeof item.projeto_id === 'string') {
      linhas.push({
        projeto_id: item.projeto_id,
        data_referencia: typeof item.data_referencia === 'string' ? item.data_referencia : undefined,
        prob_estouro_30d:
          typeof item.prob_estouro_30d === 'number' || typeof item.prob_estouro_30d === 'string'
            ? item.prob_estouro_30d
            : 0,
        ranking:
          typeof item.ranking === 'number' || typeof item.ranking === 'string'
            ? item.ranking
            : undefined,
        faixa_risco: typeof item.faixa_risco === 'string' ? item.faixa_risco : 'baixo',
        principais_fatores:
          typeof item.principais_fatores === 'string' ? item.principais_fatores : undefined,
      });
    }
  }
  return { disponivel: true, linhas };
}

function formatBRL(value: number | string | null | undefined): string {
  const num = Number(value ?? 0);
  if (!Number.isFinite(num)) return 'R$ 0,00';
  return num.toLocaleString('pt-BR', {
    style: 'currency',
    currency: 'BRL',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

function formatBRLCompact(value: number | string | null | undefined): string {
  const num = Number(value ?? 0);
  if (!Number.isFinite(num)) return 'R$ 0';
  const abs = Math.abs(num);
  if (abs >= 1_000_000) {
    return `R$ ${(num / 1_000_000).toLocaleString('pt-BR', {
      minimumFractionDigits: 1,
      maximumFractionDigits: 2,
    })} mi`;
  }
  if (abs >= 1_000) {
    return `R$ ${(num / 1_000).toLocaleString('pt-BR', {
      minimumFractionDigits: 1,
      maximumFractionDigits: 1,
    })} mil`;
  }
  return formatBRL(num);
}

function formatIndice(value: number | string | null | undefined): string {
  const num = Number(value ?? 0);
  if (!Number.isFinite(num)) return '0,00';
  return num.toLocaleString('pt-BR', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

function formatCausa(causa: string | null | undefined): string {
  const mapa: Record<string, string> = {
    falta_sre: 'Falta de SRE',
    mudanca_escopo: 'Mudança de escopo',
    bug_retrabalho: 'Bug / retrabalho',
    aprovacao_cliente: 'Aprovação do cliente',
    dependencia_fornecedor: 'Dependência de fornecedor',
    rotatividade: 'Rotatividade da equipe',
    change_freeze: 'Change freeze',
    sem_bloqueio: 'Sem bloqueio',
    nao_reportado: 'Não reportado',
  };
  if (!causa) return 'Sem bloqueio';
  return mapa[causa] ?? causa;
}

function SituacaoBadge({ situacao }: { situacao: string }) {
  if (situacao === 'crítico') {
    return (
      <Badge variant="destructive" className="font-semibold">
        crítico
      </Badge>
    );
  }
  if (situacao === 'atenção') {
    return (
      <Badge variant="secondary" className="bg-warning/25 text-warning-foreground border border-warning/50 font-semibold">
        atenção
      </Badge>
    );
  }
  return (
    <Badge variant="outline" className="bg-success/15 text-success border-success/40 font-medium">
      {situacao}
    </Badge>
  );
}

const navLinkClass = ({ isActive }: { isActive: boolean }) =>
  `px-3 py-1.5 rounded-md text-sm font-medium transition-colors ${
    isActive
      ? 'bg-primary text-primary-foreground'
      : 'text-muted-foreground hover:bg-muted hover:text-foreground'
  }`;

const mobileNavLinkClass = ({ isActive }: { isActive: boolean }) =>
  `block px-3 py-2 rounded-md text-sm font-medium transition-colors ${
    isActive
      ? 'bg-primary text-primary-foreground'
      : 'text-muted-foreground hover:bg-muted hover:text-foreground'
  }`;

type NavLinkClassFn = (props: { isActive: boolean }) => string;

function NavLinks({
  className,
  linkClass,
  onClick,
}: {
  className?: string;
  linkClass: NavLinkClassFn;
  onClick?: () => void;
}) {
  return (
    <nav className={className} aria-label="Menu principal">
      <NavLink to="/" end className={linkClass} onClick={onClick}>
        Projetos em risco
      </NavLink>
      <NavLink to="/simulador" className={linkClass} onClick={onClick}>
        Simulador
      </NavLink>
    </nav>
  );
}

function Layout() {
  const isMobile = useIsMobile();
  const [mobileNavOpen, setMobileNavOpen] = useState(false);

  return (
    <div className="min-h-screen bg-background flex flex-col">
      <header className="border-b px-4 md:px-6 py-3 flex items-center gap-4">
        <div className="flex items-center gap-2">
          <h1 className="text-lg font-semibold text-foreground">Projeto Farol</h1>
          <Badge variant="outline" className="hidden sm:inline-flex text-xs">
            Vértice Tecnologia · 16/10/2026
          </Badge>
        </div>
        <NavLinks className="hidden md:flex gap-1 ml-4" linkClass={navLinkClass} />
        <div className="ml-auto md:hidden">
          <Sheet open={mobileNavOpen && isMobile} onOpenChange={setMobileNavOpen}>
            <Button variant="ghost" size="icon" onClick={() => setMobileNavOpen(true)}>
              <Menu className="h-5 w-5" />
              <span className="sr-only">Abrir menu</span>
            </Button>
            <SheetContent side="left">
              <SheetHeader>
                <SheetTitle>Projeto Farol</SheetTitle>
              </SheetHeader>
              <NavLinks
                className="flex flex-col gap-1 mt-4"
                linkClass={mobileNavLinkClass}
                onClick={() => setMobileNavOpen(false)}
              />
            </SheetContent>
          </Sheet>
        </div>
      </header>

      <main className="flex-1 p-4 md:p-6">
        <Outlet />
      </main>
    </div>
  );
}

function useScoreEstouro() {
  const [score, setScore] = useState<ScoreEstouroResponse>({ disponivel: false, linhas: [] });
  const [loadingScore, setLoadingScore] = useState<boolean>(true);

  useEffect(() => {
    let active = true;
    fetch('/api/score-estouro')
      .then((res) => res.json())
      .then((json: unknown) => {
        if (active) {
          setScore(parseScoreResponse(json));
          setLoadingScore(false);
        }
      })
      .catch(() => {
        if (active) {
          setScore({ disponivel: false, linhas: [] });
          setLoadingScore(false);
        }
      });
    return () => {
      active = false;
    };
  }, []);

  return { score, loadingScore };
}

function ProjetosEmRiscoPage() {
  const emptyParams = useMemo(() => ({}), []);
  const {
    data: kpisData,
    loading: loadingKpis,
    error: errorKpis,
  } = useAnalyticsQuery('kpis', emptyParams);
  const {
    data: projetosData,
    loading: loadingProjetos,
    error: errorProjetos,
  } = useAnalyticsQuery('projetos_risco', emptyParams);
  const { score, loadingScore } = useScoreEstouro();

  const kpiRow = kpisData && kpisData.length > 0 ? kpisData[0] : null;

  const scorePorProjeto = useMemo(() => {
    const map = new Map<string, ScoreLinha>();
    for (const linha of score.linhas) {
      map.set(linha.projeto_id, linha);
    }
    return map;
  }, [score.linhas]);

  const qtdAltoRisco30d = useMemo(() => {
    if (!score.disponivel) return null;
    return score.linhas.filter((l) => l.faixa_risco === 'alto').length;
  }, [score]);

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      <div>
        <h2 className="text-xl font-bold text-foreground">
          Projetos em risco — Quais projetos estão atrasados e quanto esse atraso vai custar?
        </h2>
        <p className="text-sm text-muted-foreground">
          Fotografia de 16/10/2026 sobre a camada Gold (`lakehouse_vertice.gold.projeto_situacao_atual` e `status_estruturado`).
        </p>
      </div>

      {(errorKpis || errorProjetos) && (
        <Alert variant="destructive">
          <AlertTitle>Erro ao consultar o SQL Warehouse</AlertTitle>
          <AlertDescription>{String(errorKpis || errorProjetos)}</AlertDescription>
        </Alert>
      )}

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <Card>
          <CardHeader className="pb-2">
            <CardDescription>Projetos em risco (atenção + crítico)</CardDescription>
            <CardTitle className="text-2xl">
              {loadingKpis || !kpiRow ? (
                <Skeleton className="h-8 w-28" />
              ) : (
                `${Number(kpiRow.projetos_em_risco)} de ${Number(kpiRow.projetos_em_andamento)}`
              )}
            </CardTitle>
          </CardHeader>
          <CardContent className="text-xs text-muted-foreground">
            {loadingKpis || !kpiRow ? (
              <Skeleton className="h-4 w-40" />
            ) : (
              `${Number(kpiRow.projetos_criticos)} críticos · ${Number(kpiRow.projetos_melancia)} melancias 🍉`
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardDescription>Estouro previsto (EAC − orçamento)</CardDescription>
            <CardTitle className="text-2xl text-destructive">
              {loadingKpis || !kpiRow ? (
                <Skeleton className="h-8 w-36" />
              ) : (
                formatBRLCompact(kpiRow.estouro_previsto)
              )}
            </CardTitle>
          </CardHeader>
          <CardContent className="text-xs text-muted-foreground">
            {loadingKpis || !kpiRow ? (
              <Skeleton className="h-4 w-36" />
            ) : (
              formatBRL(kpiRow.estouro_previsto)
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardDescription>Carteira em andamento</CardDescription>
            <CardTitle className="text-2xl">
              {loadingKpis || !kpiRow ? (
                <Skeleton className="h-8 w-36" />
              ) : (
                formatBRLCompact(kpiRow.carteira)
              )}
            </CardTitle>
          </CardHeader>
          <CardContent className="text-xs text-muted-foreground">
            {loadingKpis || !kpiRow ? (
              <Skeleton className="h-4 w-36" />
            ) : (
              `${formatBRL(kpiRow.carteira)} em contratos ativos`
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardDescription>Alto risco em 30 dias</CardDescription>
            <CardTitle className="text-2xl">
              {loadingScore ? (
                <Skeleton className="h-8 w-20" />
              ) : qtdAltoRisco30d !== null ? (
                `${qtdAltoRisco30d} projetos`
              ) : (
                '—'
              )}
            </CardTitle>
          </CardHeader>
          <CardContent className="text-xs text-muted-foreground">
            {score.disponivel
              ? 'Faixa de risco alta no modelo preditivo (P ≥ 50%)'
              : 'Modelo preditivo opcional (gold.score_estouro_30d)'}
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Carteira em andamento — do pior para o melhor</CardTitle>
          <CardDescription>
            SPI ou CPI abaixo de 0,80 = crítico; abaixo de 0,90 = atenção. Farol verde do gerente com SPI &lt; 0,90 = melancia 🍉.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {loadingProjetos ? (
            <div className="space-y-2">
              <Skeleton className="h-10 w-full" />
              <Skeleton className="h-10 w-full" />
              <Skeleton className="h-10 w-full" />
            </div>
          ) : !projetosData || projetosData.length === 0 ? (
            <Empty>
              <EmptyHeader>
                <EmptyTitle>Nenhum projeto encontrado</EmptyTitle>
                <EmptyDescription>
                  Verifique se a tabela gold.projeto_situacao_atual está populada.
                </EmptyDescription>
              </EmptyHeader>
            </Empty>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Projeto</TableHead>
                    <TableHead>Cliente</TableHead>
                    <TableHead>Situação</TableHead>
                    <TableHead className="text-right">SPI</TableHead>
                    <TableHead className="text-right">CPI</TableHead>
                    <TableHead className="text-right">Estouro previsto</TableHead>
                    <TableHead className="text-right">Atraso (dias)</TableHead>
                    <TableHead>Farol (Gerente × Calc.)</TableHead>
                    <TableHead>Causa 90d</TableHead>
                    <TableHead className="text-right">P(estouro)</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {projetosData.map((row) => {
                    const isMelancia = Boolean(row.melancia);
                    const scoreItem = scorePorProjeto.get(row.projeto_id);
                    const prob = scoreItem ? Number(scoreItem.prob_estouro_30d) : null;

                    return (
                      <TableRow key={row.projeto_id}>
                        <TableCell className="font-medium">
                          <div>{row.projeto_id}</div>
                          <div className="text-xs text-muted-foreground">{row.nome_projeto}</div>
                        </TableCell>
                        <TableCell>
                          <div>{row.cliente}</div>
                          <div className="text-xs text-muted-foreground">{row.segmento}</div>
                        </TableCell>
                        <TableCell>
                          <SituacaoBadge situacao={row.situacao} />
                        </TableCell>
                        <TableCell className="text-right font-mono">
                          {formatIndice(row.spi)}
                        </TableCell>
                        <TableCell className="text-right font-mono">
                          {formatIndice(row.cpi)}
                        </TableCell>
                        <TableCell className="text-right font-mono">
                          {formatBRL(row.estouro_previsto)}
                        </TableCell>
                        <TableCell className="text-right font-mono">
                          {Number(row.atraso_projetado_dias)}d
                        </TableCell>
                        <TableCell>
                          <span className="text-xs">
                            {row.farol_do_gerente}
                            {isMelancia ? ' 🍉' : ''} {' × '}
                            <span className="font-semibold">{row.farol_calculado}</span>
                          </span>
                        </TableCell>
                        <TableCell className="text-xs">
                          <div>{formatCausa(row.causa_principal)}</div>
                          {Number(row.dias_falta_sre) > 0 && (
                            <div className="text-muted-foreground">
                              Falta SRE: {Number(row.dias_falta_sre)}d
                            </div>
                          )}
                        </TableCell>
                        <TableCell className="text-right font-mono">
                          {prob !== null && Number.isFinite(prob)
                            ? `${(prob * 100).toFixed(0)}%`
                            : '—'}
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

function SimuladorPage() {
  const emptyParams = useMemo(() => ({}), []);
  const {
    data: pessoasData,
    loading: loadingPessoas,
    error: errorPessoas,
  } = useAnalyticsQuery('pessoas_ociosas', emptyParams);
  const {
    data: projetosData,
    loading: loadingProjetos,
    error: errorProjetos,
  } = useAnalyticsQuery('projetos_risco', emptyParams);

  const [pessoaKey, setPessoaKey] = useState<string>('');
  const [projetoId, setProjetoId] = useState<string>('');
  const [horasOnboarding, setHorasOnboarding] = useState<number>(40);

  const pessoaSelecionada = useMemo(() => {
    if (!pessoasData || pessoasData.length === 0) return null;
    if (!pessoaKey) return pessoasData[0];
    return (
      pessoasData.find((p) => `${p.colaborador_id}:${p.projeto_id}` === pessoaKey) ??
      pessoasData[0]
    );
  }, [pessoasData, pessoaKey]);

  const projetosElegiveis = useMemo(() => {
    if (!projetosData) return [];
    const filtrados = projetosData.filter(
      (p) => p.situacao === 'atenção' || p.situacao === 'crítico'
    );
    const isSre = pessoaSelecionada?.papel?.toLowerCase() === 'sre';
    return [...filtrados].sort((a, b) => {
      if (isSre) {
        const diffSre = Number(b.dias_falta_sre) - Number(a.dias_falta_sre);
        if (diffSre !== 0) return diffSre;
      } else {
        const diffRot = Number(b.dias_rotatividade) - Number(a.dias_rotatividade);
        if (diffRot !== 0) return diffRot;
      }
      return Number(a.spi) - Number(b.spi);
    });
  }, [projetosData, pessoaSelecionada]);

  const projetoSelecionado = useMemo(() => {
    if (projetosElegiveis.length === 0) return null;
    if (!projetoId) return projetosElegiveis[0];
    return projetosElegiveis.find((p) => p.projeto_id === projetoId) ?? projetosElegiveis[0];
  }, [projetosElegiveis, projetoId]);

  const calculo = useMemo(() => {
    if (!pessoaSelecionada || !projetoSelecionado) return null;
    const horasParadasSemana = Number(pessoaSelecionada.horas_paradas_semana);
    const custoOciosoSemana = Number(pessoaSelecionada.custo_ocioso_semana);
    const custoHora = Number(pessoaSelecionada.custo_hora);

    const horasNoMes = horasParadasSemana * 4;
    const ociosidadeEvitada = custoOciosoSemana * 4;

    const isSre = pessoaSelecionada.papel.toLowerCase() === 'sre';
    const diasImpacto90d = isSre
      ? Number(projetoSelecionado.dias_falta_sre)
      : Number(projetoSelecionado.dias_rotatividade);
    const diasRecuperados = (diasImpacto90d / 90) * 30;

    const onboardingHoras = Number.isFinite(horasOnboarding) && horasOnboarding >= 0 ? horasOnboarding : 40;
    const mobilizacao = onboardingHoras * custoHora;
    const saldo = ociosidadeEvitada - mobilizacao;

    return {
      horasParadasSemana,
      custoOciosoSemana,
      custoHora,
      horasNoMes,
      ociosidadeEvitada,
      diasImpacto90d,
      diasRecuperados,
      onboardingHoras,
      mobilizacao,
      saldo,
      causaAlvo: isSre ? 'falta_sre' : 'rotatividade',
    };
  }, [pessoaSelecionada, projetoSelecionado, horasOnboarding]);

  return (
    <div className="max-w-6xl mx-auto space-y-6">
      <div>
        <h2 className="text-xl font-bold text-foreground">
          Simulador de Realocação — Tenho gente parada enquanto outro projeto pede gente?
        </h2>
        <p className="text-sm text-muted-foreground">
          Simule a transferência de especialistas com utilização &lt; 20% nas últimas 12 semanas para projetos em atenção ou críticos.
        </p>
      </div>

      {(errorPessoas || errorProjetos) && (
        <Alert variant="destructive">
          <AlertTitle>Erro ao carregar dados do simulador</AlertTitle>
          <AlertDescription>{String(errorPessoas || errorProjetos)}</AlertDescription>
        </Alert>
      )}

      {loadingPessoas || loadingProjetos ? (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <Skeleton className="h-32 w-full" />
          <Skeleton className="h-32 w-full" />
          <Skeleton className="h-32 w-full" />
        </div>
      ) : !pessoaSelecionada || !projetoSelecionado || !calculo ? (
        <Empty>
          <EmptyHeader>
            <EmptyTitle>Sem dados para simulação</EmptyTitle>
            <EmptyDescription>
              Não foram encontradas pessoas ociosas ou projetos em risco para simular.
            </EmptyDescription>
          </EmptyHeader>
        </Empty>
      ) : (
        <>
          <Card>
            <CardHeader>
              <CardTitle>Parâmetros da realocação</CardTitle>
              <CardDescription>
                Escolha o profissional ocioso, o projeto de destino (em atenção ou crítico) e o tempo estimado de onboarding.
              </CardDescription>
            </CardHeader>
            <CardContent className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div className="space-y-2">
                <Label htmlFor="select-pessoa">Pessoa ociosa (uso &lt; 20% em 12 semanas)</Label>
                <Select
                  value={`${pessoaSelecionada.colaborador_id}:${pessoaSelecionada.projeto_id}`}
                  onValueChange={(val) => setPessoaKey(val)}
                >
                  <SelectTrigger id="select-pessoa">
                    <SelectValue placeholder="Selecione uma pessoa" />
                  </SelectTrigger>
                  <SelectContent>
                    {pessoasData?.map((p) => {
                      const key = `${p.colaborador_id}:${p.projeto_id}`;
                      const usoPct = (Number(p.utilizacao) * 100).toFixed(1);
                      return (
                        <SelectItem key={key} value={key}>
                          {`${p.colaborador_id} · ${p.nome} (${p.papel.toUpperCase()}) — ${p.projeto_id} (${usoPct}% uso)`}
                        </SelectItem>
                      );
                    })}
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label htmlFor="select-projeto">Projeto destino (atenção ou crítico)</Label>
                <Select
                  value={projetoSelecionado.projeto_id}
                  onValueChange={(val) => setProjetoId(val)}
                >
                  <SelectTrigger id="select-projeto">
                    <SelectValue placeholder="Selecione o projeto destino" />
                  </SelectTrigger>
                  <SelectContent>
                    {projetosElegiveis.map((proj) => (
                      <SelectItem key={proj.projeto_id} value={proj.projeto_id}>
                        {`${proj.projeto_id} · ${proj.nome_projeto} (${proj.situacao} · SPI ${formatIndice(proj.spi)} · falta_sre: ${Number(proj.dias_falta_sre)}d)`}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label htmlFor="input-onboarding">Horas de onboarding (mobilização)</Label>
                <Input
                  id="input-onboarding"
                  type="number"
                  min={0}
                  max={200}
                  value={horasOnboarding}
                  onChange={(e) => setHorasOnboarding(Number(e.target.value))}
                />
              </div>
            </CardContent>
          </Card>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-4">
            <Card>
              <CardHeader className="pb-2">
                <CardDescription>Horas no mês (× 4 semanas)</CardDescription>
                <CardTitle className="text-2xl">
                  {`${Math.round(calculo.horasNoMes)} h`}
                </CardTitle>
              </CardHeader>
              <CardContent className="text-xs text-muted-foreground">
                {`${formatIndice(calculo.horasParadasSemana)} h/semana paradas no ${pessoaSelecionada.projeto_id}`}
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardDescription>Ociosidade que deixa de ser paga</CardDescription>
                <CardTitle className="text-2xl text-success">
                  {formatBRLCompact(calculo.ociosidadeEvitada)}
                </CardTitle>
              </CardHeader>
              <CardContent className="text-xs text-muted-foreground">
                {`${formatBRL(calculo.ociosidadeEvitada)} (${formatBRL(calculo.custoOciosoSemana)}/sem × 4)`}
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardDescription>Dias de cronograma recuperados</CardDescription>
                <CardTitle className="text-2xl">
                  {`${calculo.diasRecuperados.toLocaleString('pt-BR', {
                    minimumFractionDigits: 1,
                    maximumFractionDigits: 1,
                  })} dias`}
                </CardTitle>
              </CardHeader>
              <CardContent className="text-xs text-muted-foreground">
                {`${calculo.diasImpacto90d}d de impacto (${calculo.causaAlvo}) ÷ 90 × 30`}
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardDescription>Custo de mobilização (onboarding)</CardDescription>
                <CardTitle className="text-2xl">
                  {formatBRLCompact(calculo.mobilizacao)}
                </CardTitle>
              </CardHeader>
              <CardContent className="text-xs text-muted-foreground">
                {`${formatBRL(calculo.mobilizacao)} (${calculo.onboardingHoras}h × ${formatBRL(calculo.custoHora)}/h)`}
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardDescription>Saldo líquido no 1º mês</CardDescription>
                <CardTitle className="text-2xl text-primary">
                  {formatBRLCompact(calculo.saldo)}
                </CardTitle>
              </CardHeader>
              <CardContent className="text-xs text-muted-foreground">
                {formatBRL(calculo.saldo)}
              </CardContent>
            </Card>
          </div>

          <Card>
            <CardContent className="pt-6">
              <details className="text-sm space-y-2">
                <summary className="font-semibold cursor-pointer text-foreground">
                  Como essa conta é feita? (Memória de cálculo)
                </summary>
                <div className="pt-3 space-y-2 text-muted-foreground border-t mt-2">
                  <p>
                    <strong>1. Horas disponíveis no mês:</strong> média de horas ociosas por semana nas últimas 12 semanas ({formatIndice(calculo.horasParadasSemana)} h/sem) × 4 semanas ={' '}
                    <strong>{formatIndice(calculo.horasNoMes)} h ({Math.round(calculo.horasNoMes)} h)</strong>.
                  </p>
                  <p>
                    <strong>2. Ociosidade que deixa de ser paga:</strong> custo ocioso médio semanal ({formatBRL(calculo.custoOciosoSemana)}) × 4 semanas ={' '}
                    <strong>{formatBRL(calculo.ociosidadeEvitada)}</strong> ({formatBRLCompact(calculo.ociosidadeEvitada)}).
                  </p>
                  <p>
                    <strong>3. Dias de cronograma recuperados em 30 dias:</strong> soma dos dias de impacto declarados nos últimos 90 dias para a causa{' '}
                    <code>{calculo.causaAlvo}</code> no projeto {projetoSelecionado.projeto_id} ({calculo.diasImpacto90d} dias) ÷ 90 × 30 ={' '}
                    <strong>
                      {calculo.diasRecuperados.toLocaleString('pt-BR', {
                        minimumFractionDigits: 1,
                        maximumFractionDigits: 1,
                      })}{' '}
                      dias
                    </strong>.
                  </p>
                  <p>
                    <strong>4. Mobilização (onboarding):</strong> {calculo.onboardingHoras} horas de rampa × custo/hora de {pessoaSelecionada.nome} ({formatBRL(calculo.custoHora)}/h) ={' '}
                    <strong>{formatBRL(calculo.mobilizacao)}</strong> ({formatBRLCompact(calculo.mobilizacao)}).
                  </p>
                  <p>
                    <strong>5. Saldo líquido no 1º mês:</strong> ociosidade evitada ({formatBRL(calculo.ociosidadeEvitada)}) − mobilização ({formatBRL(calculo.mobilizacao)}) ={' '}
                    <strong>{formatBRL(calculo.saldo)}</strong> ({formatBRLCompact(calculo.saldo)}).
                  </p>
                </div>
              </details>
            </CardContent>
          </Card>
        </>
      )}
    </div>
  );
}

const router = createBrowserRouter([
  {
    element: <Layout />,
    children: [
      { path: '/', element: <ProjetosEmRiscoPage /> },
      { path: '/simulador', element: <SimuladorPage /> },
    ],
  },
]);

export default function App() {
  return <RouterProvider router={router} />;
}
