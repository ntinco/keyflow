# Plan de evolución agresivo — keyflow

> Principio rector: **prefer deletion over compatibility layers**. Cada ciclo debe dejar el repo más pequeño, más legible y más fácil de mantener por una IA, no solo igual.
>
> Meta doble: (1) una IA nueva puede entender y modificar keyflow leyendo muy pocos archivos; (2) esos archivos de guía evolucionan junto al código —sin quedar obsoletos ni conservar historia que ya no sirve.

---

## Estado de partida (27 jun 2025)

- `health-check`: ✅ `ok: true`, 0 issues, 13 servicios, 0 candidatos muertos detectados.
- Superficie pública: estable pero con helpers UI dormidos y archivos de borde cuestionables.
- Frontera declarada: adelgazar helpers opcionales de UI y superficie pública sin valor de mantenimiento.

---

## Regla operativa nueva — guía viva obligatoria

**Al terminar cada frente de ejecución**, los artefactos de guía deben actualizarse en el mismo ciclo. No es opcional, no es "después". El ciclo no está cerrado hasta que la guía refleje el estado actual.

Qué actualizar y qué escribir en cada artefacto:

| Artefacto | Qué escribir al cerrar un frente |
|---|---|
| `ai/health-check.summary.json` | Regenerar con `health_check.py`. Refleja estado técnico objetivo. |
| `ai/repo-map.json` | Eliminar entradas de archivos/dominios borrados. Actualizar `current-focus` y `next-frontier`. Nunca dejar rutas que ya no existen. |
| `AGENTS.md` → *Current evolution status* | Reemplazar —no acumular— con el estado actual: qué se completó, qué ya no aplica, cuál es el siguiente frente. Una IA nueva debe poder leer solo esta sección y saber dónde está el repo. |
| `README.md` → *Current evolution status* | Igual que `AGENTS.md`: reemplazar, no acumular. Quitar menciones a frentes ya ejecutados. |
| `next.md` | Una sola línea o párrafo: el frente siguiente y el estado actual. Borrar lo anterior. No es un log. |

**Regla de escritura:** estas secciones se *reemplazan*, no se extienden. La historia que ya no sirve no pertenece aquí; pertenece al log de git o se descarta. Si una sección crece en lugar de mantenerse compacta, es una señal de que la actualización fue incorrecta.

---

## Frentes de evolución (orden de ejecución)

### Frente 1 — Eliminar UI helpers dormidos

**Por qué es agresivo:** `dark-theme.ahk` y `window-border-overlay.ahk` viven en `library/ui/` pero ninguno de los dos está `#Include`-ado en `bootstrap.ahk` ni en `keyflow.ahk`. La línea de `WindowBorderOverlay` en `keyflow.ahk` está comentada. Son código muerto.

**Acciones:**
1. Confirmar que `dark-theme.ahk` y `window-border-overlay.ahk` no son referenciados en ningún archivo activo.
2. Eliminar `platforms/windows/library/ui/dark-theme.ahk`.
3. Eliminar `platforms/windows/library/ui/window-border-overlay.ahk`.
4. Eliminar el directorio `platforms/windows/library/ui/` si queda vacío.
5. Eliminar las líneas comentadas de `WindowBorderOverlay` y `activeWindowIdProvider` en `keyflow.ahk`.
6. Ejecutar health check. **Actualizar guía AI** (ver regla operativa).

**Riesgo:** bajo — código nunca ejecutado en producción.

---

### Frente 2 — Colapsar agregadores de hotkeys vacíos

**Por qué es agresivo:** `hotkeys/editors.ahk` y `hotkeys/sap.ahk` son archivos que solo contienen `#Include` de sub-archivos más una función `trackXxxHotkeyUsage()`. Si esa función puede vivir en su sub-archivo correspondiente, los agregadores desaparecen y `keyflow.ahk` incluye directamente los archivos finales.

**Acciones:**
1. Revisar si `trackEditorsHotkeyUsage()` y `trackSapGuiHotkeyUsage()` / `trackSapEclipseHotkeyUsage()` son llamadas desde fuera de sus respectivos sub-archivos.
2. Si solo se llaman internamente: mover las funciones a los sub-archivos y eliminar `editors.ahk` y `sap.ahk`.
3. Actualizar `keyflow.ahk` para incluir directamente `editors-ide.ahk`, `editors-office.ahk`, `editors-text.ahk`, `sap-gui.ahk`, `sap-eclipse.ahk`.
4. Ejecutar health check. **Actualizar guía AI**.

**Condición de parada:** si `trackXxxHotkeyUsage()` es llamada desde múltiples archivos como punto centralizado, mantener el agregador pero documentarlo explícitamente en `repo-map.json`.

---

### Frente 3 — Eliminar `util.ahk` → `AppUtils` y absorber en servicios

**Por qué es agresivo:** `AppUtils` es un objeto global (`utils`) con métodos utilitarios dispersos. Algunos métodos como `paste()`, `tooltip()`, `clipboardRead()` podrían pertenecer a servicios específicos. Otros como `iswindow()`, `keyClear()`, `fileLines()` son helpers sin dueño claro.

**Acciones:**
1. Auditar cada método de `AppUtils` y mapear qué servicio lo llama.
2. Métodos usados solo por un servicio: moverlos dentro de ese servicio.
3. Métodos transversales genuinos: convertir en funciones libres en lugar de métodos de clase.
4. Si `AppUtils` queda con ≤3 métodos: disolver la clase, convertir en funciones libres en `bootstrap.ahk`.
5. Ejecutar health check. **Actualizar guía AI**.

**Riesgo:** medio — requiere auditoría de referencias cruzadas. Usar `lsp_references` antes de cada movimiento.

---

### Frente 4 — Eliminar `json-service.ahk` como wrapper

**Por qué es agresivo:** `JsonService` es una clase con dos métodos estáticos (`load`, `dump`) que son pure delegation a `jxonLoadImpl` / `jxonDumpImpl`. La clase no añade valor sobre llamar las funciones directamente.

**Acciones:**
1. Auditar todas las llamadas a `JsonService.load(...)` y `JsonService.dump(...)`.
2. Reemplazar cada llamada con `jxonLoadImpl(...)` / `jxonDumpImpl(...)`, o renombrar las funciones impl a `jsonLoad` / `jsonDump` sin wrapper.
3. Eliminar la clase `JsonService`.
4. Renombrar el archivo para que refleje su contenido real (el parser JXON), o absorberlo en `bootstrap.ahk`.
5. Ejecutar health check. **Actualizar guía AI**.

**Riesgo:** bajo — refactor mecánico 1:1.

---

### Frente 5 — Reducir superficie de `constants-core-*.ahk`

**Por qué es agresivo:** hay 5 archivos de constantes más un consolidador. Esta granularidad fue útil en crecimiento; en modo simplificación es sobrecarga de navegación para una IA.

**Acciones:**
1. Leer todos los archivos de constantes y mapear cuántas constantes tiene cada uno.
2. Si algún archivo tiene < 5 constantes: fusionarlo con el más cercano semánticamente.
3. Si el total de constantes activas < 40: consolidar en un solo `constants.ahk`.
4. Ejecutar health check. **Actualizar guía AI** — `repo-map.json` debe reflejar el nuevo nombre y la nueva ruta.

**Condición de parada:** no fusionar `constants-secrets.ahk` con el resto — los secrets siempre separados.

---

### Frente 6 — Auditar y podar `stop-portable-apps.ahk`

**Por qué es agresivo:** mata 12 procesos hardcodeados. Algunos (`norman-app.ahk`, `tbaction.exe`, `handy.exe`) son probablemente legacy.

**Acciones:**
1. Revisar si todos los procesos listados siguen siendo relevantes.
2. Eliminar entradas para apps que ya no forman parte del setup.
3. Si el archivo queda con < 4 entradas: mover al `local-startup.ini` como configuración local y eliminar el script versionado.
4. **Actualizar guía AI** si el archivo es eliminado.

---

### Frente 7 — Vaciar directorios estructurales vacíos

**Por qué es agresivo:** `platforms/mac/`, `docs/`, `.agents/` están vacíos. Son ruido estructural que una IA nueva puede interpretar como "hay algo aquí".

**Acciones:**
1. Confirmar que están realmente vacíos.
2. Eliminarlos, o añadir un `README.md` de una línea solo si hay intención declarada y fecha de activación prevista.
3. Si se eliminan: sacarlos de `repo-map.json`. **Actualizar guía AI**.

---

### Frente 8 — Eliminar `hotkey-usage.example.json`

**Por qué es agresivo:** `hotkey-usage.json` es local-only (en `.gitignore`). El ejemplo versionado no añade onboarding que no esté ya cubierto por la documentación.

**Acciones:**
1. Confirmar que ningún script referencia el ejemplo en runtime.
2. Eliminar del repo.
3. **Actualizar guía AI** si se menciona en `repo-map.json`.

---

## Orden de ejecución recomendado

| Prioridad | Frente | Impacto | Riesgo | Esfuerzo |
|---|---|---|---|---|
| 1 | Frente 1 — UI helpers dormidos | Alto | Bajo | Bajo |
| 2 | Frente 2 — Agregadores de hotkeys | Alto | Bajo | Bajo |
| 3 | Frente 4 — JsonService wrapper | Medio | Bajo | Bajo |
| 4 | Frente 7 — Directorios vacíos | Bajo | Nulo | Mínimo |
| 5 | Frente 8 — hotkey-usage.example | Bajo | Nulo | Mínimo |
| 6 | Frente 6 — stop-portable-apps | Medio | Bajo | Bajo |
| 7 | Frente 5 — Constantes | Alto | Medio | Medio |
| 8 | Frente 3 — AppUtils | Alto | Medio | Alto |

---

## Protocolo de ejecución por frente

```
1. python ai/health_check.py --pretty --summary           # baseline antes de tocar nada
2. Auditar referencias: lsp_references + grep antes de borrar
3. Hacer el cambio mínimo responsable
4. python ai/health_check.py --pretty \
     --output ai/health-check.json \
     --output-summary ai/health-check.summary.json        # validar ok: true
5. Actualizar guía AI (obligatorio, mismo ciclo):
   - repo-map.json: eliminar rutas muertas, actualizar current-focus
   - AGENTS.md / README.md → "Current evolution status": reemplazar, no acumular
   - next.md: una línea con el siguiente frente
6. Smoke-test si wiring cambió:
   platforms/windows/tools/exe/AutoHotkey64.exe /ErrorStdOut=CP65001 platforms/windows/keyflow.ahk
```

---

## Definición de "done" para todo el plan

- `health-check`: `ok: true`, 0 issues después de cada frente.
- El número de archivos en `library/` y `hotkeys/` disminuyó visiblemente.
- Ningún archivo `#Include`-ado referencia código eliminado.
- Una IA nueva puede leer `health-check.summary.json` + `repo-map.json` + `AGENTS.md` y entender el estado sin arqueología adicional.
- `repo-map.json` no menciona rutas que ya no existen.
- `AGENTS.md` y `README.md` no conservan historia obsoleta en sus secciones de estado.
- `next.md` tiene exactamente un párrafo: el frente siguiente y el estado actual.
