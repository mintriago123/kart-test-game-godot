# Multijugador local y LAN

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

## LAN

LAN está disponible únicamente en Windows y Linux. Usa `7777/UDP` para ENet y
`7778/UDP` para anuncios. También se puede escribir una IP y puerto manuales.
Una sala desaparece del navegador después de tres segundos sin anuncios.

El anfitrión simula física, IA, cajas, objetos, impactos, vueltas, posiciones y
resultados. Los clientes envían input numerado a 30 Hz por un canal no fiable
ordenado; el anfitrión publica snapshots a 20 Hz. Los rivales se interpolan con
100 ms de buffer y el kart local reconcilia correcciones gradualmente. Sala,
ready, inicio, objetos, vueltas y resultados usan entrega fiable.

La entrada valida `LAN_PROTOCOL_VERSION = 1`, fingerprint de catálogo, pista,
piloto y vehículo. Una incompatibilidad se rechaza con texto explícito. Cada
cliente conserva un token de sesión: al desconectarse, la IA toma su kart y el
slot queda reservado; al volver con el token recupera el control. Si cae el
anfitrión, la carrera termina y no se migra el host.

LAN no incluye cifrado, cuentas, chat, UPnP, matchmaking ni servicios externos.
Debe usarse solo en una red local de confianza. No se admiten participantes
nuevos durante una carrera ni combinaciones LAN + pantalla dividida.

## Pruebas

`tools/run_tests.sh quick` incluye catálogo, sesiones, aislamiento de input,
migración de progreso, un mundo local 2+6 y un loopback real con un host y tres
clientes. Ese loopback certifica descubrimiento UDP, entrada por IP, ready,
inicio, inputs numerados, snapshots, eventos fiables y reconexión de un slot
reservado. Puede ejecutarse solo con `tools/run_lan_loopback.sh`; necesita
permiso para abrir sockets UDP locales.
`exhaustive` añade la matriz completa de pistas/CC y carreras largas; la
certificación previa a distribución debe incluir cuatro PCs, hot-plug y mandos
Xbox, PlayStation y genéricos.
