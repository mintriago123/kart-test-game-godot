# Changelog

## 1.3.0-beta.1 - 2026-08-13

### Red local

- Sala ENet autoritativa para hasta cuatro dispositivos Android, Windows o Linux, con IA hasta completar ocho.
- Descubrimiento UDP, conexión por IP, validación de protocolo/fingerprint y mensajes de incompatibilidad.
- Inputs a 30 Hz, snapshots a 20 Hz, interpolación, predicción local y reconciliación.
- Slots reservados con IA temporal y reconexión por token; caída del host finaliza la partida.
- Android ofrece LAN con un humano por dispositivo, oculta pantalla dividida y habilita el permiso de red del APK.

### Compatibilidad

- Guardado schema 5 con telemetría separada para pantalla dividida y LAN.
- Los modos multijugador no conceden medallas, desbloqueos ni récords de pista.

## 1.2.0 - 2026-08-13

### Multijugador local

- Catálogo ampliado a ocho pilotos con Sol, Coco, Perla y Nube.
- Carrera rápida de ocho corredores; Copas conservan cuatro y puntuación 9/6/3/1.
- Sala local de dos jugadores, input por dispositivo y selección de piloto único/vehículo independiente.
- Pantalla dividida horizontal con cámara, minimapa y HUD por jugador, resultados múltiples y DNF a 30 segundos.
- Perfil gráfico temporal para sostener dos vistas sin modificar los ajustes guardados.

## 1.1.0-beta.1 - 2026-08-13

### Funcionalidades

- Campaña de siete Copas de tres pistas: cuatro eventos principales y tres remix.
- Progresión híbrida con ocho vehículos por medallas, cuatro por hitos globales y Sedán inicial.
- Puntos de carrera idempotentes con multiplicadores por dificultad y un máximo de 126.
- Selector de Copas, Perfil y Garaje con candados, requisitos, próximo hito y recompensas acumulativas.
- Doce circuitos oficiales reorganizados en la campaña sin modificar su identidad visual.

### Pruebas y estabilidad

- Certificación de atajos basada en los corredores y muestras de navegación usados en producción.
- Comprobaciones independientes para geometría, compuertas, superficie, conducción y recuperaciones.
- Perfiles rápido y exhaustivo para estabilidad de carreras y conducción de atajos.
- Ejecución aislada de cada suite para evitar contaminación de `user://` y rotación compartida de logs.

### Compatibilidad

- El guardado usa el esquema 4 y migra partidas de los esquemas 1–3 sin revocar vehículos.
- Se conservan medallas, telemetría, Copa activa, recompensas vistas y vehículo equipado.
- Si una partida antigua no tiene vehículo equipado, se asigna el Sedán inicial.

## 1.0.0

### Funcionalidades

- Celebración final de Copa por clasificación, medalla y recompensas.
- Perfil desplazable con estadísticas, medallas y estado de la colección.
- Selector de Copa generado desde catálogo con circuitos, minimapas y premios.
- Preparación adaptable con showroom, minimapa y selectores táctiles.
- Galería centrada con estados Bloqueado, Nuevo y Equipado.

### Correcciones

- El muestreo de recuperación se reinicia al establecer un punto de reaparición.
- La prueba de conducción de atajos distingue una recuperación automática de un bucle.
- Las tarjetas de galería actualizan su estado al inspeccionar una recompensa.

### Compatibilidad

- Se conserva el formato de Copa activa, medallas, telemetría y vehículo equipado.
- Las partidas schema 2 migran a schema 3 y consideran vistas sus recompensas existentes.
