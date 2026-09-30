# Pix com InfinitePay

A assinatura mensal de Apoiador continua na Stripe. Cada pacote de caixas tem
um único botão, com ícone e preço, que usa `infinitepay-checkout`.

Configuração do servidor: `INFINITEPAY_HANDLE=jrlescovar` nos secrets do projeto
Supabase. Na conta InfinitePay, habilitar Checkout Integrado e desativar a etapa
de endereço para produtos digitais. Não é necessária uma chave da conta no cliente.

O servidor reserva o pedido em `infinitepay_orders`, com jogador, produto e preço
definidos no servidor. Cada link inclui o endpoint `infinitepay-webhook` e o retorno
`?payment=infinitepay`. Não configurar o webhook manualmente para cada produto.

Webhook e retorno autenticado (`infinitepay-status`) consultam `payment_check`
diretamente na InfinitePay usando handle, pedido, transação e fatura. Dados de
valor, jogador e confirmação vindos do navegador/webhook não liberam itens.
`settle_infinitepay_order` entrega tudo numa transação, com bloqueio do pedido e
identificadores únicos para impedir duplicação ou reutilização de pagamento.

O checkout InfinitePay também oferece cartão. Uma compra avulsa já paga por esse
meio é entregue normalmente; ela não cria assinatura recorrente. A assinatura
mensal do site continua exclusivamente na Stripe.

Pedidos antigos de Apoiador por Pix continuam sendo confirmados, mas essa opção
não aparece mais na loja. Esses pedidos concedem 30 dias, 7 caixas normais, 1 caixa de fontes e 1 mês
na medalha de apoiador. O registro usa prefixo `ip_` na coluna legada
`pass_prepaid_payments.stripe_session_id`; seus triggers existentes concedem
caixas e contam o mês pago. Concessão gratuita do admin não entra nesse contador.

Verificação: `npm test -- tests/infinitepayPayments.test.ts tests/boxPayments.test.ts`,
`tests/infinitepayPayments.sql` (transação com rollback) e a página local
`/tests/fixtures/payments.html`. A fixture intercepta todas as chamadas de backend
e não cria pagamentos reais. `?result=pending` permite testar a espera limitada.
