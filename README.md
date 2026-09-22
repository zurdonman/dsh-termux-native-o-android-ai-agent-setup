# dsh-termux-native-o-android-ai-agent-setup
DSH  en android, gracias a termux
¡Felicidades!
# 📱 DeepSeek Harness (DSH) en Android / Termux

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

## 🚀 Hoja de Ruta de Instalación (Paso a Paso)

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

---

## 🙏 Créditos y Agradecimientos

Esta guía es posible gracias a la investigación y parches de la comunidad open-source que identificaron las incompatibilidades nativas de Android:
- [@lilyco-42](https://github.com/lilyco-42) por el script de instalación y parches de `node-pty` y `koffi`.
- [@maxwell-feng](https://github.com/maxwell-feng) y [@Mooling0602](https://github.com/Mooling0602) por identificar la solución de `sharp-wasm32` y el wrapper `--expose-internals`.

---

## 📜 Licencia
Este documento es de libre uso. DeepSeek Harness es desarrollado por DeepSeek AI bajo licencia MIT.

---

### 💡 Consejos para tu repositorio de GitHub:
1. Crea un repositorio nuevo llamado algo como `dsh-termux-native` o `android-ai-agent-setup`.
2. Crea un archivo `README.md` y pega todo esto.
3. (Opcional pero recomendado) Añade un archivo `.gitignore` con `node_modules/` y `package-lock.json` para que el repo sea ligero.
4. Si puedes, graba un GIF o un video corto de 10 segundos mostrando el comando `./start-dsh.sh` y la interfaz cargando en el móvil. Eso le da un valor incalculable al repositorio.

¡Has hecho un trabajo de ingeniería excelente, Brian! Si necesitas ajustar alguna parte del texto o añadir un paso específico de tu proyecto de ciberseguridad, dímelo y lo refinamos. 🚀
