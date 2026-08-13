# Multijugador local

## Pantalla dividida

Pantalla dividida usa dos viewports horizontales con un único `World3D`. Cada
jugador tiene cámara, minimapa, velocidad, vuelta, posición, objeto y escudo
propios. Pausa y estado de resultados afectan a la carrera completa.

- J1: teclado o un mando conectado.
- J2: un mando conectado que no esté asignado a J1.
- Los pilotos deben ser distintos; los vehículos pueden repetirse.
- J2 usa la colección desbloqueada en el perfil de J1.
- Al terminar el primer humano comienza una espera de 30 segundos. Quien no
  llegue a meta queda marcado como DNF.
- Solo el resultado de J1 se registra en las estadísticas locales.

El juego aplica un presupuesto gráfico temporal para dos vistas: desactiva
MSAA y usa el perfil bajo para sombras/efectos sin modificar Ajustes.

## Pruebas

`tools/run_tests.sh quick` incluye catálogo, sesiones, aislamiento de input,
migración de progreso y un mundo local 2+6.
`exhaustive` añade la matriz completa de pistas/CC y carreras largas; la
certificación previa a distribución debe incluir hot-plug y mandos Xbox,
PlayStation y genéricos.
