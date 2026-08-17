# Paquete visual generado

Los SVG de `brand/` y `cups/emblems/` son recursos vectoriales pequeños,
deterministas y sin dependencias de fuentes instaladas. Las portadas raster se
generan con `tools/capture_track_previews.gd` y los retratos con
`tools/capture_racer_portraits.gd`; ninguna herramienta sobrescribe un recurso
existente salvo que se pase `--force`. Si falta una portada, el selector usa el
minimapa almacenado en la definición. Retratos y emblemas mantienen fallbacks
dibujados por UI para que una importación incompleta nunca bloquee la
navegación.

Las dos herramientas de captura requieren un renderer 3D gráfico de Godot. En
modo `--headless` con renderer `dummy` se detienen sin sobrescribir recursos.
