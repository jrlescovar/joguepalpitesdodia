# Caixas de personalização — 14/10/2026

Ativos originais criados com a ferramenta integrada de geração de imagem, com a referência de maletas reforçadas fornecida pelo usuário. A referência foi usada como inspiração visual. Conversão para WebP com Sharp, mantendo a transparência gerada.

## Arquivos publicados

- Moldura: `public/midia/caixas/frame-case-front-20261014.webp` (azul, símbolo de moldura, vista frontal corrigida)
- Nome: `public/midia/caixas/name-clean-20261014.webp` (verde, decoração gravada, sem N)
- Fonte: `public/midia/caixas/font-spray-20261014.webp` (roxo, respingos e traços de spray, sem Aa)
- Personalização: `public/midia/caixas/classic-clean-20261014.webp` (dourado, sem paleta)
- Halloween: `public/midia/caixas/halloween-case-20261014.webp` (laranja, abóbora iluminada, teias e detalhes roxos)

Originais PNG copiados para `.runtime/caixas-originais-20261014/`. Prévia dos quatro ativos: `.runtime/caixas-reforcadas-preview.png`.

## Conjunto de prompts

Prompt base:

> Create ONE premium 3D game inventory case icon for a dark mobile game store. Reference image is ONLY style inspiration from the colored reinforced game cases, not a screenshot to copy. Render a single hard-shell rectangular equipment case at a consistent gentle front three-quarter angle, front face dominant and a little right side and lid visible. Carrying handle on top, two metal front latches, reinforced corners, shallow vertical ribs, subtle beveled panel seams, refined painted metal with slight realistic texture. Studio light top-left, restrained highlights, soft shadows ON the case. No floor, no backdrop, no cast shadow outside the object. Entire case isolated with genuine transparent background. Center the complete case in a square canvas, occupy about 88% width and 65% height. It must read clearly at 28px. No weapons, people, screenshots, watermarks, labels or game-brand logos. Original asset for a customization game.

Variações: azul com moldura branca vazia; verde esmeralda com placa branca e N; violeta com Aa em branco; dourado com paleta branca e três cores pastel. Mesmo acabamento metálico, sem logotipos de jogos.

Edição final por ativo:

> Make it a clean transparent-background product cutout for a UI icon. Preserve the case shape, paint color, metal corners, carrying handle, latches, front symbol, painted design and all lighting ON the object. Remove everything outside the physical case: floor, environment, scenery, blurred background, light halo, colored glow and cast shadow. Outside the silhouette must be transparent. Do not change the symbol or perspective.

## Integração

`CustomizationBoxIcon.tsx` escolhe o ativo pelo tema, mantendo o contrato de tamanho, classe e abertura usado pela loja, caixa de entrada, passe e roleta. Os cinco temas usam maletas e tampa separada do corpo. Regras de compra e de sorteio não foram alteradas nesta substituição visual.

Prévia visual dos ativos conferida. O navegador de automação não estava disponível nesta sessão; a interface autenticada não foi validada visualmente no navegador.

## Ajuste de vista e abertura

Moldura editada pela ferramenta integrada de geração de imagem. Prompt: "Edit the blue case into a perfectly straight front view. Preserve blue textured metal, white frame emblem, silver corners, two latches and black handle. Centered camera, symmetrical left and right, level horizontal edges, no visible side panels or tilted perspective. Transparent background. Clearly horizontal lid seam."

Original da edição: `.runtime/caixas-originais-20261014/frame-front.png`; prévia: `.runtime/frame-front-preview.png`.

Corpo e tampa usam duas camadas alinhadas do mesmo ativo, recortadas na emenda por CSS. A tampa levanta com perspectiva em 500 ms; o giro começa aos 700 ms e mantém a duração de 4,4 segundos. Apenas transform e opacity são animados. A preferência de movimento reduzido pula o giro e mantém a apresentação do resultado. A imagem da caixa fechada permanece nivelada.

Verificação isolada da sequência real do componente (backend, hooks e DOM de roleta simulados): `.runtime/check-case-opening-flow.mjs`. Conferidos feedback imediato, bloqueio de clique duplo, reuso do mesmo requestId após falha, tampa antes da roleta, prêmio final e preservação de um prêmio confirmado caso a atualização local falhe. Nenhuma caixa real foi consumida pelos testes. O erro específico de conexão da foto não foi reproduzido; falta acesso ao navegador autenticado nesta sessão.

## Halloween e correção da falha de abertura

Halloween criado pela ferramenta integrada de geração de imagem, tomando a maleta de nome como referência de formato. Prompt: "Halloween edition of this reinforced 3D inventory case. Same straight centered front view, level edges, handle, three metal latches and corner guards. Pumpkin orange paint, charcoal metal corners, dark violet engraved flourishes and small spiderweb accents. Replace N with a large glowing jack-o-lantern face. Transparent background, no floor or scenery, 3:2 canvas with margins, horizontal lid seam. No game-brand logos or words."

Original: `.runtime/caixas-originais-20261014/halloween.png`; prévia: `.runtime/halloween-case-preview.png`. WebP otimizado com Sharp, preservando a transparência gerada. A tampa usa o mesmo movimento das demais caixas.

A falha da foto foi posteriormente reproduzida no banco: `pass_xp` passou a multiplicar por 2, mas `box_openings_xp_awarded_check` não incluía 400 e 2000 XP. Aberturas com item épico ou lendário repetido de apoiadores eram revertidas pelo PostgreSQL. A migração `20261014142000_box_duplicate_supporter_double_xp_constraint.sql` acrescenta esses dois valores, preservando os valores históricos, e foi aplicada e registrada no Supabase.

## Decoração sem símbolos e fonte com spray

Edições feitas pela ferramenta integrada de geração de imagem, usando os respectivos originais. Invariantes de prompt: preservar exatamente silhueta, escala, posição, câmera, proporções, alça, travas, emenda da tampa, cantos metálicos, iluminação, textura, proporção do canvas, margens e transparência. Alterar apenas a decoração frontal, sem letras ou logotipos.

- Nome: remover N e placa branca; completar a região com metal verde e o padrão gravado ao redor, sem emblema substituto.
- Personalização: remover toda a paleta branca e os pontos de cor; completar com o mesmo metal amarelo texturizado.
- Fonte: remover Aa; acrescentar respingos de spray turquesa e rosa, pequenos detalhes verde-lima, poucos escorridos finos e traços de grafite pintados na superfície. Manter roxo dominante e a estrutura intacta, sem palavras, latas ou símbolos de paleta.

Originais das edições: `.runtime/caixas-originais-20261014/name-clean.png`, `classic-clean.png` e `font-spray.png`. Prévia dos três: `.runtime/caixas-decoracao-preview.png`. A conversão WebP usa Sharp para otimização e preserva a transparência da geração. Os tamanhos na interface e os movimentos de tampa permanecem iguais.

O teste `supabase/tests/box-supporter-double-xp-constraint.sql` falhou com a restrição antiga e passou depois da correção: 44 combinações de tipo de caixa/raridade/apoiador, itens novos e repetidos, XP real, saldo e idempotência. Testes executados em transação com rollback; perfis, saldos e registros reais preservados, nenhum perfil temporário remanescente. Auxiliares de produção restaurados após rollback. Não houve validação visual da interface autenticada no navegador nesta sessão.
