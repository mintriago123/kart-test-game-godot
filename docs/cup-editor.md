# Editor visual de Copas

El plugin añade la pestaña principal **Copas** al editor de Godot. Trabaja únicamente con pistas, pilotos, dificultades y vehículos que ya estén publicados.

## Flujo recomendado

1. Crea una Copa y completa nombre, descripción, orden y, si corresponde, su Copa previa. El requisito puede exigir una dificultad concreta o aceptar cualquiera.
2. Elige tres circuitos distintos. Las flechas cambian su orden.
3. Selecciona un piloto, tres rivales, una tabla de puntos estrictamente descendente y al menos una dificultad.
4. Define los umbrales de bronce, plata y oro. El panel muestra el máximo posible.
5. Asigna opcionalmente un vehículo a Bronce, Plata y Oro. El premio es acumulativo y no depende de la dificultad.
6. Revisa los errores, usa el simulador y publica.

Todos los controles interactivos tienen una altura mínima de 48 px y el flujo funciona por teclado. Los errores de la revisión llevan a la sección correspondiente.

## Borradores y recuperación

**Guardar borrador** escribe `progression/cups/drafts/{id}.tres`. Estos recursos no se añaden al catálogo y, por tanto, no aparecen en el juego. Cada cambio también actualiza `user://michikart_cup_recovery.tres`; **Recuperar** abre esa copia como borrador.

Al abrir una Copa publicada, su ID queda bloqueado. Antes de reemplazar una Copa publicada conviene revisar especialmente cambios de circuitos, acceso, orden, puntuación, dificultades y premios. Las medallas históricas se conservan por ID de Copa y dificultad.

## Publicación

**Publicar** sólo se habilita si la validación completa no encuentra errores. Los premios nuevos reciben IDs `{cup_id}_{medal}`. Los premios retirados dejan de pertenecer a la Copa, pero permanecen archivados en `UnlockCatalog`, para que partidas antiguas puedan resolver sus IDs.

Los hitos globales por puntos aparecen como un resumen de solo lectura. Se mantienen en `UnlockCatalog` porque pertenecen a toda la campaña, no a una Copa concreta.

La publicación guarda primero los premios, luego la Copa y finalmente `progression_catalog.tres`. Conserva copias byte a byte de todos los archivos afectados y las restaura si falla cualquiera de las escrituras. Al terminar, el filesystem del editor se vuelve a escanear.

La Copa Tropical conserva el ID `tropical`. El guardado schema 4 migra los nueve IDs de premios históricos al nuevo premio que contiene el mismo vehículo.
