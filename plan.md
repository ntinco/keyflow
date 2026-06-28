Plan de continuación AI-friendly para keyflow después de axet-code
Resumen
Continuar desde el estado actual ok: true con una limpieza agresiva en runtime, startup, naming y tooling AI-first, y agregar una regla operativa nueva: al terminar cada ciclo de ejecución también se deben actualizar los artefactos de guía del repositorio para dejar explícito qué cambió, qué ya no aplica y en qué punto quedó la evolución.
La meta es doble:
que una IA nueva pueda entender y modificar keyflow leyendo muy pocos archivos;
que esos mismos archivos de guía evolucionen junto al código, sin quedarse obsoletos ni conservar historia que ya no sirve.
Cambios de implementación
1. Reafirmar el contrato AI-first y eliminar contradicciones
Actualizar AGENTS.md, README.md y ai/repo-map.json para que la fuente documental real sea solo README.md, AGENTS.md y ai/.
Eliminar referencias a docs/ inexistente y cualquier instrucción que apunte a flujos ya retirados.
Cambiar la postura sobre legacy: NORMAN_* y norman_src dejan de describirse como “compatibles” y pasan a ser deuda a retirar.
Mantener la regla de no tocar archivos locales reales, pero documentar que los ejemplos y el provider de KeePass son el único contrato válido.
2. Cortar el naming SAP legacy de punta a punta
Renombrar la API pública de sesiones SAP para que exprese intención de negocio y no historia técnica.
Reemplazar openDevSession, openQasSession, openPrdSession, openSession, reloginFromProjectWindow y helpers asociados por una taxonomía única basada en session.
Migrar las claves internas que hoy usan sap_logon_* hacia nombres directos y estables alineados con pluz dev, pluz qas, pluz prd.
Ajustar hotkeys, hotstrings y wiring para que no queden aliases legacy.
Mantener textos externos reales de SAP y nombres de negocio tal cual están.
3. Reescribir startup/ al contrato actual de keyflow
Modernizar host-startup.ahk y vmware-startup.ahk para que usen solo local-startup.ini y rutas explícitas del contrato actual.
Eliminar todo fallback a EnvGet("NORMAN_*"), norman_src y defaults históricos incrustados.
Separar claramente “arranque de keyflow” de “bootstrap personal de la máquina”: keyflow debe ser una llamada pequeña y explícita dentro del startup.
Si una rutina de startup no pertenece al runtime principal ni al onboarding mínimo, moverla a una zona secundaria claramente marcada o planificar su salida inmediata.
4. Reducir la superficie pública del runtime
Revisar services.* y dejar público solo lo que tenga consumidores reales o valor semántico claro.
Convertir a privados o eliminar métodos públicos sin callers como jobGroupKey, paste, registerEntries y cualquier wrapper equivalente que no aporte contrato útil.
Mantener separados sap-session.ahk y sap.ahk, pero con frontera más nítida:sap-session.ahk: resolución KeePass, armado de sesión, apertura y credenciales.
sap.ahk: automatización SAP GUI/Eclipse sobre sesión abierta.

Mantener hotkeys/ como capa declarativa y sacar de ahí cualquier lógica que deba vivir como intención reusable.
5. Convertir el health check en guardián del nuevo modelo
Cambiar ai/health_check.py para que referencias legacy prohibidas dejen de ser solo auditoría y pasen a fallar el chequeo.
Hacer que también detecte referencias documentales o de workflow a rutas inexistentes o contratos viejos.
Detectar:NORMAN_* y norman_src
referencias a docs/ inexistente
métodos públicos de servicio sin consumidores
grupos, targets o constantes sin uso

Mantener ai/health-check.summary.json corto, pero alineado con el contrato nuevo y sin notas que reintroduzcan compatibilidad legacy.
6. Evolucionar agresivamente los artefactos guía al cierre de cada ciclo
Al terminar cualquier ejecución importante, actualizar obligatoriamente los archivos de guía que gobiernan navegación, mantenimiento y continuidad.
El mínimo obligatorio de cierre es:AGENTS.md
README.md
ai/repo-map.json
ai/health-check.summary.json
cualquier artefacto AI-first adicional que se use como guía operativa del repo

Esos archivos deben dejar explícito:qué cambió en el modelo actual
qué rutas o reglas dejaron de aplicar
cuál es la nueva forma correcta de trabajar
en qué punto quedó la evolución y cuál es el siguiente frente lógico

La actualización de guías no debe ser conservadora: si una guía quedó vieja, se reescribe o se adelgaza sin miedo, igual que el runtime.
Si conviene formalizar esto, el nombre paraguas recomendado para esa capa es AI operating guide, compuesta por AGENTS.md + README.md + artefactos ai/.
7. Ajustar el mapa AI y la navegación operativa
Refrescar ai/repo-map.json para reflejar el flujo real:entrypoint
bootstrap
startup actual
SAP session/login
SAP automation
AI tooling

Declarar explícitamente qué artefactos son runtime principal, cuáles son standalone y cuáles son soporte local.
Mantener cualquier plan*.md fuera del contrato operativo; si se conserva, que sea histórico y no fuente de verdad.
Cambios importantes de API e interfaces
La API pública de SAP se renombra a vocabulario session y elimina nombres logon/login/relogin heredados.
Los scripts de startup ya no aceptan NORMAN_* como entrada válida.
ai/health_check.py cambia su política: legacy interno prohibido pasa a ser error.
La documentación operativa deja de depender de docs/ y se concentra en el AI operating guide del repo.
El cierre de cada ejecución pasa a incluir actualización obligatoria de las guías y del estado operativo del repo.
Plan de pruebas
python ai/health_check.py --pretty --summary debe terminar con ok: true y issue_count: 0.
El output completo debe reflejar cero referencias internas a NORMAN_*, norman_src y docs/ inexistente.
platforms/windows/keyflow.ahk debe cargar limpio con platforms/windows/tools/exe/AutoHotkey64.exe /ErrorStdOut=CP65001.
Los hotkeys SAP deben seguir pudiendo abrir pluz dev, pluz qas y pluz prd mediante KeePass sin depender de sap_logon_*.
Revisión de cierre:AGENTS.md, README.md y ai/repo-map.json deben quedar alineados entre sí
ninguna guía debe mencionar reglas, rutas o comportamientos retirados
una IA nueva debe poder identificar el siguiente paso de evolución leyendo solo la capa guía

Supuestos y defaults
Se acepta romper compatibilidad con setup legacy para simplificar ahora.
No se preservan aliases sap_logon_*, relogin* ni NORMAN_* salvo dependencia externa real demostrada.
startup/ sigue en el repo, pero como flujo modernizado de keyflow, no como fósil histórico.
docs/ no vuelve como capa documental principal.
KeePassXC sigue siendo el mecanismo oficial para secretos y sesiones SAP.
AGENTS.md es obligatorio de actualizar al cierre, y el resto del AI operating guide también debe evolucionar junto al código.