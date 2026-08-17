# Rediseño integral del frontend y paquete visual

## Relación con el plan existente

Este documento amplía [ui-hud-redesign-plan.md](ui-hud-redesign-plan.md). El plan original se conserva como especificación detallada de la primera fase —HUD y flujo previo a carrera— y sigue siendo aplicable salvo cuando este documento añade requisitos más amplios.

## Resumen

Extender el retoque a todo el frontend con una dirección **arcade multientorno**. Grafito, crema, amarillo y coral formarán la identidad estable de MichiKart; los colores de costa, jardín, desierto, pantano, glaciar, neón, volcán y demás circuitos actuarán como acentos contextuales.

El HUD seguirá priorizando la conducción. Los menús, la progresión y los resultados podrán ser más expresivos, pero compartirán tipografía, superficies, contraste, movimiento y componentes con el flujo de carrera.

## Dirección de diseño

- **Dominio:** parrilla, boxes, campeonato, vueltas, récords, medallas, garaje, rivales, atajos y velocidad.
- **Color base:** grafito/asfalto para estructura, crema para lectura, amarillo para foco y jugador, coral para rivalidad, peligro y acciones destructivas.
- **Color contextual:** cada pista o Copa aporta un acento derivado de sus temas y circuitos, sin reemplazar los colores semánticos de la marca.
- **Firma visual:** wordmark de MichiKart, showroom 3D, minimapas y portadas de circuito, cifras de carrera condensadas y geometría inspirada en señalización de pista.
- **Profundidad:** superficies oscuras escalonadas y bordes discretos; evitar mezclar sombras dramáticas, contornos gruesos y cambios bruscos de color.
- **Tipografía:** Barlow Condensed para marca, títulos, botones y cifras; Inter para descripciones, formularios y texto de configuración.
- **Movimiento:** rápido, interrumpible y funcional. Navegación con teclado o mando será instantánea; puntero y toque podrán recibir transiciones breves y feedback de presión.

## Sistema compartido

- Consolidar en `UiTokens`:
  - cuatro niveles de texto: primario, secundario, terciario y deshabilitado;
  - superficies base, elevada, flotante y scrim;
  - tokens de controles, borde, foco, éxito, advertencia y peligro;
  - escala tipográfica expresiva y números tabulares;
  - espaciado basado en 4 px y radios para control, tarjeta y modal;
  - duraciones de movimiento: presión 100–140 ms, entrada 160–200 ms y salida 100–140 ms.
- Añadir una utilidad de color contextual que:
  - reciba `TrackDefinition.preview_color` o un color de `TrackTheme`;
  - limite luminosidad y saturación para evitar acentos ilegibles o dominantes;
  - elija grafito o crema como primer plano;
  - garantice un contraste mínimo de 4.5:1 para texto normal.
- Extender los componentes compartidos para cubrir botones, tarjetas de evento, indicadores de estado, filas de clasificación, tarjetas de recompensa, avisos y estados vacío/error.
- Centrar el pivote de elementos presionables y cancelar el tween anterior antes de iniciar uno nuevo. El feedback `scale(0.97)` se aplicará solo a puntero/toque.
- El modo de movimiento reducido eliminará escala y desplazamiento, manteniendo cambios instantáneos o fundidos breves cuando ayuden a comprender el estado.
- Documentar decisiones y medidas finales en `.interface-design/system.md`.

## Paquete de assets

Los nuevos recursos se derivarán del propio juego; no se introducirá una estética ilustrada que contradiga los modelos presentes en carrera.

### Marca

- Crear un wordmark SVG de `MICHIKART XD`, convertido a trazados para no depender de fuentes instaladas.
- Mantener la relación amarillo/coral del menú y preparar una variante clara y otra compacta para fondos oscuros.
- Usarlo en título y menú; las pantallas funcionales conservarán encabezados tipográficos normales para no saturar la marca.

### Pilotos

- Crear ocho retratos cuadrados de 256×256 mediante captura controlada del vehículo, conductor y color de cada `RacerDefinition`.
- Usar encuadre, iluminación, fondo y cámara idénticos para toda la serie.
- Conectar las texturas al campo existente `RacerDefinition.portrait`.
- Mostrar fallback con inicial, color corporal y silueta neutral si falta una textura.

### Copas

- Crear siete emblemas SVG derivados de las formas, colores y combinación de los tres circuitos de cada Copa.
- Mantener silueta legible a 32, 64 y 128 px.
- Conectar cada emblema al campo existente `CupDefinition.icon`.
- Usar un fallback geométrico generado por código cuando no exista icono.

### Circuitos

- Generar doce portadas WebP de 960×540 desde Godot, con un objetivo aproximado máximo de 250 KB por portada.
- Añadir a cada pista incluida un marcador `PreviewCamera` que defina una vista reconocible y no interfiera con la carrera.
- Crear una herramienta determinista que cargue cada pista, coloque su tema, espere a estabilizar el render y exporte la portada.
- Conectar las portadas al campo existente `TrackDefinition.preview_texture`.
- Mantener el minimapa como fallback para pistas personalizadas o portadas ausentes.

### Iconos funcionales y vehículos

- Crear SVG coherentes para bloqueo, nuevo, equipado, medalla, récord, multijugador local y red.
- No duplicar iconos de objetos ni prompts de entrada ya existentes.
- Reutilizar `VehicleViewport` para recompensas y presentación de vehículos; no hornear miniaturas separadas salvo que una prueba de rendimiento lo justifique.
- Mantener el paquete total de nuevas texturas y vectores por debajo de aproximadamente 4 MB y usar importación comprimida apropiada para Android.

## Pantallas y flujos

### Título y menú principal

- Sustituir el título textual por el wordmark y conservar el vehículo 3D como firma principal.
- En título, la única acción focal será comenzar; prompt y versión pasarán a niveles secundarios.
- Mantener la composición amarilla/coral del menú, refinando proporciones y espacio para que logo, acciones y showroom no compitan.
- `JUGAR` será la acción dominante; Garaje, Perfil y Ajustes tendrán menor contraste.
- Si existe una Copa activa, `CONTINUAR COPA` reemplazará a `JUGAR` como primer foco, sin convertir ambas en acciones primarias simultáneas.

### Modo, pista y preparación

- Rediseñar modos como una composición jerárquica: tarjeta enfocada protagonista y alternativas compactas sobre superficies oscuras.
- Separar título y descripción de cada modo; expresar identidad con geometría, numeración y color sin ilustraciones adicionales.
- Neutralizar la lista de pistas: superficie común, franja de acento y portada/minimapa en el panel principal.
- El texto nunca se dibujará directamente sobre un `preview_color` sin elección automática de contraste.
- En preparación, sustituir el encabezado `DIFICULTAD` por `REGLAS` cuando corresponda a objetos o fantasma, eliminar datos duplicados y equilibrar evento, vehículo, configuración y acción de inicio.

### HUD de carrera

- Posición será el dato principal; vuelta y tiempo serán secundarios.
- Combinar velocidad y carga de miniturbo en un instrumento inferior compacto.
- Ocultar totalmente la ranura de objeto vacía; mostrarla al obtener un objeto y retirarla al consumirlo.
- Colocar el minimapa sobre una superficie grafito translúcida, reducir ruido de flechas y mantener jugador/rivales distinguibles.
- Derivar el acento de carrera de `TrackTheme.banner_color`, sin cambiar los colores semánticos de jugador, rival, éxito o peligro.
- Usar un joystick móvil flotante sobre una zona amplia del lado izquierdo: invisible en reposo, centrado en el primer contacto, protegido frente a dedos adicionales y liberado al soltar u ocultar el HUD. Reducir opacidad de los botones móviles en reposo, reforzar el estado pulsado y convertir `GAS AUTO` en confirmación temporal.
- Mantener la pista como foco visual y evitar HUD sobre el eje central de conducción salvo cuenta regresiva o feedback transitorio.

### Copas

- Convertir la selección en una vista protagonista con emblema, descripción, progreso, mejor medalla, requisito y recompensa.
- Presentar los tres circuitos como una secuencia con sus portadas y orden de carrera.
- Diferenciar claramente bloqueada, disponible, activa y completada.
- Visualizar dificultad, multiplicador y medalla previa como opciones estructuradas, no como una línea compacta.
- Mantener las reglas actuales de Copa activa, reemplazo y confirmación.

### Garaje y selector de vehículo

- Conservar showroom 3D, carrusel, navegación lateral y comparación con el vehículo equipado.
- Dar al vehículo la mayor superficie; detalles, estado y acción ocuparán una columna secundaria.
- Sustituir cadenas con símbolos por badges compartidos para `Nuevo`, `Equipado`, `Disponible` y `Bloqueado`.
- Presentar estadísticas con valores consistentes, números tabulares, diferencia cromática y barras con escala explícita.
- Hacer visible el requisito de desbloqueo sin competir con la acción primaria.

### Perfil y progreso

- Sustituir los bloques de texto por una tarjeta de campeonato.
- Foco principal: puntos globales, siguiente hito y progreso hacia él.
- Agrupar carreras, victorias, podios, tiempo y récords como métricas secundarias.
- Presentar Copas como una matriz de emblema y medallas por dificultad.
- Mostrar colección, vehículo equipado y recompensas nuevas con enlace claro al Garaje.
- Mantener local y LAN como una sección secundaria separada.

### Resultados y recompensas

- Usar posición, récord o medalla como elemento hero según el modo.
- Convertir la clasificación en filas alineadas con posición, retrato, nombre y tiempo/puntos.
- Separar vueltas y telemetría de la información esencial; el detalle podrá desplazarse sin mover las acciones.
- Mantener `Otra carrera`/`Siguiente carrera` como acción primaria y Menú como secundaria.
- En Copa, conservar las etapas de clasificación final, medalla y recompensas, con transiciones breves y `VehicleViewport` para vehículos nuevos.
- En movimiento reducido, los cambios de etapa serán instantáneos o mediante opacidad breve.

### Multijugador local

- Convertir cada jugador en un pit box con retrato, color, dispositivo, piloto, vehículo y estado listo.
- Destacar inmediatamente la ausencia de mando para J2 y los conflictos de piloto/dispositivo.
- Mantener `Elegir circuito` bloqueado hasta que ambos jugadores estén válidos y listos.
- Conservar toda la lógica actual de teclado, mandos y parrilla de seis IA.

### Red local

- Priorizar salas descubiertas y estado de conexión sobre la introducción manual de IP.
- Mantener tres áreas funcionales: perfil local, conexión/salas y configuración/slots.
- Diferenciar visualmente anfitrión, cliente, slot libre, eligiendo, listo, desconectado e incompatible.
- Mantener visible la advertencia de red local sin cifrado, pero como aviso compacto y no como título competidor.
- Preservar descubrimiento, IP manual, permisos del anfitrión y contratos de sesión existentes.

### Ajustes, controles, pausa y modales

- La pestaña inicial de Ajustes contendrá controles reales de juego, incluyendo fantasma y avisos; no abrirá en una sección casi vacía.
- Mantener categorías, scroll, foco y targets táctiles actuales.
- Unificar ajustes abiertos desde menú y carrera mediante el componente reutilizable existente.
- En pausa, `Continuar` será primaria; Ajustes y Controles serán secundarias; Reiniciar y Salir usarán tratamiento de riesgo y confirmación.
- Unificar confirmaciones, toasts, estados vacíos y errores con títulos, cuerpo, acciones y foco consistentes.

## Interfaces y compatibilidad

- Añadir a `TrackDefinition` un campo `origin` con valores `BUNDLED` y `CUSTOM`.
- Marcar las doce pistas incluidas como `BUNDLED`; el editor publicará pistas nuevas como `CUSTOM`.
- La clasificación en “Pistas oficiales” y “Mis pistas” dejará de depender de la ruta del archivo.
- Ampliar el router con el modo de entrada actual para decidir si una transición debe animarse; navegación por teclado/mando será instantánea.
- Mantener señales públicas, rutas, payloads de selección, configuración de carrera, progresión, récords y esquemas de guardado.
- Los campos visuales nuevos o ya existentes tendrán fallbacks seguros; no se requerirá migración del save del jugador.
- Mantener `RaceHud.configure_minimap(track, racers)` y derivar internamente el acento desde `TrackLevel.track_theme`.

### Migración y fallbacks

- Los recursos existentes sin `origin` se tratarán como `BUNDLED` cuando pertenezcan al catálogo incluido; las nuevas publicaciones del editor se escribirán explícitamente como `CUSTOM`.
- El cambio de origen no alterará IDs, rutas públicas, payloads de selección, contratos de sesión ni datos guardados del jugador; no se requerirá migración de saves.
- Las pistas sin `preview_texture` conservarán el minimapa como fallback. Las pistas personalizadas no dependerán de tener una portada para poder seleccionarse o jugarse.
- Los campos visuales opcionales (`preview_texture`, `RacerDefinition.portrait` y `CupDefinition.icon`) deberán tolerar valores ausentes sin bloquear la navegación.
- Cuando falte un asset opcional se usará, según el componente, minimapa, fallback geométrico, silueta con color corporal, inicial o tratamiento textual compartido.
- Las herramientas de captura y publicación serán aditivas: no sobrescribirán assets existentes si la regeneración no fue solicitada explícitamente.

## Orden de implementación

1. Consolidar tokens, contraste, tipografía, componentes y movimiento.
2. Implementar HUD y flujo previo descritos en el plan original.
3. Crear herramientas de captura y conectar fallbacks visuales.
4. Producir wordmark, doce portadas, ocho retratos, siete emblemas e iconos funcionales.
5. Rediseñar Copas, Perfil, Garaje y Resultados.
6. Rediseñar Título, Menú, Multijugador local y LAN.
7. Unificar Ajustes, Pausa, Controles, confirmaciones y avisos.
8. Completar QA visual, rendimiento y documentación del sistema.

## Validación

- Extender pruebas automatizadas para verificar:
  - clasificación `BUNDLED`/`CUSTOM` y fallback de pistas personalizadas;
  - existencia, dimensiones y presupuesto de portadas, retratos y emblemas;
  - regeneración determinista de portadas y retratos;
  - contraste mínimo de acentos de las doce pistas;
  - estados de objeto vacío/ocupado y controles móviles;
  - aparición, arrastre progresivo, protección multitáctil y liberación del joystick flotante;
  - foco, navegación, acciones deshabilitadas y restauración de ruta;
  - ausencia de solapamientos entre HUD, minimapa, pausa y controles;
  - movimiento reducido y tweens interrumpibles;
  - fallbacks cuando falta cualquier asset opcional.
- Ejecutar `frontend_layout.gd`, `ui_redesign.gd`, pruebas de carrera/HUD y la suite rápida existente.
- Realizar QA visual en 640×360, 1280×720, 1920×1080 y ultrawide, además de captura móvil.
- Revisar al menos costa, pantano, glaciar, neón y volcán para cubrir fondos claros, oscuros, cálidos y saturados.
- Verificar rendimiento en perfil bajo/medio de Android y que las nuevas texturas no causen picos visibles al navegar.

## Criterios de aceptación

- Cada pantalla tiene un único foco reconocible al desenfocar la vista.
- Menús, carrera y progresión pertenecen claramente al mismo producto.
- Toda información crítica conserva contraste y legibilidad con cualquier tema de pista.
- Ningún target táctil interactivo baja de 48 px.
- Los assets nuevos reutilizan el lenguaje visual y contenido del juego, sin prometer personajes o estilos ausentes en carrera.
- La interfaz completa funciona sin assets opcionales gracias a los fallbacks definidos.
- La navegación por teclado/mando se siente inmediata; puntero y toque reciben feedback breve sin retrasar acciones.

## Fuera de alcance

- Rediseño funcional del editor de pistas, salvo origen de la pista y marcadores/herramientas de preview.
- Nuevos modelos 3D, personajes ilustrados independientes o cambios de gameplay.
- Nueva música o identidad sonora por circuito; se tratará como una fase separada de contenido/audio.
- Cambios en reglas de progresión, desbloqueos, multijugador o estructura de Copas.
