# Sesión de depuración: `dsh web debug`

Arranca `dsh web` detrás de un proxy que registra cada petición y cada mensaje que hace la interfaz del navegador, y guarda el resultado en la carpeta **Descargas** del móvil.

## Activar el comando (una vez)

```bash
termux-setup-storage
cd ~/dsh-termux-native-o-android-ai-agent-setup && git pull
bash termux-debug/dsh-web-debug.sh --install-alias
```

Luego abre una sesión nueva de Termux (o ejecuta `source ~/.bashrc`). `dsh web` normal no cambia.

## Uso

```bash
dsh web debug
```

1. Abre la URL que muestra (`http://127.0.0.1:3080/?token=...`) en el navegador del móvil.
2. Reproduce el problema: pulsa los botones, escribe, habla con el modelo.
3. Pulsa **Ctrl+C** en Termux.
4. Abre **Descargas > dsh-log > session-…** y comparte los `.txt` en el chat.

## Qué se registra

| Fichero | Contenido |
|---|---|
| `events.log` | Una línea por cada petición HTTP de la interfaz (método, ruta, estado, tiempo, cuerpo si es JSON o texto) y por cada mensaje del WebSocket (`/api/remote.mux`), en ambos sentidos. |
| `terminal.txt` | Todo lo que imprime `dsh web`. |
| `report.txt` | Versiones (Android, Node, dsh, ripgrep), nombres y tamaños de los ficheros de `~/.dsh` y `~/.codex`, logs de arranque y estado del plugin de ChatGPT. |

Claves, tokens, JWT y correos se sustituyen por `REDACTED` antes de guardar nada.

## Qué NO se registra

- Interacciones que no hablan con el servidor (scroll, abrir y cerrar menús, escribir sin enviar). Solo queda registro cuando la interfaz llama al servidor.
- Errores de JavaScript del navegador. Para verlos haría falta un cambio en la propia interfaz.
- El contenido de `~/.codex/auth.json` ni de otros ficheros de credenciales.
- Nada se sube a internet. Los ficheros se quedan en el móvil.

## Notas

- Con la sesión activa, dsh escucha en el puerto interno **3180**. El proxy usa el **3080**, así que solo abre la URL del puerto 3080. El modelo puede citar el puerto 3180 en sus mensajes; no es un error.
- Revisa los `.txt` antes de compartirlos. La redacción cubre los patrones habituales, pero no lo garantiza al 100 %.
