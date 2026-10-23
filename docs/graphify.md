# Graphify neste projeto

Instalação local do Graphify 0.9.92, pacote oficial `graphifyy[sql]`, dentro de `.runtime/graphify-venv`. A integração de skill está em `.agents/skills/graphify/` e será descoberta no próximo turno do Codex.

## Uso no PowerShell

```powershell
# Atualizar o índice, relatório e mapa interativo
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/graphify.ps1 refresh

# Consultar um componente com saída limitada
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/graphify.ps1 query "WheelPanel" --budget 1200

# Seguir uma relação concreta
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/graphify.ps1 path "WheelPanel" "WheelRewardModal"

# Explorar a Liga da Semana
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/graphify.ps1 explain "WeeklyArena"
```

Abra `graphify-out/graph.html` para o mapa visual. `graphify-out/GRAPH_REPORT.md` traz a visão geral e `graphify-out/graph.json` guarda os dados consultáveis. A visualização HTML usa bibliotecas carregadas por CDN e pode precisar de conexão para abrir; a análise e as consultas de código são locais.

O script desativa backends LLM e o log global de consultas durante a execução. A atualização usa somente análise estática de código, sem chave de API, sem transcrição e sem extração semântica de documentos. A `.graphifyignore` e a `.gitignore` excluem ambiente local, segredos, dependências, mídia e arquivos gerados.

## Limites

O mapa contém relações extraídas do código; não garante que toda chamada dinâmica, CSS, migração de dados ou regra executada no banco esteja representada. SQL histórico pode ter várias definições de uma mesma função. Para confirmar uma regra em produção, consulte a função atual do banco. Nós externos e relações inferidas precisam ser verificados nas fontes. Economia de tokens depende da tarefa; não há percentual garantido para este projeto.

## Reinstalar o ambiente local

```powershell
python -m venv .runtime/graphify-venv
.runtime/graphify-venv/Scripts/python.exe -m pip install 'graphifyy[sql]==0.9.92'
.runtime/graphify-venv/Scripts/graphify.exe install --project --platform agents
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/graphify.ps1 refresh
```

Não foram instalados hooks de Git, serviços de fundo ou configurações globais do Codex. O mapa é uma ferramenta de desenvolvimento e fica fora do build publicado.

Fonte oficial: https://github.com/Graphify-Labs/graphify
