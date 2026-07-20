# agentmemory-portable — kit USB (vive dentro il repo agentmemory)

Avvia agentmemory da pen drive / cartella locale **senza patchare** i sorgenti
upstream. Questa cartella fa parte del progetto e si puo pushare su git.

## Posizione

```
agentmemory/
  agentmemory-portable/     <-- questo kit
  src/ ...
  package.json
```

In layout **in-tree** (default qui) il codice e la cartella padre del kit:
non serve un secondo clone in `repo\`.

## Layout

```
agentmemory-portable\
  setup.cmd / start.cmd / start-clean.cmd / stop.cmd / status.cmd / update.cmd
  mcp-launch.cmd
  mcp-cursor.example.json
  kit.config.ps1
  iii-config.yaml          # SQLite -> .\data (cwd = kit root)
  data\                    # state_store.db + stream_store (DATI)
  scripts\
  portable\node\           # Node portatile (non in git)
  portable\iii.exe         # backup (non in git)
  home\.agentmemory\       # .env, pid, preferences (runtime, non in git)
  home\cache\
  downloads\               # zip temporanei (non in git)
```

## Prerequisiti

- Windows 10/11 x64
- `git` sul PATH (setup/update)
- Porte libere: **3111**, **3112**, **3113**, **49134**
- USB 3.x consigliata se usi una pen drive

## Prima installazione

1. Dal clone del progetto: entra in `agentmemory-portable\`
2. Doppio-click **`setup.cmd`** (serve rete: Node + iii.exe + npm install/build)
3. Avvia con **`start.cmd`**

Su pen drive: copia l'intero repo `agentmemory` (o almeno questa cartella + build),
poi `setup.cmd` / `start.cmd`.

## Uso quotidiano

| Comando | Effetto |
|--------|---------|
| `start.cmd` | Remappa home su `home\`, avvia daemon (dati in `data\`). Se trova Docker chiede A/B/C |
| `start-clean.cmd` | Opzione C automatica: ferma Docker agentmemory, ripulisce pid, avvia USB |
| `stop.cmd` | Ferma worker + iii-engine |
| `status.cmd` | `agentmemory status` |
| `update.cmd` | `git pull` sul repo padre + `npm install` + build |

## Dati sulla pen drive / kit

| Dato | Dove |
|------|------|
| SQLite + stream | `agentmemory-portable\data\` |
| Config / pid / snapshot / export | `home\.agentmemory\` |
| Cache embedding | `home\cache\` |
| Codice | repo padre (`..`) |

## Docker in conflitto

`start.cmd` offre:
- **A** istruzioni manuali
- **B** resta su Docker
- **C** pulizia auto (stop container, no delete volumi) + avvio kit

## MCP Cursor

Vedi `mcp-cursor.example.json`. Con daemon avviato:

```json
"agentmemory": {
  "command": "npx",
  "args": ["-y", "@agentmemory/mcp"],
  "env": { "AGENTMEMORY_URL": "http://127.0.0.1:3111" }
}
```

## Cosa viene committato

Si pushano script, `iii-config.yaml`, `*.cmd`, README, esempi MCP.

**Non** finiscono in git (vedi `.gitignore`): `portable/node`, `downloads`,
`data/*`, `home/**` runtime, `.env`.
