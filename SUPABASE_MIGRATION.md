# Migração para Supabase

O site continua hospedado no Firebase Hosting. Autenticação, perfis, palpites e ranking passam para Supabase Auth + PostgreSQL. Não há assinatura Realtime nem processamento jogador por jogador no navegador.

## O que já está pronto

- Esquema PostgreSQL, índices, regras de acesso e funções em `supabase/migrations/001_initial.sql`.
- Login Google pelo Supabase.
- Um único comando transacional para concluir a aposta: resultado, greens/reds, 25 XP, sequências, posições e movimento no ranking.
- 5 XP no momento da confirmação do palpite.
- Ranking lê somente o top 10 e a posição do usuário.
- Dados privados, e-mail e saldo não aparecem no perfil público.
- O administrador `admin@example.invalid` controla cadastros, desafios, resultados e edição dos jogadores.
- Sem consultas Realtime permanentes. A tela atualiza ao entrar, ao voltar para a aba e depois de uma ação do usuário.
- RLS em todas as tabelas, acesso mínimo por RPC e permissões automáticas revogadas.
- Limite de 60 chamadas da Data API por minuto por usuário/IP, aplicado antes da função solicitada.
- Firebase Hosting e Supabase filtram DDoS na borda; o site também envia CSP, HSTS e Permissions Policy.

## Conectar o projeto gratuito

1. Crie um projeto no plano Free em Supabase.
2. Abra **SQL Editor**, cole todo o arquivo `supabase/migrations/001_initial.sql` e execute uma vez.
3. Em **Authentication > URL Configuration**, use `https://joguepalpitesdodia.web.app` como Site URL e adicione `https://joguepalpitesdodia.web.app/**` à lista de redirects. O domínio antigo pode permanecer na lista durante a transição.
4. Em **Authentication > Providers > Google**, copie a callback exibida pelo Supabase. No Google Auth Platform, o cliente Web existente pode receber `https://joguepalpitesdodia.web.app` nas origens e a callback do Supabase nos redirects. Gere um segredo separado, mantendo o antigo para o Firebase, e salve o novo somente no provider Google do Supabase.
5. Em **Project Settings > API**, copie a Project URL e a chave publishable. Crie `.env` a partir de `.env.example`.
6. Importe os usuários antigos antes de liberar o novo build. A ligação é feita pelo e-mail: no primeiro login Google, o registro importado recebe o novo ID de autenticação e mantém nome, número, XP, greens, avatar, sequências e histórico.
7. Valide login, criação/recuperação de perfil, palpite, ranking, perfil público e administração.
8. Rode `npm run deploy`. O comando só publica o Hosting e bloqueia o deploy quando as variáveis Supabase não estão configuradas.

## Limites do plano gratuito

O app evita Realtime, carrega o top 10 e consolida o resultado no banco. Para continuar gratuito, acompanhe no painel do Supabase o tamanho do banco e a saída de dados. Temporadas antigas devem ser arquivadas quando o banco se aproximar do limite gratuito.

## Chaves e proteção contra abuso

- A chave publishable existe no JavaScript do navegador por definição. Ela identifica o projeto, mas não libera dados: RLS, grants e o JWT do usuário decidem o acesso.
- Nunca use `sb_secret_...`, `service_role` ou senha do banco no Vite, no navegador ou no Git. Este projeto não precisa dessas chaves para funcionar.
- `.env*`, certificados e chaves privadas estão bloqueados no `.gitignore`; somente o exemplo sem credenciais pode ser versionado.
- Em **Authentication > Rate Limits**, mantenha os limites do Supabase ativos. A plataforma já limita endpoints de autenticação.
- Se cadastros por senha ou OTP forem adicionados no futuro, ative Cloudflare Turnstile em **Authentication > Bot and Abuse Protection** antes de publicar.

## Volta segura

A migração foi publicada no Firebase Hosting após validar login Google, perfil importado, palpite, ranking, perfil público e administração. Os arquivos antigos do Firestore foram removidos do código ativo. Os perfis ainda não vinculados são associados automaticamente por e-mail no primeiro login Google.

## Apostas Extras

Para liberar até três jogos por data no site existente, execute "supabase/migrations/005_extra_predictions.sql" no SQL Editor do projeto Supabase antes de publicar o novo build. A migração preserva os palpites anteriores como Aposta do Dia. Cada jogo recebe palpite e resultado próprios; as Extras concedem 5 XP pelo palpite e 25 XP pelo acerto, atualizam greens, reds e sequência de greens. Somente a Aposta do Dia atualiza a sequência diária.

## Desempate do ranking

Depois da migração 005, execute "supabase/migrations/006_ranking_xp_tiebreak.sql" no SQL Editor. Com o mesmo número de greens, o ranking usa o XP total acumulado (incluindo níveis anteriores); se o XP também empatar, usa o menor ID de jogador. Esta migração atualiza imediatamente as posições armazenadas.

## Ranking Global por pontos

Depois da migração 006, execute `supabase/migrations/007_rank_points.sql` no SQL Editor antes de publicar a interface nova. Todos os jogadores começam com 0 pontosRank. O proprietário define entre 1 e 1000 pontos para cada opção ao publicar um novo desafio; apenas o palpite vencedor recebe os pontos da sua opção. Apostas publicadas antes desta migração, mesmo que ainda estejam abertas, não concedem pontosRank. O ranking global mostra os dez maiores totais, desempatando pelo menor ID de jogador. Os graus são Bronze (0–99), Prata (100–199), Ouro (200–299), Platina (300–399), Diamante (400–499) e Mestre (500+). O torneio de greens e XP permanece separado.

Para mostrar a posição do próprio jogador abaixo do top 10 quando ele estiver fora dele, execute `supabase/migrations/008_my_global_rank.sql` antes de publicar a interface correspondente.

Para definir pontosRank nas apostas já publicadas que ainda estejam abertas, execute `supabase/migrations/009_open_prediction_rank_points.sql` no SQL Editor. O proprietário poderá informar os pontos de cada opção em **Administração > Últimos desafios > Definir pontosRank**. A edição deixa de ser permitida quando o prazo da aposta termina; os pontos são concedidos aos palpites vencedores ao confirmar o resultado.

Para corrigir a mensagem de limite de requisições do Supabase, execute `supabase/migrations/010_rate_limit_error.sql`. O limite continua por usuário, com resposta HTTP 429 válida e uma mensagem legível quando houver excesso de chamadas.

Para editar PontosRank de um jogador em **Administração > Editar perfil de jogador**, execute `supabase/migrations/011_admin_profile_rank_points.sql` no SQL Editor antes de publicar a interface correspondente. Somente o proprietário pode salvar essa alteração; o valor aceito vai de 0 a 1.000.000.

Para permitir até quatro Apostas Extras (cinco jogos no total) em cada data, execute `supabase/migrations/012_four_extra_predictions.sql` depois da migração 011. A Aposta do Dia continua sendo a única que altera a sequência diária; cada Extra mantém palpite, resultado, XP e PontosRank próprios.

Para ampliar a capacidade para nove Apostas Extras (dez apostas por data), aplique `supabase/migrations/021_nine_extra_predictions.sql` após as migrações anteriores. A função de publicação e os limites das tabelas passam a aceitar os slots de 0 a 9; a administração carrega até 310 apostas recentes.
