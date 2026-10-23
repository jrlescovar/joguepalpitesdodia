# Apoiador por 30 dias

Compra única de R$ 4,97 pela InfinitePay, sem renovação automática.
O botão envia kind=supporter, quantity=1 e requestId idempotente.
O servidor define o preço e confirma o pagamento com payment_check antes de
entregar 30 dias, 7 caixas de personalização e 1 caixa de fontes. Cada compra
entrega o benefício uma vez, mesmo com notificações repetidas.

Concessões gratuitas e prêmios da roleta continuam separados das compras.
Aplicar 20261012040000_supporter_one_time.sql somente depois de confirmar o fim
da renovação das assinaturas antigas. A migração preserva os dias já comprados,
remove o uso da integração anterior e mantém o histórico financeiro privado.
As migrações históricas não devem ser apagadas ou reescritas.

Remover as funções antigas pass-checkout, pass-portal, pass-pix, pass-webhook e
box-checkout em produção e as credenciais antigas depois do cancelamento.
Não existe portal de cobrança no novo fluxo.

Testes: infinitepayPayments.test.ts, infinitepayPayments.sql e supporterOneTime.sql.
Os testes de banco usam rollback e não criam pagamentos reais.
