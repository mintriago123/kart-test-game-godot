# MichiKart UI system

## Intent

La interfaz debe sentirse como un panel de boxes arcade: rápida durante la conducción, expresiva en selección y siempre subordinada a la pista. La conducción conserva el foco; el color comunica identidad del circuito o estado semántico, nunca decoración gratuita.

## Tokens

- Base: grafito/asfalto para estructura y crema para lectura.
- Foco y jugador: amarillo eléctrico.
- Rivalidad, peligro y acciones destructivas: coral.
- Estado contextual: acento derivado de `TrackTheme.banner_color`, limitado por `UiColorUtils`.
- Texto: primario, secundario, terciario y deshabilitado.
- Espaciado: múltiplos de 4 px.
- Targets táctiles: mínimo 48 px.
- Radios: pequeño para controles, medio para tarjetas y grande para modales.

## Tipografía y profundidad

- `Barlow Condensed` para marca, títulos, botones y cifras.
- `Inter` para descripciones, formularios y configuración.
- Números dinámicos alineados con una escala consistente y sin cambios de layout.
- Superficies grafito escalonadas y bordes discretos; no se mezclan sombras dramáticas con contornos gruesos.

## Movimiento

- Presión: 100–140 ms.
- Entrada: 160–200 ms con salida ease-out.
- Salida: 100–140 ms.
- Los tweens se cancelan antes de iniciar otro.
- Teclado y mando navegan de forma inmediata.
- Movimiento reducido elimina escala y desplazamiento; conserva cambios de opacidad breves cuando ayudan a entender el estado.

## Reglas de fallback

- Portada ausente: minimapa.
- Retrato ausente: inicial, silueta y color corporal.
- Emblema ausente: geometría generada.
- Cualquier fallback debe conservar contraste y no bloquear navegación o gameplay.
