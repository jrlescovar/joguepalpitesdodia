# Roleta: atualização visual

Arte em SVG e CSS nativos, com aro metálico dourado, pequenos rebites, setores sombreados com divisórias discretas, centro em relevo, ponteiro facetado e caixas de 52 px. As posições dos ícones continuam no raio de 36% usado pela animação existente. As proporções dos setores são calculadas por `wheelSegments`, a partir dos mesmos pesos retornados pelo servidor.

`WheelArt.tsx` contém a arte; `WheelPanel.tsx` conserva as solicitações, permissões, resultados, retomada e navegação existentes. Nenhuma alteração no banco ou nas chances. O movimento continua com a mesma duração e tratamento de movimento reduzido.

Validação: build aprovado e 20 testes de geometria, movimento e destino das recompensas aprovados. Prévia estática gerada a partir dos componentes reais de face e aro, com os arquivos atuais das caixas: `.runtime/roleta-novo-design.png`. Essa prévia usa pesos de teste e não é uma captura da página autenticada. O navegador de automação estava indisponível; não foi feita validação visual ou interação em um celular real nesta sessão.
