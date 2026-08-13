# Changelog

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
