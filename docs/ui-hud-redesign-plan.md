# Retoque expresivo del HUD y flujo de carrera

## Resumen

Actualizar el HUD, selección de modo/pista, preparación y ajustes con una dirección **arcade adaptable a cada circuito**. Se conservarán grafito, crema, amarillo y coral como identidad de marca; los colores de costa, jardín, desierto, pantano, glaciar, neón o volcán funcionarán como acentos contextuales. No se crearán recursos gráficos nuevos.

## Cambios principales

- Reorganizar el HUD:
  - Posición como dato principal; vuelta y tiempo como información secundaria.
  - Combinar velocidad y carga de miniturbo en un instrumento inferior compacto.
  - Ocultar por completo la ranura de objeto vacía; mostrarla al recoger un objeto y retirarla al consumirlo.
  - Colocar el minimapa sobre una superficie grafito translúcida para conservar legibilidad en todos los temas.
  - Sustituir el joystick fijo por una zona flotante que ocupe el 52% izquierdo y el 68% inferior: permanecerá invisible en reposo, aparecerá bajo el primer pulgar y desaparecerá al soltar. Ignorará contactos adicionales durante el arrastre para evitar saltos, sin invadir los botones derechos.
  - Reducir la opacidad de los botones móviles en reposo y reforzar únicamente el estado pulsado.
  - Convertir `GAS AUTO` en una confirmación temporal, no un elemento permanente.
- Aplicar un acento contextual durante la carrera derivado de `TrackTheme.banner_color`, con corrección automática de luminosidad y primer plano accesible. Amarillo seguirá reservado para jugador, foco y acción principal; coral para rivales, peligro y acciones destructivas.
- Rediseñar la selección de modo como una composición jerárquica: opción enfocada dominante, alternativas oscuras y compactas, títulos y descripciones separados tipográficamente. Las diferencias se expresarán mediante composición, números, líneas y color, sin iconos nuevos.
- Neutralizar la lista de pistas: superficie común, pequeña franja del color del circuito y color amplio solo en selección/preview. El texto nunca se dibujará directamente sobre un `preview_color` sin calcular contraste.
- Corregir preparación:
  - Cambiar `DIFICULTAD` por `REGLAS` cuando el control corresponda a objetos o fantasma.
  - Eliminar información duplicada del resumen.
  - Dar protagonismo equilibrado a evento, vehículo y acción de inicio.
- Corregir ajustes:
  - La pestaña inicial contendrá opciones reales de juego —fantasma y avisos— en vez de una descripción aislada.
  - Mantener categorías, foco, scroll y targets táctiles actuales.
- Consolidar tokens semánticos para HUD, texto primario/secundario, controles, estados y acentos de circuito. Aplicar realmente Barlow Condensed a títulos, cifras y botones; Inter quedará para descripciones y configuración.
- Pulir interacción: pivote centrado, tweens interrumpibles, entradas de 160–200 ms con ease-out y salidas más rápidas. El modo de movimiento reducido eliminará desplazamiento/escala y conservará solo cambios instantáneos o de opacidad.

## Interfaces y datos

- Añadir a `TrackDefinition` un origen explícito `BUNDLED`/`CUSTOM`; marcar las doce pistas incluidas como `BUNDLED` y hacer que el editor publique nuevas pistas como `CUSTOM`. La selección dejará de inferir el grupo mediante la ruta de la escena.
- Añadir una utilidad compartida que:
  - obtenga un acento seguro desde `preview_color` o `TrackTheme`;
  - ajuste luminosidad/saturación dentro de límites definidos;
  - elija texto grafito o crema con contraste mínimo de 4.5:1.
- Mantener `RaceHud.configure_minimap(track, racers)` como entrada existente y derivar internamente el tema visual del `TrackLevel`; no cambiar contratos del flujo de carrera ni datos guardados del jugador.
- Documentar dirección, jerarquía, escala tipográfica, espaciado de 4 px, estrategia de superficies y reglas de color en `.interface-design/system.md`.

## Validación

- Extender pruebas para verificar:
  - clasificación correcta de pistas incluidas y personalizadas;
  - contraste mínimo de todos los colores de las doce pistas;
  - ranura de objeto oculta/vista en sus estados;
  - aparición del joystick en el punto inicial, dirección progresiva, protección multitáctil y liberación inmediata al soltar u ocultar el HUD;
  - ausencia de solapamientos entre HUD, minimapa, pausa y controles táctiles;
  - movimiento reducido y tweens que no se acumulen.
- Ejecutar `frontend_layout.gd`, `ui_redesign.gd` y la suite rápida existente.
- Realizar QA visual en 1280×720, 640×360, 1920×1080 y ultrawide; capturar HUD de escritorio y móvil.
- Revisar como mínimo costa, pantano, glaciar, neón y volcán para cubrir fondos claros, oscuros, cálidos y saturados.
- Criterio de aceptación: la pista sigue siendo el foco al desenfocar la vista, toda cifra crítica se lee sobre cualquier tema, las acciones principales se identifican inmediatamente y ningún target táctil baja de 48 px.

## Supuestos

- Garaje, perfil, copas, lobbies y resultados quedan fuera salvo beneficios pasivos de tokens compartidos.
- El menú principal conserva su composición actual.
- No se añaden imágenes, ilustraciones ni familias de iconos.
- La mejora será claramente visible, pero compatible con la identidad y navegación existentes.
