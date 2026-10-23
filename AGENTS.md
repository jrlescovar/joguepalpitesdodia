# Instruções do projeto

## Código C

Nunca use `return;`, `return` em função recursiva, `continue` ou `while (1)` em C. `break` só pode estar dentro de `switch case`. Declare a struct como `structy` e depois o `typedef`, conforme a instrução do usuário.

## Graphify local

- O mapa deste projeto fica em `graphify-out/graph.json`. Para perguntas sobre arquitetura e relações entre arquivos, comece por uma consulta focada quando o mapa existir:
  `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/graphify.ps1 query "WheelPanel" --budget 1200`
- Use `path "WheelPanel" "WheelRewardModal"` para relações e `explain "WeeklyArena"` para um símbolo. Nomes ambíguos precisam ser qualificados com o identificador retornado pela ferramenta.
- O executável está no ambiente local `.runtime/graphify-venv`; use o script acima, sem instalar pacotes globalmente nem configurar hooks para isso.
- O fluxo padrão é somente AST local (`GRAPHIFY_BACKEND=none`, `--code-only`). Não envie documentos ou código para um provedor LLM sem solicitação explícita.
- O grafo é um índice de navegação. Confirme as linhas no código antes de editar; migrações históricas não representam necessariamente o estado atual do banco. Consultas sem resultados ou informações incompletas permitem pesquisar diretamente nas fontes.
- Após alterações relevantes no código, atualize com `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/graphify.ps1 refresh`.
- `graphify-out/` e o ambiente local são ignorados pelo Git. Não publique o mapa no site. Instruções e reinstalação: `docs/graphify.md`.
