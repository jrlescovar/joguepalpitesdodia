# Retenção de dados temporários

Aplicada em 11/10/2026 pela migração `20261011040000_minimal_runtime_retention.sql`.

- `cron.job_run_details`: execuções bem-sucedidas são removidas a cada 15 minutos pelo job `runtime-history-cleanup`. Falhas ficam por até sete dias, limitadas às 100 mais recentes. Execuções em andamento são preservadas. O histórico é gerado pelo pg_cron; não foi desativado globalmente porque `cron.log_run` exige reinício do servidor neste projeto.
- `level_drop_requests`: conserva as respostas enquanto o drop está `playing` ou `ready`, mantendo a proteção contra cliques repetidos, inclusive após uma falha de conexão. Ao finalizar, `interact_level_drop` apaga os recibos daquele drop e não grava outro. Repetir a abertura retorna `level_drops.reward` já persistido, sem creditar item ou XP novamente. Não expirar recibos de drops ainda ativos.
- `box_style_catalog`: removidos apenas `halloween-house`, `halloween-graveyard` e `halloween-bats`, aposentados e sem referências. Itens aposentados referenciados por inventário, perfil, correio ou abertura devem permanecer.

A limpeza é restrita a `postgres`/`service_role`; jogadores não podem invocá-la. Não alterar perfis, inventário, saldos, recompensas, histórico de aberturas ou tarefas de jogo para reduzir armazenamento temporário.

Verificação: `supabase/tests/minimal-runtime-retention.sql` executa fixtures e desfaz tudo com `ROLLBACK`. Cobre repetição de cliques, estado ativo/pronto, fechamento, XP/item uma única vez, falha atômica, isolamento de jogadores, permissões e política dos logs.

Compactação única: `scripts/data-fixes/2026-10-11-compact-runtime-history.sql` foi aplicada após a limpeza. Usa bloqueio curto e cópia temporária para manter todos os logs ainda existentes, inclusive execuções em andamento; não reinicia a sequência de IDs. Só esvazia fisicamente o cache se ele já estiver vazio. Não programar essa compactação como tarefa recorrente.

Backup anterior à limpeza: `.runtime/backup-minimal-runtime-before.json` (somente local). Resultados: `.runtime/minimal-retention-final-verification.json`. Os dados de perfis, inventário, aberturas e drops foram comparados antes/depois e permaneceram idênticos. Aproximadamente 3,6 MiB foram liberados no banco; os logs e cache passaram juntos de 3.866.624 bytes para 49.152 bytes físicos.

Referências: https://supabase.com/docs/guides/cron/quickstart e https://github.com/citusdata/pg_cron/blob/main/README.md.
