# Pagamentos com InfinitePay

Moedas, Apoiador e inscrições em torneios usam a InfinitePay.
O Apoiador custa R$ 4,97 por 30 dias, sem renovação automática.

infinitepay-checkout valida sessão, origem, produto, preço e requestId.
infinitepay-webhook e infinitepay-status consultam payment_check antes de
executar settle_infinitepay_order. O retorno do navegador sozinho não entrega
benefícios. Webhook repetido não duplica dias, caixas ou medalha.

Apoiador: 30 dias, 7 caixas de personalização e 1 caixa de fontes por compra.
Pacotes de caixas antigos continuam reconhecidos para concluir pedidos já criados.
Os novos cartões de caixas usam o saldo de esmeraldas.

Referência: https://www.infinitepay.io/checkout-documentacao
Credencial: INFINITEPAY_HANDLE.

Testes: infinitepayPayments.test.ts, infinitepayPayments.sql e supporterOneTime.sql.
