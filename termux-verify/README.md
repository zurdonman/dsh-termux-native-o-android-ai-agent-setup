# Verificar dsh en tu móvil (Termux)

Este kit instala el proyecto con el instalador de `lilyco-42/dsh-termux` y comprueba en tu propio Android que funciona: instalación, arranque de `dsh web`, módulos nativos (`node-pty`, `koffi`, `sharp`) y ripgrep (`glob`/`grep`).

## Antes de empezar

- Termux instalado desde **F-Droid** (no Play Store).
- Android 11 o superior.
- Conexión a internet estable y unos 2 GB libres.

## Ejecutar

En Termux:

```bash
pkg install -y git
git clone https://github.com/zurdonman/dsh-termux-native-o-android-ai-agent-setup.git
cd dsh-termux-native-o-android-ai-agent-setup
bash termux-verify/verify.sh
```

Tarda bastante (compilación de módulos nativos). No cierres Termux mientras corre.

No necesitas una API key real para esta prueba. Si no defines `DEEPSEEK_API_KEY`, el script usa una de prueba.

## Qué enviar de vuelta

- `~/dsh-verify/report.txt` (resumen PASS/FAIL, corto).
- `~/dsh-verify/full.log` si algo falla (log completo, con tokens y claves redactados).

Puedes copiar el contenido con `cat ~/dsh-verify/report.txt` y pegarlo aquí.

## Probar otra versión del instalador

```bash
INSTALLER_REPO=owner/repo INSTALLER_REF=main bash termux-verify/verify.sh
```
