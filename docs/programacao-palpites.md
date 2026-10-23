# Programação dos palpites

Cada dia tem 10 palpites: um principal e nove extras. Nos dias com muitos jogos,
especialmente terça, quarta, quinta, sábado e domingo, selecionar **6 confrontos**:
quatro confrontos com dois mercados diferentes e dois com um mercado cada
(2 + 2 + 2 + 2 + 1 + 1). Nenhum confronto deve aparecer três vezes.

A programação de 13 a 25/10/2026 usa seis confrontos em todos os dias, exceto
25/10: **7 mercados de Barcelona x Real Madrid** e 3 palpites de outros jogos.
Essa é uma exceção explícita solicitada pelo proprietário.

O gerador `scripts/prepare-daily-schedule.py` valida a distribuição, as datas de
Brasília, as fontes e os horários confirmados antes de gerar JSON/CSV. Ele não
publica no banco. As partidas selecionadas e suas fontes estão em
`scripts/data-fixes/2026-10-13-a-25-fixtures.json`.

Os prazos continuam encerrando 10 minutos antes do início. Os nomes dos times
ficam no confronto; as opções correspondentes são exibidas como Casa e Fora.
As regras automáticas de pontos em dobro às quintas permanecem válidas.

Ao trocar um confronto já publicado, preservar os palpites humanos ou interromper
a troca para resolver essas escolhas. Nunca transferir uma escolha humana para
outro jogo. Nesta revisão só havia bots nos mercados alterados: as escolhas deles
foram sorteadas novamente com a regra de risco existente, sem novo crédito de XP.

El Clásico confirmado para 25/10/2026 às 21h na Espanha, 17h em Brasília:
[comunicado do Real Madrid](https://www.realmadrid.com/es-ES/noticias/futbol/primer-equipo/actualidad/el-barcelona-real-madrid-se-jugara-el-domingo-25-de-octubre-a-las-21-00-h-01-09-2026).
