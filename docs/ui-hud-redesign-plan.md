# Fase 1: HUD y flujo pre-carrera

Este documento es la primera fase de [ui-frontend-redesign-plan.md](ui-frontend-redesign-plan.md), que es el plan principal y normativo del rediseño. Aquí solo se detallan los cambios necesarios para el HUD, la selección previa a carrera y los ajustes directamente relacionados con el gameplay.

Las reglas globales de tokens, tipografía, contraste, movimiento, componentes, assets, compatibilidad, fallbacks y QA se definen en el plan frontend. Cuando exista solapamiento, prevalece el plan frontend.

## Alcance de la fase

- HUD de carrera para escritorio y móvil.
- Selección de modo y pista.
- Preparación de carrera.
- Ajustes de gameplay visibles desde el flujo previo o durante la carrera.
- Pruebas de layout, interacción y accesibilidad específicas de estas pantallas.

Quedan fuera de esta fase el rediseño de Garaje, Perfil, Copas, Resultados, lobbies, título, menú principal y la producción de assets nuevos. Esas áreas pertenecen a las fases posteriores del plan frontend.

## HUD de carrera

- Mostrar la posición como dato principal; vuelta y tiempo quedarán como información secundaria.
- Combinar velocidad y carga de miniturbo en un instrumento inferior compacto.
- Ocultar por completo la ranura de objeto vacía; mostrarla al recoger un objeto y retirarla al consumirlo.
- Colocar el minimapa sobre una superficie grafito translúcida para conservar legibilidad en todos los temas.
- Derivar el acento de carrera de `TrackTheme.banner_color`, respetando los colores semánticos globales definidos en el plan frontend.
- Mantener la pista como foco visual y evitar HUD sobre el eje central salvo cuenta regresiva o feedback transitorio.

## Controles táctiles

- Sustituir el joystick fijo por una zona flotante que ocupe el 52% izquierdo y el 68% inferior.
- Mantenerlo invisible en reposo, centrarlo bajo el primer pulgar y ocultarlo al soltar o al ocultar el HUD.
- Ignorar contactos adicionales durante el arrastre activo y evitar invadir los botones derechos.
- Reducir la opacidad de los botones móviles en reposo y reforzar únicamente el estado pulsado.
- Convertir `GAS AUTO` en una confirmación temporal, no en un elemento permanente.

## Selección y preparación

- Rediseñar la selección de modo con una opción enfocada dominante y alternativas compactas sobre superficies oscuras.
- Separar títulos y descripciones; expresar diferencias mediante composición, numeración y color, sin introducir iconos nuevos en esta fase.
- Neutralizar la lista de pistas, reservando el color contextual para la franja y el preview.
- No dibujar texto directamente sobre `preview_color` sin aplicar la utilidad de contraste compartida.
- Cambiar `DIFICULTAD` por `REGLAS` cuando el control corresponda a objetos o fantasma.
- Eliminar información duplicada del resumen de preparación y equilibrar evento, vehículo, configuración y acción de inicio.

## Ajustes de gameplay

- Hacer que la pestaña inicial contenga controles reales de juego, incluyendo fantasma y avisos, en vez de una descripción aislada.
- Mantener categorías, foco, scroll y targets táctiles existentes.
- Reutilizar el componente de ajustes compartido para las entradas desde menú y carrera.

## Interfaces y compatibilidad

- Mantener `RaceHud.configure_minimap(track, racers)` como entrada pública.
- Derivar internamente el tema visual desde `TrackLevel.track_theme` sin cambiar contratos del flujo de carrera.
- Usar los campos y fallbacks definidos en la sección “Migración y fallbacks” del plan frontend; esta fase no introduce una política alternativa.
- La clasificación `BUNDLED`/`CUSTOM` se implementará según el plan frontend, aunque la UI de pistas sea parte de esta fase.

## Validación específica

- Verificar contraste mínimo de los acentos de todas las pistas incluidas.
- Verificar estados de objeto vacío/ocupado y consumo.
- Verificar aparición del joystick en el punto inicial, dirección progresiva, protección multitáctil y liberación inmediata.
- Verificar ausencia de solapamientos entre HUD, minimapa, pausa y controles táctiles.
- Verificar targets táctiles de al menos 48 px.
- Verificar navegación, foco, acciones deshabilitadas y movimiento reducido.
- Ejecutar `frontend_layout.gd`, `ui_redesign.gd` y la suite rápida existente.
- Realizar QA visual en 640×360, 1280×720, 1920×1080 y ultrawide, cubriendo al menos costa, pantano, glaciar, neón y volcán.

## Criterios de aceptación

- La pista sigue siendo el foco al desenfocar la vista.
- Toda cifra crítica se lee sobre cualquier tema incluido.
- Las acciones principales se identifican inmediatamente.
- Ningún target táctil interactivo baja de 48 px.
- El HUD funciona sin portadas u otros assets opcionales gracias a los fallbacks del plan frontend.
