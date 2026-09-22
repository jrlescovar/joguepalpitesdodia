# Validação — 21/09/2026

- Build React/TypeScript concluído.
- 21 testes passaram: 8 de domínio e 13 de integração com regras reais no Firestore Emulator.
- Validados: reserva do ID 1000001, IDs concorrentes, nomes únicos sem distinção de caixa, renomeação atômica, privacidade, proteção de saldo/XP/ID, autorização administrativa, paginação, palpite único, prazo pelo servidor e liquidação idempotente.
- Fluxo visual no emulador: login de teste, cadastro, início vazio, perfil, edição de nome/cor, persistência após recarregar, ranking com posição real e tela Em breve.
- Login inspecionado em larguras CSS 320, 360, 375, 390 e 430, sem overflow horizontal. Início e ranking privados também inspecionados em viewport móvel.
- Layout da versão pública inspecionado no navegador. Rodapé confirmado: © 2026 Desenvolvido por Jrlescovar.
- Hosting publicado em https://jogueapostadodia.web.app.
- Regras e índices publicados no banco EXISTENTE `projects/jogueapostadodia/databases/default`, edição Enterprise Native. Nenhum banco novo foi criado.
- HTML, JavaScript, CSS e favicon públicos retornaram HTTP 200.
- Sem Cloud Functions: fontes antigas e configuração de deploy removidas. Nenhuma função foi publicada. Nenhuma cobrança ou plano foi ativado.

## Limites da validação

- A autenticação Google real do proprietário não foi concluída pelo agente. Cadastro e perfil foram testados exclusivamente em ambiente isolado. Entre com admin@example.invalid no site público para criar seu perfil real e receber o primeiro ID.
- Não foram usados aparelhos físicos Android/iPhone; a verificação visual foi feita no navegador com viewport reduzido.
- App Check depende da chave de site e do registro/enforcement no console; o código mantém a integração opcional, sem alegar configuração concluída.
- A liquidação é iniciada pelo proprietário e precisa da página aberta; após interrupção, há o botão Retomar liquidação. Não existe processo em segundo plano com a página fechada.
- O build emite aviso de tamanho do pacote Firebase; isso não bloqueou compilação ou publicação.
