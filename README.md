# Main Menu Editor + Quick Panel (Psych Engine 1.0.4)

## Instalar
Copia las carpetas `source/` y `assets/` encima de las de tu proyecto (respeta rutas). Archivos:

- `source/backend/MainMenuData.hx` (nuevo)
- `source/states/MainMenuState.hx` (reemplaza el tuyo)
- `source/states/editors/MasterEditorMenu.hx` (reemplaza)
- `source/states/editors/MainMenuEditorState.hx` (nuevo)
- `source/objects/quickpanel/*.hx` (nuevos, 8 archivos)
- `assets/shared/images/quick-panel/` y `assets/shared/sounds/quick-panel/` (assets del panel)

## Activar el panel rápido en un mod
En `mods/<tu_mod>/pack.json`:

    { "name": "Mi Mod", "Custom menu": true }

(también vale `customMenu`). El editor tiene un checkbox "Custom menu" que lo escribe por ti al guardar (CTRL+S).
Abrir/cerrar el panel: TAB o clic en la pestaña del borde (en móvil, arrastrarla). ESC también lo cierra.

## Menú
Se guarda en `mods/<mod>/data/mainmenu.json` y lo lee `MainMenuState` al entrar.

## Ajustes
- Lado del panel: `new QuickPanelState(true)` en MainMenuState lo pone a la izquierda.
- Botones del panel: `buildButtonData()` en `QuickPanelGroup.hx`.
- Si la pestaña sale descentrada: `ATLAS_OFFSET_X/Y` en `QuickPanelPullTab.hx`.
- La acción `state` necesita que la clase tenga `@:keep` (por el DCE).

## Versión ampliada: editores Freeplay/Options y móvil

Esta versión añade:

- `source/backend/MenuScreenLayout.hx`: configuración separada por pantalla (`menu-layout-freeplay.json` y `menu-layout-options.json`).
- `source/states/editors/MenuScreenLayoutEditorState.hx`: editor táctil/teclado para los valores de posición, escala y separación.
- Dos entradas nuevas en `MasterEditorMenu`: **Freeplay Layout Editor** y **Options Layout Editor**.
- Ajustes de tamaño/espaciado de la lista y del panel del `MainMenuEditorState` para pantallas estrechas, además de botón táctil de regreso.

### Importante: conectar los valores a los estados

El editor guarda los perfiles, pero no cambia por sí solo la disposición de Freeplay/Options. Para aplicar los valores, integra `backend.MenuScreenLayout` en los estados originales.

**FreeplayState.hx**

1. Añade `import backend.MenuScreenLayout;` al bloque de imports.
2. Dentro de `create()`, después de crear `bg`, carga `var menuLayout = MenuScreenLayout.load('freeplay');` y aplica `bg.x += menuLayout.backgroundX; bg.y += menuLayout.backgroundY;` y, si necesitas escala, `bg.scale.set(menuLayout.backgroundScale, menuLayout.backgroundScale); bg.updateHitbox();`.
3. Al crear cada `songText`, aplica `songText.x += menuLayout.itemsX; songText.y += menuLayout.itemsY; songText.scale.set(menuLayout.itemScale, menuLayout.itemScale); songText.updateHitbox();`. Para ajustar la separación vertical, reemplaza el factor `1.3` de `updateTexts()` por `menuLayout.itemSpacing / 100` y conserva una referencia accesible al perfil como variable de clase.
4. Para `scoreText` y `diffText`, aplica los offsets `scoreX/scoreY` y `difficultyX/difficultyY` después de su posicionamiento normal.

**OptionsState.hx**

1. Añade `import backend.MenuScreenLayout;`.
2. En `create()`, carga `var menuLayout = MenuScreenLayout.load('options');` y aplica offsets/escala al fondo después de configurarlo.
3. En el bucle que crea cada `optionText`, aplica `optionText.x += menuLayout.itemsX; optionText.y += menuLayout.itemsY; optionText.scale.set(menuLayout.itemScale, menuLayout.itemScale); optionText.updateHitbox();` y usa `menuLayout.itemSpacing` en lugar del `92` fijo para el desplazamiento vertical.

La configuración se guarda en `mods/<mod>/data/menu-layout-freeplay.json` y `mods/<mod>/data/menu-layout-options.json` cuando la plataforma permite escritura (`sys`). El Quick Panel sigue siendo exclusivo de `MainMenuState`; el nuevo editor no lo crea ni lo abre.

### Instalación

Copia `source/` y `assets/` sobre el proyecto Psych Engine 1.0.4. Haz una copia de seguridad de los archivos que reemplaces. La integración final de los perfiles en Freeplay/Options requiere aplicar los pasos anteriores a los estados de tu fork; no reemplaces esos estados completos por archivos de otra versión.
