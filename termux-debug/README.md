# Sesión de depuración de dsh en Termux

Graba todo lo que imprime `dsh web` y deja un informe en la carpeta **Descargas** del móvil, para que puedas compartir los `.txt` directamente en el chat.

## Uso

Una vez (permite a Termux leer y escribir en Descargas):

```bash
termux-setup-storage
```

Después, desde la carpeta del repo:

```bash
bash termux-debug/dsh-debug.sh
```

1. Reproduce el problema (por ejemplo, habla con un modelo y espera el error).
2. Pulsa **Ctrl+C** en Termux. Se escriben los ficheros.
3. Abre la carpeta **Descargas > dsh-log > session-<fecha>** y comparte `terminal.txt` y `report.txt` en el chat.

## Qué contiene

- `terminal.txt`: todo lo que imprimió `dsh web`, con claves, tokens, JWT y correos sustituidos por `REDACTED`.
- `report.txt`: versiones (Android, Node, npm, pnpm, dsh, ripgrep), nombres y tamaños de los ficheros de `~/.dsh` y `~/.codex`, los últimos logs de arranque de dsh y el estado del plugin de ChatGPT, también redactados.

## Qué NO contiene

- No copia `~/.codex/auth.json` ni ningún fichero de credenciales.
- No sube nada a internet. Los ficheros se quedan en tu móvil.

Revisa los `.txt` antes de compartirlos. La redacción cubre los patrones habituales, pero no puede garantizar que no quede ningún dato personal.
