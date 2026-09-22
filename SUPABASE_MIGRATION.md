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
3. Em **Authentication > URL Configuration**, use `https://jogueapostadodia.web.app` como Site URL e adicione `https://jogueapostadodia.web.app/**` à lista de redirects.
4. Em **Authentication > Providers > Google**, copie a callback exibida pelo Supabase. No Google Auth Platform, o cliente Web existente pode receber `https://jogueapostadodia.web.app` nas origens e a callback do Supabase nos redirects. Gere um segredo separado, mantendo o antigo para o Firebase, e salve o novo somente no provider Google do Supabase.
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
