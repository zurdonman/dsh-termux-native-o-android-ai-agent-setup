# Publicar esta versión en `main`

`main` tiene la versión antigua del README. La versión que funciona está en la rama
`arena/071a9cd5-dsh-termux-native-o-android-ai`. Como `main` no tiene commits que no estén en esa rama,
basta un **fast-forward**: `main` pasa a apuntar al mismo commit, sin perder contenido y sin `--force`.

## Comprobación previa (en Termux o en el PC)

```bash
cd ~/dsh-termux-native-o-android-ai-agent-setup
git fetch origin
git merge-base --is-ancestor origin/main origin/arena/071a9cd5-dsh-termux-native-o-android-ai && echo "OK: fast-forward posible"
```

Si imprime `OK`, sigue. Si no, **no publiques**: `main` tiene commits que no están en la rama, y hay que decidirlo antes.

## Publicar

```bash
git push origin origin/arena/071a9cd5-dsh-termux-native-o-android-ai:refs/heads/main
```

Sin `--force`. Si GitHub lo rechaza (protección de rama), usa la vía por Pull Request:

```bash
gh pr create --base main --head arena/071a9cd5-dsh-termux-native-o-android-ai --title "Publicar versión funcional de DSH en Termux" --body "Sustituye el README y los scripts de instalación de main por la versión verificada en Android."
gh pr merge <número> --merge
```

Sustituye `<número>` por el número que devuelve `gh pr create`. También puedes hacerlo en la web de GitHub: *Compare & pull request* → *Create pull request* → *Merge pull request*.

## Comandos para instalar desde `main` (para cualquiera)

En Termux, uno por línea:

```bash
pkg install -y git
git clone https://github.com/zurdonman/dsh-termux-native-o-android-ai-agent-setup.git
cd dsh-termux-native-o-android-ai-agent-setup
bash install-termux.sh
```

Después, para arrancar la interfaz: `dsh web`. Para depurar y generar un log: `bash termux-debug/dsh-web-debug.sh --install` y luego `dsh-debug`.

## Instrucción para el agente de DSH

Pégala tal cual en el chat de DSH. Solo sirve si el Termux del móvil tiene permiso para hacer `git push` a GitHub; si no, usa la vía por Pull Request de arriba.

```
Necesito que publiques en la rama main de mi repositorio zurdonman/dsh-termux-native-o-android-ai-agent-setup
el contenido de la rama arena/071a9cd5-dsh-termux-native-o-android-ai, sin cambiar nada más.

1. cd ~/dsh-termux-native-o-android-ai-agent-setup
2. git fetch origin
3. Comprueba que main es antecesor de la rama:
   git merge-base --is-ancestor origin/main origin/arena/071a9cd5-dsh-termux-native-o-android-ai && echo OK
   Si no imprime OK, para y dime qué commits tiene main que no están en la rama. No hagas nada más.
4. Si imprime OK, publica con un push normal (sin --force):
   git push origin origin/arena/071a9cd5-dsh-termux-native-o-android-ai:refs/heads/main
5. Si el push falla por permisos o autenticación, no intentes iniciar sesión ni pidas tokens.
   Dime que hace falta reconectar GitHub, o que use la vía por Pull Request.
6. Al terminar, comprueba con git ls-remote origin refs/heads/main que main apunta al mismo commit que la rama,
   y dime el hash.

No borres ramas, no hagas force push, no toques ningún otro archivo ni ~/.codex ni ~/.dsh.
```
