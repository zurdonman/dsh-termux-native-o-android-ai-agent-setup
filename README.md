# dsh-termux-native-o-android-ai-agent-setup
DSH  en android, gracias a termux
¡Felicidades!
# 📱 DeepSeek Harness (DSH) en Android / Termux

**Instalar DeepSeek Harness (DSH) en Android con Termux, sin proot ni PC.** Guía y script de instalación para ejecutar `dsh web` en un móvil Android (arm64), con los parches necesarios para `flock`, `rename`, ripgrep y el login del plugin de ChatGPT, y un modo debug que genera un log para compartir.

> *English summary:* install DeepSeek Harness (dsh) natively on Android with Termux (no proot, no PC). One-command installer, Android fixes (`flock is not supported on android-arm64`, `rename is not defined`, ripgrep), ChatGPT subscription plugin sign-in fix, and a debug mode that writes shareable logs.


Guía definitiva para ejecutar **DeepSeek Harness** (el framework de agentes de IA de DeepSeek) de forma **nativa** en dispositivos Android a través de Termux, sin contenedores `proot` y con acceso completo al sistema de archivos local.

> **⚠️ ADVERTENCIA CRÍTICA:** No instales Termux desde la Google Play Store (está desactualizado y falla). Descárgalo exclusivamente desde [F-Droid](https://f-droid.org/packages/com.termux/).

---

## 🎯 ¿Qué logra esta guía?
- ✅ Ejecuta la interfaz Web UI de DSH nativamente en `android-arm64`.
- ✅ Soluciona el error de compilación de `sharp` (procesamiento de imágenes).
- ✅ Soluciona el error fatal del plugin HMR (`--expose-internals`).
- ✅ Permite conectar **cualquier API Custom** (OpenAI compatible, Ollama, DeepSeek, etc.).
- ✅ El agente puede leer, escribir y ejecutar archivos directamente en tu almacenamiento Android (`/storage/emulated/0/`).

---

## ⚡ Instalación rápida en Termux (un comando)

Requisitos: Termux instalado desde **F-Droid**, Android 11 o superior, unos 2 GB libres y una API key de DeepSeek.

En Termux, ejecuta estos comandos uno a uno:

```bash
pkg install -y git
git clone https://github.com/zurdonman/dsh-termux-native-o-android-ai-agent-setup.git
cd dsh-termux-native-o-android-ai-agent-setup
bash install-termux.sh
```

El script instala todo: paquetes, `@deepseek-ai/dsh` (con el instalador de [lilyco-42/dsh-termux](https://github.com/lilyco-42/dsh-termux), fijado a un commit), `pnpm` para los plugins, y las correcciones de Android de `termux-verify/`:

- `fix-require-builtin.sh`: sin esto, `dsh web` no arranca (`No usable native binding found for node-addon-require-builtin-android-arm64`).
- `fix-ripgrep.sh`: sin esto, las herramientas `glob` y `grep` fallan.

Tarda bastante, porque compila módulos nativos. Pide tu API key en mitad del proceso; la escribes sin que se vea. No lo ejecutes con un pipe (`curl ... | bash`), porque el instalador necesita el teclado. Al final, arranca la interfaz con:

```bash
dsh web
```

Es seguro volver a ejecutar `bash install-termux.sh`: cada paso salta lo que ya está hecho. Si algo falla, el script indica qué comprobar y deja el resultado en `~/dsh-install/checks.txt`.

> **Probado:** en un móvil real (Android 15, arm64) `dsh web` arranca, la interfaz carga y se instaló un plugin, con `pnpm` añadido a mano. El script completo aún no se ha ejecutado de principio a fin en un móvil limpio.

---

## 🚀 Hoja de Ruta de Instalación (Paso a Paso, manual)

Esta es la guía manual original. El comando de arriba hace lo mismo y además aplica las correcciones de Android.

Sigue estos pasos en orden dentro de tu terminal de Termux.

### Paso 1: Permisos y Actualización
Concede a Termux acceso a tus carpetas de Android y actualiza los paquetes base.
```bash
termux-setup-storage
pkg update && pkg upgrade -y
pkg install nodejs npm -y
```

### Paso 2: Crear entorno de trabajo local
Evitamos `npx` global para tener control total sobre las dependencias y aplicar parches locales.
```bash
mkdir ~/dsh-agent && cd ~/dsh-agent
npm init -y
```

### Paso 3: Instalación de DSH y parche de `sharp`
Instalamos DSH y forzamos el uso de la versión WebAssembly de `sharp`, ya que no existen binarios nativos precompilados para `android-arm64`.
```bash
npm install @deepseek-ai/dsh @img/sharp-wasm32
```

### Paso 4: Crear el script de lanzamiento (La solución al error HMR)
El wrapper por defecto de npm no pasa la bandera `--expose-internals` requerida por el plugin de Hot Module Replacement (HMR) de Node.js en Android. Creamos un script personalizado para solucionarlo.

Copia y pega este bloque completo en tu terminal:
```bash
cat > start-dsh.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/sh
echo "🚀 Iniciando DeepSeek Harness (Modo Nativo Android)..."
node --expose-internals ./node_modules/@deepseek-ai/dsh/lib/bin.js web
EOF
```

Dale permisos de ejecución al script:
```bash
chmod +x start-dsh.sh
```

### Paso 5: ¡Ejecutar el Agente!
Inicia el servidor web usando tu nuevo script:
```bash
./start-dsh.sh
```
Deberías ver una salida similar a: `dsh web: http://127.0.0.1:3080/?token=...`

---

## 🌐 Acceso y Configuración

1. Abre tu navegador web en el móvil (Chrome, Firefox, etc.).
2. Ve a la dirección que te mostró la terminal (ej: `http://127.0.0.1:3080`).
3. Introduce el token si te lo solicita.

### ⚙️ Configurar tu API Custom
DSH es agnóstico al modelo. Para usar tu propia API (Ollama local, OpenRouter, DeepSeek, etc.):
1. En la interfaz web, ve a **Settings** (Configuración).
2. Busca la sección de **Model Provider** o **LLM**.
3. Selecciona **OpenAI Compatible** o **Custom**.
4. Rellena los campos:
   - **Base URL:** `https://tu-endpoint-personalizado.com/v1`
   - **API Key:** `tu-clave-secreta` (o `sk-fake` si es local)
   - **Model ID:** `nombre-exacto-de-tu-modelo` (ej: `deepseek-coder`, `llama3`)

---

## 💡 Uso Práctico (Ejemplo)

Una vez configurado, puedes darle órdenes como esta en el chat del agente:

> *"Crea un archivo llamado `analisis.py` en la carpeta `/storage/emulated/0/Download/`. El script debe usar la librería `requests` para obtener el HTML de 'https://example.com', buscar la palabra 'security' y guardar el resultado en `reporte.txt`. Instala `requests` si es necesario y ejecuta el script."*

El agente escribirá el código, lo ejecutará en la terminal integrada y te mostrará el resultado, todo en tu dispositivo.

---

## 🛠️ Solución de Problemas (Troubleshooting)

| Problema | Solución |
| :--- | :--- |
| `Could not load the "sharp" module` | Asegúrate de haber ejecutado `npm install @img/sharp-wasm32` en el Paso 3. |
| `--expose-internals is required for HMR` | Estás usando `npx dsh web`. Usa **siempre** `./start-dsh.sh` como se indica en el Paso 4. |
| `EACCES: permission denied` al guardar archivos | Olvidaste ejecutar `termux-setup-storage` en el Paso 1. Reinicia Termux y ejecútalo. |
| La interfaz web no carga | Verifica que la URL sea `127.0.0.1` y no `localhost` (a veces Android resuelve mal localhost). |
| `Could not find @vscode/ripgrep-android-arm64` o fallan `glob` / `grep` del agente | `@vscode/ripgrep` no tiene binario para Android. Aplica la **corrección de ripgrep** de la sección siguiente. |
| `gyp ERR!`, `make: not found`, `clang: not found` al instalar | Faltan herramientas de compilación para `node-pty`. Ejecuta `pkg install -y clang make python cmake binutils pkg-config` y reinstala. |
| `dsh web` se cierra al arrancar | Comprueba la versión de Node con `node -v`. Los proyectos de la comunidad indican **22.19+** o **24+**. Si es más antigua, ejecuta `pkg install nodejs-lts`. |
| `flock is not supported on android-arm64` al abrir una sesión | Ejecuta `bash termux-verify/fix-flock.sh` (ya incluido en `install-termux.sh`). |
| `rename is not defined` al crear o guardar una sesión | Ejecuta `bash termux-verify/fix-rename-import.sh` (ya incluido en `install-termux.sh`). |
| Login de ChatGPT: vuelve a pedir iniciar sesión, o aparece `oauth.write-failed` / «no se pudo guardar localmente» | Ejecuta `bash termux-verify/fix-chatgpt-codex-dir.sh` y vuelve a iniciar sesión. Crea `~/.codex`, que el plugin necesita. |
| Error `403 AUTH` o «API key is invalid» con un proveedor compatible con OpenAI (p. ej. b.ai) | Revisa la base URL del proveedor: debe terminar en `/v1`. |

---

## 🐞 Modo debug: log para compartir

Si algo falla, el modo debug registra la sesión (peticiones HTTP, WebSocket, acciones de la interfaz y errores del turno) en una carpeta que puedes compartir sin login:

```bash
cd ~/dsh-termux-native-o-android-ai-agent-setup
bash termux-debug/dsh-web-debug.sh --install
dsh-debug
```

- Los logs se guardan en `/storage/emulated/0/Download/dsh-log/session-<fecha>/`: `events.log`, `terminal.txt` y `report.txt`.
- Si Download no es escribible, el log queda en `~/dsh-log/` y el script avisa.
- Las claves, tokens y correos se redactan. Revisa el log antes de compartirlo.
- Guía completa: [`termux-debug/README.md`](termux-debug/README.md).

## 🔐 Login de ChatGPT (plugin ChatGPT Subscription)

El plugin es [songoao25/dsh-chatgpt-sub](https://github.com/songoao25/dsh-chatgpt-sub). En Termux necesita `~/.codex`, que el plugin no crea. Sin ella, el login se completa en OpenAI pero no se guarda. Solución:

```bash
bash termux-verify/fix-chatgpt-codex-dir.sh
```

Después pulsa «Sign in with ChatGPT» otra vez. Este paso ya está incluido en `install-termux.sh`. Issue reportado al autor: [songoao25/dsh-chatgpt-sub#55](https://github.com/songoao25/dsh-chatgpt-sub/issues/55).

---

## 🔁 Si no funciona: diagnóstico y alternativas de la comunidad

Esta guía fija `@deepseek-ai/dsh` sin versión. Al comprobarlo, se ven estos puntos:

- **Verificado en Linux (sandbox x64, Node 22.22.3):** `npm install @deepseek-ai/dsh@0.2.0-rc.2` instala bien, `dsh --version` devuelve `0.2.0-rc.2` y `dsh web` imprime `http://127.0.0.1:3080/?token=...`. Por tanto, el fallo es específico de **Android/Termux**, no del comando de arranque.
- **`@vscode/ripgrep` (usado por las herramientas `glob`/`grep`)** busca el paquete `@vscode/ripgrep-<platform>-<arch>`. En Termux la plataforma es `android`, que no existe en npm, así que el módulo lanza error. Esto no está cubierto por la guía original.
- **`node-pty`** no trae binario precompilado para Android y se compila con `node-gyp` en el propio móvil. Necesita clang, make y python.
- **`koffi`** también depende de binarios por plataforma, y no hay build `android-arm64` oficial.

### Corrección de ripgrep (verificada en simulación)

Instala el `rg` nativo de Termux y crea un paquete *shim* que lo expone con el nombre que espera `@vscode/ripgrep`:

```bash
pkg install -y ripgrep
cd ~/dsh-agent
D=node_modules/@vscode/ripgrep-android-arm64/bin
mkdir -p "$D"
echo '{"name":"@vscode/ripgrep-android-arm64","version":"1.18.0","main":"bin/rg"}' > node_modules/@vscode/ripgrep-android-arm64/package.json
printf '#!/data/data/com.termux/files/usr/bin/sh\nexec rg "$@"\n' > "$D/rg"
chmod +x "$D/rg"
```

Hay que repetir este paso tras cada `npm install` o actualización de dsh. La prueba se hizo simulando `process.platform = "android"` con `npm_config_arch=arm64` en Linux: el módulo resuelve el shim y `rg --version` responde. **Todavía no se ha probado en un móvil real.**

### Proyectos de la comunidad (GitHub)

| Proyecto | Qué ofrece | Notas |
| :--- | :--- | :--- |
| [Vengisk/deepseek-harness-termux](https://github.com/Vengisk/deepseek-harness-termux) | Parches automáticos sobre el paquete npm, instalador `install.sh`, compilación de `node-pty`/`koffi` en el dispositivo, shim de ripgrep y paquete precompilado `dsh-termux-full.tgz`. | Es el más completo en la documentación de problemas. Requiere Node ≥ 24. Sus parches están probados contra versiones 0.1.x. |
| [Yuifeng2016/deepseek-harness-termux](https://github.com/Yuifeng2016/deepseek-harness-termux) (fork de mermergi) | 18 parches idempotentes (`android-fix.mjs`), shim de ripgrep, app Android opcional con instalador. | Indica probar con **0.1.7-rc.2**: sin los parches 10, 11 y 18 no arranca. |
| [tkosub/dsh-termux-core](https://github.com/tkosub/dsh-termux-core) | Instalador `provision.sh` que aplica las correcciones y comprueba bloqueo de archivos, creación, imágenes y búsqueda. | Probado con **0.1.5-rc.1** y Android 11+. |
| [ARSADM7/termux-deepseek-harness](https://github.com/ARSADM7/termux-deepseek-harness) | Instalador de un comando con compilación nativa y configuración automática. | Probado en Android 16 / aarch64. Indica Android 11+. |
| [lilyco-42/dsh-termux](https://github.com/lilyco-42/dsh-termux) | `install.sh` que instala `@deepseek-ai/dsh` (sin versión fija) y aplica 7 parches: node-gyp, koffi (`android30`), sharp con libvips, shebang `--expose-internals`, y tres parches de publicación de archivos (`link()` → `rename()`) en sesiones, adjuntos y `fs-local`. | Comprobado en este entorno: los tres parches JS se aplican sin error sobre 0.2.0-rc.2 y el código resultante es sintácticamente válido. **No gestiona ripgrep**, así que `glob`/`grep` pueden seguir fallando. Requiere Android 11+. No tiene pruebas en dispositivo. |

**Importante:** los proyectos anteriores están pensados para versiones 0.1.x. La versión actual en npm es **0.2.0-rc.2**. Si quieres usar uno de ellos, instala la versión que indique su README (por ejemplo, `npm install @deepseek-ai/dsh@0.1.7-rc.2`) en lugar de `latest`.

### Ruta recomendada

1. Haz la instalación limpia con `pkg` y Node 22.19+ o 24+.
2. Si solo falla la búsqueda (`glob`/`grep`), aplica la corrección de ripgrep de esta sección.
3. Si falla la compilación nativa, prueba `install.sh` de **Vengisk/deepseek-harness-termux** y consulta su documentación.
4. Si tienes un error distinto, copia el mensaje completo que aparece en Termux al ejecutar `./start-dsh.sh` y abre un *issue* en este repositorio.

---

## 🙏 Créditos y Agradecimientos

Esta guía es posible gracias a la investigación y parches de la comunidad open-source que identificaron las incompatibilidades nativas de Android:
- [@lilyco-42](https://github.com/lilyco-42) por el script de instalación y parches de `node-pty` y `koffi`.
- [@maxwell-feng](https://github.com/maxwell-feng) y [@Mooling0602](https://github.com/Mooling0602) por identificar la solución de `sharp-wasm32` y el wrapper `--expose-internals`.

---

## 📜 Licencia
Este documento es de libre uso. DeepSeek Harness es desarrollado por DeepSeek AI bajo licencia MIT.

---

## 🏷️ Palabras clave

DeepSeek Harness, DSH, DeepSeek en Android, DeepSeek Termux, Termux Android AI agent, instalar dsh en Android, `dsh web` Termux, agente de IA en el móvil sin PC, Node.js en Android, `android-arm64`, `flock is not supported`, `rename is not defined`, `node-pty` Termux, ripgrep Termux, ChatGPT subscription plugin Termux, `oauth.write-failed`, debug de agentes en Android.
