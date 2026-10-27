import { createApp, analytics, server } from '@databricks/appkit';

createApp({
  cache: { enabled: false },
  plugins: [
    analytics(),
    server(),
  ],
  onPluginsReady(appkit) {
    appkit.server.extend((app) => {
      app.get('/api/score-estouro', async (_req, res) => {
        try {
          const rows: unknown = await appkit.analytics.query(
            `SELECT
               projeto_id,
               data_referencia,
               prob_estouro_30d,
               ranking,
               faixa_risco,
               principais_fatores
             FROM lakehouse_vertice.gold.score_estouro_30d`
          );
          const linhas: unknown[] = Array.isArray(rows) ? rows : [];
          res.json({ disponivel: true, linhas });
        } catch {
          res.json({ disponivel: false, linhas: [] });
        }
      });
    });
  },
}).catch(console.error);
