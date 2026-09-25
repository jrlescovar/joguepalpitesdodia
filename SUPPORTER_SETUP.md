# Seja um Apoiador — ativação

Produto Stripe: `prod_VJujjcdjZSI8xv`. Preço mensal: `price_1UJKjJDK92yMyavYtGmnXKMu` (R$ 4,97). Não há período grátis. O checkout cobra ao assinar e a renovação é mensal.

O frontend e as Edge Functions foram publicados no projeto Supabase `kvvctmkxdvgdashxwpjb` e no Firebase. As migrações 013, 014 e 015 foram executadas. O Checkout real abre com R$ 4,97/mês, mas nenhuma compra foi concluída durante a validação. Para reproduzir a instalação:

1. Execute `supabase/migrations/013_supporter_subscription.sql`, `supabase/migrations/014_supporter_service_role_access.sql` e `supabase/migrations/015_admin_supporter_grants.sql` no SQL Editor. As migrações até 012 precisam estar aplicadas.
2. Configure os secrets `STRIPE_SECRET_KEY` (chave secreta do modo real) e `STRIPE_PRICE_ID=price_1UJKjJDK92yMyavYtGmnXKMu` em Edge Functions → Secrets. Nunca coloque a chave secreta em `VITE_*` ou no repositório.
3. Publique as funções `pass-checkout`, `pass-portal` e `pass-webhook` de `supabase/functions`. Mantenha a verificação JWT de plataforma em checkout e portal; essas funções também validam a sessão do jogador. Desative-a somente no webhook, que valida a assinatura Stripe.
4. Crie um webhook Stripe para `https://kvvctmkxdvgdashxwpjb.supabase.co/functions/v1/pass-webhook` com `checkout.session.completed`, `customer.subscription.created`, `customer.subscription.updated` e `customer.subscription.deleted`. Guarde o segredo de assinatura como `STRIPE_WEBHOOK_SECRET` no Supabase.
5. Ative o Customer Portal da Stripe para cartão e cancelamento. Antes de considerar a cobrança totalmente validada, teste o webhook após uma assinatura, renovação, cancelamento e falha de pagamento em ambiente de teste.
6. Publique o frontend no Firebase e confirme a compra com um usuário de teste controlado. O retorno da Stripe por si só não libera benefícios: somente o webhook assinado grava o estado `active` no banco.

Ganhos de XP com assinatura ativa são arredondados para cima individualmente: 5 → 8 e 25 → 38. PontosRank, greens e sequências mantêm as regras atuais. Após cancelamento, os benefícios continuam até o fim do período já pago; depois ficam indisponíveis.

O administrador pode conceder Premium gratuito por 1 a 3650 dias no perfil do jogador. A concessão fica em `pass_grants`, separada da cobrança Stripe, e pode ser revogada. `pass_active` aceita uma assinatura paga vigente ou uma concessão gratuita ainda válida. O prazo gratuito não renova automaticamente e não altera uma assinatura paga existente.

## Pix avulso de 30 dias

O fluxo de Pix está preparado, mas fica oculto até a conta Stripe ter Pix habilitado. Na conta brasileira atual, Pix não aparece nas formas de pagamento disponíveis; a documentação da Stripe indica disponibilidade por convite para contas brasileiras. Não configure `VITE_PIX_ENABLED=true` nem publique o botão antes da confirmação de elegibilidade e de um checkout de teste bem-sucedido.

Quando disponível: aplique `supabase/migrations/020_prepaid_pix.sql`, publique `pass-pix` e a versão atualizada de `pass-webhook`, adicione `checkout.session.async_payment_succeeded` ao webhook Stripe e configure `VITE_PIX_ENABLED=true` no build. O checkout cobra R$ 4,97 uma vez. O webhook verifica na Stripe o valor, moeda, método e estado pago antes de liberar 30 dias; o registro da sessão impede crédito duplicado. O Pix não renova automaticamente. Teste o pagamento confirmado e o vencimento antes de liberar em produção.
