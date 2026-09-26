# Caixa da Loja

Cada abertura concede **um item**: um estilo de nome ou uma moldura, nunca os dois juntos. O visual do prêmio usa o nome e a foto do próprio jogador. A animação de roleta revela um resultado definido pelo servidor antes de começar; fechar a animação não cancela nem repete o prêmio.

| Raridade | Chance | XP se o mesmo item já pertence ao jogador |
| --- | ---: | ---: |
| Comum | 40% | 25 XP |
| Raro | 30% | 50 XP |
| Épico | 15% | 100 XP |
| Mítico | 10% | 250 XP |
| Lendário | 5% | 500 XP |

Fluxo do sorteio: escolher a raridade, escolher entre nome e moldura, escolher um estilo dessa raridade e registrar o prêmio ou XP. A propriedade de nome e moldura é separada: possuir o nome “Fade” não torna a moldura “Fade” repetida. “Normal” e “Sem moldura” não entram nos prêmios. O servidor guarda o resultado e o saldo de caixas em uma única operação, para impedir abertura duplicada por atualização da página.

Na Loja, a caixa mostra chances, saldo disponível e botão de abrir. Após a roleta, aparecem “Equipar agora” e “Fechar”. O administrador pode conceder caixas a um jogador, com registro da concessão. O inventário é individual e os itens ganhos podem ser equipados mesmo sem Plus.

A compra permanece indisponível e nenhum valor é exibido na Loja.
