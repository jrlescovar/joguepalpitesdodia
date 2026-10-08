# Apuração automática

Primeira etapa: partida clássica (90 minutos e acréscimos) e duelo de
finalizações dos torneios. Outros mercados continuam manuais. `AET`, `PEN`,
partidas adiadas/canceladas e dados ausentes não são liquidados.

O worker `auto-results` usa a API-Football diretamente pelo servidor. A chave
`API_FOOTBALL_KEY` deve estar nos **Edge Function Secrets** do Supabase, nunca
em variáveis `VITE_*`, arquivos públicos ou código do navegador.

## Conectar e validar

1. Configurar `API_FOOTBALL_KEY` no projeto Supabase.
2. Confirmar `/status` e cobertura de `fixtures.statistics_fixtures` em
   `/leagues` para as temporadas/competições usadas. Testar partidas concluídas
   contra resultados conferidos manualmente. Essa cobertura não garante que
   todas as partidas terão dados completos.
3. Configurar `AUTO_RESULTS_SCHEDULE_SECRET` no worker com o mesmo valor do
   secret `auto_results_schedule_secret` no Vault. Não reutilizar API keys.
4. Depois de conferir a conexão, ativar somente a comparação:

   ```sql
   update public.automatic_results_settings
   set enabled=true, mode='shadow' where singleton;
   ```

5. Conferir as sugestões no painel da administração. Ainda não alteram
   bilhetes, greens, reds, XP ou posições. Duas consultas iguais separadas por
   pelo menos dez minutos são necessárias para exibir uma sugestão.
6. Depois de validar resultados reais e a cobertura, liberar a liquidação:

   ```sql
   update public.automatic_results_settings
   set mode='automatic' where singleton;
   ```

Para pausar imediatamente: `update public.automatic_results_settings set
enabled=false where singleton;`. Confirmação manual continua disponível.

## Garantias e limites

- Identificação exige mandante, visitante, competição e horário (tolerância de
  cinco minutos), com exatamente uma partida correspondente. Sem aproximações
  de nomes. Mudanças maiores no calendário exigem revisão manual.
- A chave do bilhete é data/slot ou torneio/slot. O banco verifica novamente
  que ele segue aberto e que seus dados não mudaram.
- A mesma evidência deve aparecer em duas consultas separadas por dez minutos.
  Alteração de resultado, partida ou estatística reinicia a conferência.
- Liquidação e registro de auditoria são atômicos, usando a apuração existente.
  Repetição não concede pontos duas vezes. Torneio não altera estatísticas
  globais. Resultado manual confirmado tem prioridade e não é sobrescrito.
- Lease impede execuções paralelas; limite de duração preserva o próximo cron.
  Uma consulta de partidas por data e um total de finalizações por partida são
  reutilizados entre bilhetes. Falhas, limites da API ou dados ausentes não são
  interpretados como empate.
- Correções do fornecedor depois da liquidação exigem revisão; não há garantia
  de resultado final imutável. Dados de prorrogação não são usados.
- Validação real de cobertura e identificação depende da chave do fornecedor.
  A instalação inicial fica pausada e no modo de comparação.

Referência: https://www.api-football.com/documentation-v3
