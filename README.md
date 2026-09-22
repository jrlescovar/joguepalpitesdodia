# Aposta do Dia

Site mobile-first com React, Vite, TypeScript, Tailwind, Firebase Authentication, Cloud Firestore e Hosting. A arquitetura atual não utiliza Cloud Functions nem exige Blaze. O plano Spark possui cotas de uso: se forem atingidas, operações podem ser interrompidas até a renovação das cotas.

Identidade visual azul; verde exclusivo de greens e vermelho de reds. Rodapé: © 2026 Desenvolvido por Jrlescovar.

## Executar

Requer Node.js 22 e npm.

```sh
npm ci
npm run dev
npm run build
```

Preview: http://localhost:5173. Configuração pública Firebase em `src/firebase.ts`, projeto `jogueapostadodia`, banco nomeado `default` (sem parênteses). Nenhuma chave privada, Admin SDK ou banco de dados em localStorage é usado. A persistência de sessão é gerenciada pelo Firebase Authentication.

## Firebase e publicação

```sh
npx firebase login
npm run deploy
```

Publicação: Hosting, regras e índices Firestore no projeto `jogueapostadodia`, usando `admin@example.invalid`. O comando não publica funções.

- Ative o provedor Google em Authentication. Autorize localhost e os domínios jogueapostadodia.web.app e jogueapostadodia.firebaseapp.com.
- Faça o primeiro cadastro com a conta Google verificada `admin@example.invalid`. O ID 1000001 fica reservado a essa conta. O login do proprietário precisa ser feito pela própria pessoa; os testes locais não criam uma conta real.
- No Perfil → Administração, libere os cadastros públicos depois de criar o proprietário.
- App Check está preparado de forma opcional: registre o aplicativo e configure `VITE_RECAPTCHA_ENTERPRISE_SITE_KEY` antes de ativar enforcement no Firestore. A chave é pública. Nenhuma validação de App Check é contornada.
- O login usa redirecionamento na própria página para não depender de pop-ups. Em produção, o retorno OAuth usa `https://jogueapostadodia.web.app/__/auth/handler`, no mesmo domínio do site, para preservar a sessão em navegadores que isolam armazenamento entre domínios.

## Operações sem servidor próprio

`src/data.ts` executa transações do SDK cliente. **O cliente não é a autoridade:** `firestore.rules` valida as operações usando identidade autenticada, dados atuais, estado atômico pós-transação (`getAfter`) e horário de servidor (`request.time`).

- Cadastro: cria perfil privado, perfil público, reserva do nome e contador numa transação. IDs são sequenciais; conflitos concorrentes são tratados. O cliente não pode pular o contador nem mudar ID ou saldo.
- Nomes: 3–12 caracteres A–Z, números ou underscore, comparação sem diferenciar maiúsculas. Renomear libera a reserva antiga atomicamente.
- Perfil público: somente playerId, username, avatarColor e green. E-mail e saldo permanecem no perfil privado. O proprietário pode consultar perfis necessários à liquidação; jogadores comuns não podem ler perfis privados de terceiros.
- As reservas permitem consulta exata para disponibilidade, sem listagem. O contador permite leitura autenticada do próximo ID e UID proprietário, sem dados privados. A gravação é estritamente validada.
- Palpites: um documento imutável por jogador/dia. Regras verificam prazo e data de Brasília. Sequência diária é gravada na mesma transação e derivada na tela quando existe um dia perdido.
- Greens: 1 ponto e 25 XP. Reds: 0 XP. Próximo nível custa nível × 15. Recompensas e atualização do palpite são atômicas e validadas pelas regras, incluindo o perfil público.
- Ranking: paginação real de 25 jogadores por greens e ID crescente. A posição pessoal percorre páginas de até 50 perfis; esse cálculo consome leituras proporcionais à posição.
- Horário exibido: obtido por timestamp do servidor em documento privado de relógio, com cache em memória de cinco minutos. O prazo de gravação é sempre decidido por `request.time`, mesmo se o relógio do aparelho for alterado.

## Administração e liquidação

O primeiro UID proprietário fica permanente em `meta/counters`. Apenas esse UID pode publicar desafios, liberar inscrições ou liquidar resultados. O e-mail informado em um formulário nunca concede poderes.

Publique desafios em ordem crescente de data. A data anterior é registrada em cada desafio, e as regras exigem sua liquidação antes de iniciar o seguinte. Desafios publicados e resultados confirmados são imutáveis.

A liquidação é coordenada pelo navegador autenticado do proprietário, em páginas de 40 palpites, com uma transação por jogador. Mantenha a tela aberta até terminar. Se a conexão cair ou a página fechar, use **Retomar liquidação**. Palpites já processados são ignorados sem duplicar greens ou XP. Não existe processamento em segundo plano após fechar o navegador. O proprietário é responsável por só concluir o desafio depois de percorrer todos os palpites; o cliente administrativo implementa esse percurso. As regras validam cada recompensa individual, mas não contam toda a coleção para validar o encerramento global.

## Testes

```sh
npm test
npm run test:integration
```

Os testes de integração exigem Java 17+ e usam exclusivamente `demo-apostadodia`, sem alterar a produção. Incluem concorrência, unicidade, privacidade, adulteração de estatísticas, prazo, palpites e liquidação idempotente.

Se o Java no Windows apresentar erro de loopback ou de locale, inicie o emulador com diretório curto e idioma inglês. Exemplo após baixar o emulador via Firebase CLI:

```powershell
$env:JAVA_TOOL_OPTIONS='-Duser.language=en -Duser.country=US -Djdk.net.unixdomain.tmpdir=C:\apostadodia\.runtime\java-tmp'
$env:FIREBASE_EMULATORS_PATH='C:\apostadodia\.runtime\emulators'
$env:XDG_CONFIG_HOME='C:\apostadodia\.runtime\firebase-config'
npm run test:integration
```

Crie previamente `.runtime/java-tmp`. Para testes contra um emulador já ativo, configure `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080` e execute `npm test`.

Para desenvolvimento isolado da interface, copie `.env.example` para `.env.local`, configure `VITE_USE_EMULATORS=true`, inicie `npm run emulators` e depois `npm run dev`. O Auth Emulator permite identidades de teste; esses usuários não existem na produção.

## Arquivos principais

- `src/App.tsx`: login e apresentação.
- `src/PlayerApp.tsx`: início, perfil e navegação.
- `src/DailyCard.tsx`, `src/Ranking.tsx`, `src/Admin.tsx`: palpites, ranking e administração.
- `src/data.ts`, `src/domain.ts`: transações e cálculos.
- `firestore.rules`, `firestore.indexes.json`: segurança e índices.
- `tests/`: testes de domínio e integração com regras reais.

Referências: [transações e validação atômica](https://firebase.google.com/docs/firestore/manage-data/transactions), [regras do Firestore](https://firebase.google.com/docs/firestore/security/rules-conditions), [autenticação Google](https://firebase.google.com/docs/auth/web/google-signin).
