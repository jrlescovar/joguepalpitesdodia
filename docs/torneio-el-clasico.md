# EL CLÁSSICO

Torneio criado a pedido do proprietário para Barcelona x Real Madrid em 25/10/2026.

- ID: `2270fca1-406c-4da0-8582-20c20520a44c`.
- Inscrição: R$ 4,44, com confirmação pelo fluxo de pagamento existente.
- Início e fechamento de todos os palpites: 25/10/2026 às 16:50 de Brasília.
- Encerramento: 26/10/2026 às 00:00 de Brasília.
- 20 palpites em um dia, modalidade `mixed`; cada acerto vale um ponto no torneio.
- Premiação: R$ 4,44 por inscrito, dividida entre os jogadores empatados no maior número de acertos.
- Card no layout e tamanho do da Champions, com azul/grená (Barcelona) e branco/dourado (Real Madrid) em tons discretos no fundo. Ranking com as cores padrão.
- Navegação: Champions primeiro, EL CLÁSSICO segundo. O torneio de cartões foi restaurado do backup e aparece em terceiro, encerrado, com o vencedor no lugar do botão de entrada.

## Palpites e opções

| # | Palpite | Opções |
|---|---|---|
| 1 | Quem vence? | Casa / X / Fora |
| 2 | Mais finalizações | Casa / X / Fora |
| 3 | Mais chutes ao gol | Casa / X / Fora |
| 4 | Mais cartões | Casa / X / Fora |
| 5 | Mais escanteios | Casa / X / Fora |
| 6 | Mais impedimentos | Casa / X / Fora |
| 7 | Mais faltas cometidas | Casa / X / Fora |
| 8 | Mais de 2,5 gols | Sim / Não |
| 9 | Finalizações do Raphinha | 0–2 / 3–4 / 5+ |
| 10 | Finalizações do Yamal | 0–2 / 3–4 / 5+ |
| 11 | Finalizações do Vini Jr. | 0–2 / 3–4 / 5+ |
| 12 | Finalizações do Mbappé | 0–2 / 3–4 / 5+ |
| 13 | Defesas dos goleiros do Barcelona | 0–2 / 3–5 / 6+ |
| 14 | Defesas dos goleiros do Real Madrid | 0–2 / 3–5 / 6+ |
| 15 | Ambos os times marcam | Sim / Não |
| 16 | Quem marca primeiro | Casa / Nenhum / Fora |
| 17 | Quem vence o primeiro tempo | Casa / X / Fora |
| 18 | Mais posse de bola | Casa / X / Fora |
| 19 | Vai ter cartão vermelho | Sim / Não |
| 20 | Mais de 5,5 cartões | Sim / Não |

Casa é Barcelona; Fora é Real Madrid. Valem os 90 minutos e acréscimos; primeiro tempo inclui seus próprios acréscimos. Finalizações incluem chutes para fora e bloqueados. Quem não jogar tem zero finalizações. Defesas somam os goleiros da equipe, incluindo substitutos.

Cartões incluem amarelos e vermelhos diretos dos jogadores em campo. Segundo amarelo conta nos amarelos, sem acrescentar outro vermelho ao total. Expulsão por segundo amarelo vale como vermelho para o palpite 19. Mais de 5,5 equivale a pelo menos 6 cartões.

## Implementação e validação

A migração `20261011080000_el_clasico_mixed_tournament.sql` acrescenta opções e regras por palpite. Os IDs `home`, `draw` e `away` são identificadores internos das alternativas; em mercados binários só `home` (Sim) e `away` (Não) são válidos. Triggers validam escolhas e resultados, impedem alteração das regras após respostas e recusam apuração de faixas por comparação de totais.

Apuração e correção são feitas no painel existente, usando as opções de cada mercado. A automação de placares/finalizações não inclui a modalidade `mixed`. Inscrição, privacidade, prazo, idempotência, cálculo de acertos e auditoria seguem os mecanismos existentes. A criação não inscreve jogadores nem gera pagamentos.

Após a criação, o proprietário solicitou a inscrição administrativa do zaotips (#1000001). Ela foi registrada por `scripts/data-fixes/2026-10-11-el-clasico-zaotips-entry.sql`, sem gerar pedido de pagamento ou palpites. A conta tem acesso aos 20 palpites; novas inscrições continuam por R$ 4,44.

`supabase/tests/el-clasico-mixed.sql` verifica os RPCs reais dentro de uma transação revertida, incluindo preço, alternativas inválidas, prazos, apuração, correção, privacidade e preservação dos torneios anteriores.
