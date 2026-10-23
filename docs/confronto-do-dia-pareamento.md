# Pareamento do Confronto do Dia

As regras usam pontos do Ranking Global e o dia de Brasília:

- O mesmo par de jogadores não se repete em dias consecutivos, mesmo trocando Casa/Fora ou criando as rodadas fora de ordem. O bloqueio também existe no trigger de gravação.
- O sorteio normal começa por diferença de até 200 pts e amplia até 300, 400 e 500. Assim, 1990 pode enfrentar 1530.
- Quando ambos os jogadores têm 2100+ pts, não há limite de diferença. Contra quem está abaixo de 2100, permanece o limite normal de 500.
- O top 10 é priorizado pelo Ranking Global atual, incluindo os que estão protegidos por inatividade. Primeiro se busca cobertura completa com adversários dentro das regras normais. Quando não é possível, o limite de diferença é removido para completar as partidas desses líderes, sem repetir o adversário do dia anterior. Isso permite 2000 contra 1100.
- Se não houver oponente livre no grupo já sorteado, podem entrar jogadores cadastrados ainda sem partida, inclusive protegidos por inatividade. Apenas os escolhidos são incluídos; não são salvas vagas extras e a proteção não é alterada.
- Confrontos já pareados e resultados encerrados são preservados. A aplicação preenche apenas vagas abertas de hoje e amanhã; não refaz resultados passados.

A migração `20261011110000_daily_battle_master_top10_fallback.sql` usa os locks de rodada e finalização existentes. O planejamento ocorre antes da gravação e conserva a pontuação capturada no sorteio. O sorteio não concede ou retira PontosRank, XP ou estatísticas de vitórias/derrotas.

A prioridade elimina a falta de adversário por diferença de pontos. Se não existir nenhum outro jogador disponível que respeite a regra de dias consecutivos, continua proibido inventar um adversário, duplicar jogadores ou repetir o par. O teste cobre a base real, 20 sorteios, limites 500/501, Mestres, entrada tardia, reservas, recrutamento de emergência, duplicatas, idempotência e preservação dos confrontos e totais.

Validação: `supabase/tests/daily-battle-pairing-rules.sql`, sempre em transação com rollback. A cópia anterior dos dados e funções está em `.runtime/daily-pairing-before.json`.
