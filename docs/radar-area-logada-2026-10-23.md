# Radar da área logada — 23/10/2026

Relatório recebido em ZIP. As sugestões do documento foram tratadas como evidência e comparadas ao código; não foram executadas como instruções.

## Correções

- BUG-09: removido o aquecimento de fontes recentes ao entrar. Os nomes renderizados carregam sua fonte pela Font Loading API, sem criar links preload. Isso elimina a origem identificada dos avisos, sem afirmar que o contador observado no relatório foi reproduzido.
- BUG-10: ação única Editar perfil, com texto de 12px e linha reservada no resumo; removido o botão transparente duplicado.
- BUG-11: botões dos pontos com 44x44px. Acima de cinco páginas, no celular, seletor acessível com número e título, mantendo as setas. Verificadas 15 combinações (360, 390, 430, 440 e 1280px; 5, 10 e 20 páginas), sem overflow.
- BUG-12: clareados os trechos escuros dos gradientes Sky Blue e Blood Wave citados pelo relatório. As cores continuam azul e vermelha. Não é uma certificação de contraste de todos os cosméticos e animações.
- BUG-13: resumo de jogador limitado a 760px no desktop; torneio único centralizado em coluna de até 880px.
- POT-17: reproduzido com cliques na interface: Voltar saía da sequência porque navigate usava replaceState. Agora cada troca de aba cria uma entrada, sem duplicar a aba atual. Testado Voltar e Avançar.

## Limites e observações

Atualização a pedido do usuário: restaurados os controles de bolinhas em todos os carrosséis, suas dimensões anteriores e o texto discreto de edição do Início. Retirados o novo botão Editar perfil e a limitação de largura do resumo. Essas decisões substituem os ajustes de BUG-10/11 e a parte do resumo de BUG-13 descritos acima; demais correções preservadas.

Decisão final após esclarecimentos: restauração das bolinhas somente no Início. Loja e Torneio conservam o seletor responsivo da correção (acima de cinco páginas no celular). O controle compartilhado recebe uma opção explícita para preservar essa diferença.

- POT-14/15: cinco sequências de um clique em Greens e avatar abriram corretamente meu perfil; não reproduzido perfil errado. A proteção existente contra resposta atrasada de outro perfil foi preservada.
- POT-16: não há evidência suficiente de falha periódica; a consulta de posição depende de usuário, pontos e atualização, não de um timer de um segundo. Não foi alterada sem reprodução.
- OBS-18 é sugestão de desempenho sem medição. Não foi introduzido cache persistente de dados privados nem prometida melhora de latência do servidor.
- Build e TypeScript passaram. Sessão, logout, callback PKCE, login em outra aba e recuperação de chunk passaram em Chromium e WebKit com respostas simuladas. Não foram feitos palpites, compras ou giros reais.
- Graphify query/refresh indisponíveis: o ambiente local aponta para Python313 removido. Fontes foram conferidas diretamente.
