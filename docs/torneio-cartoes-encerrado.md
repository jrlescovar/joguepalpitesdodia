# Torneio Duelo de Cartões encerrado

O torneio `671f995b-18bf-4c49-a706-caff6e580e19` foi restaurado do backup local após solicitação do proprietário. Encerrou em 11/10/2026 às 18:14 de Brasília. A ordem da lista continua Champions, EL CLÁSSICO, Cartões.

Foram restaurados 20 resultados apurados, 11 inscrições, 220 palpites, cinco pedidos de pagamento e quatro correções administrativas. Os identificadores, datas e valores originais foram preservados. Os 120 logs antigos de automação ficaram apenas no backup local, sem voltar ao banco. Nenhum pagamento foi processado novamente e nenhum ponto foi acrescentado ao ranking global.

O vencedor é NicoTheGoat, com 11 pontos de torneio (um por acerto). O card mostra a foto e a personalização do nome do perfil público, com o total de pontos, no lugar da inscrição e de “Ver palpites e ranking”. O status é “TORNEIO ENCERRADO”.

A migração `20261011100000_finished_tournament_winners.sql` acrescenta `winners` ao RPC existente. Só fornece vencedores depois do encerramento e da apuração de todos os resultados. Inclui todos os empatados na maior pontuação. O vencedor é visível a qualquer jogador autenticado; os palpites continuam privados aos inscritos. O helper não tem permissão de execução para anon/authenticated. Um torneio ainda não apurado mostra “Resultado final em apuração.”.

A restauração dos dados pessoais e financeiros foi gerada em `.runtime/restore-cards-data.sql` a partir de `.runtime/cards-removal-backup.json`, sem inserir esses dados no código versionado. O ensaio completo foi validado em transação com rollback antes da aplicação. `supabase/tests/restored-cards-winner.sql` valida a restauração, privacidade, empate, resultado pendente, ordem e preservação dos demais dados.
