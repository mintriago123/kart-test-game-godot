# Editor guiado de pistas

El editor se abre desde la pestaña **Pistas** de la barra superior de Godot.
Está diseñado para trabajar sin el árbol de nodos, el Inspector ni herramientas
de curvas. El proyecto se desarrolla y valida con Godot 4.7.1.

## Flujo recomendado

1. **Configuración** permite cambiar el nombre, las vueltas y la descripción.
2. **Carretera** muestra un mapa aéreo. Selecciona un punto blanco y arrástralo;
   también puedes moverlo con las flechas del teclado.
3. **Atajos** crea una conexión eligiendo puntos de entrada y salida.
4. **Objetos** coloca cajas y decoración CC0 junto a la carretera.
5. **Revisar** explica cualquier problema y habilita Probar y Publicar.

El botón **? Guía** vuelve a mostrar estas instrucciones dentro del editor.

## Crear una pista

Pulsa **Nueva**, escribe un nombre y elige una plantilla:

- Pequeña para carreras rápidas: radio base de 42 m y 6 puntos.
- Mediana como opción recomendada: radio base de 62 m y 8 puntos.
- Grande para recorridos largos: radio base de 84 m y 12 puntos.

El diálogo muestra las dimensiones, la longitud estimada y el tamaño del
entorno antes de crear la pista. Cada plantilla incluye una silueta cerrada
distinta y cuatro cajas de objetos. Las pistas nuevas se guardan en
`levels/tracks/<identificador>.tscn`.

## Editar la carretera

- Pulsa un punto, caja, decoración o centro de atajo para seleccionarlo; el
  editor abre automáticamente su paso e inspector.
- Arrastra para mover libremente. Mantén `Ctrl` para ajustar a la cuadrícula
  elegida de 1, 2 o 5 metros.
- Usa **Añadir punto después** para ampliar el trazado.
- Usa **Eliminar punto** para simplificarlo; siempre deben quedar cuatro.
- Los campos X/Y/Z permiten introducir una posición exacta; `Shift` + flechas
  mueve la selección en incrementos de 0,25 metros.
- **Marcar como salida** mueve la parrilla, la meta y el inicio lógico.
- Las flechas amarillas indican el sentido de carrera.
- `Ctrl+Z`/los botones de flecha permiten deshacer y rehacer la ruta junto con
  todos sus elementos dependientes.

El mapa se actualiza durante el movimiento y la carretera 3D se reconstruye al
terminar, evitando que el editor se bloquee. Los atajos, cajas y la decoración
colocada desde este editor conservan un progreso normalizado sobre la carretera:
siguen conectados aunque se muevan, inserten o eliminen puntos.

La rueda acerca o aleja el mapa. El botón central, o `Espacio` mientras se
arrastra, desplaza la mesa de trazado. **Encuadrar** restaura la vista completa.
El menú **Capas** controla sentido, objetos, atajos, errores y las vistas
técnicas opcionales de pendiente, curvatura y barreras.
La franja inferior muestra dimensiones, longitud, puntos y zoom. La regla de 5,
10, 20 o 50 metros y la cuadrícula se adaptan al zoom manteniendo distancias
reales del mundo.

## Atajos

Selecciona un punto de entrada y otro de salida. La salida debe estar al menos
dos puntos después de la entrada siguiendo las flechas. El editor ajusta la
dirección de ambas conexiones y abre las barreras automáticamente.

Los errores se explican con mensajes como “entra a contravía” o “sale antes de
entrar”. Un atajo inválido puede guardarse como borrador, pero no probarse ni
publicarse.
El control turquesa central permite cambiar sus desplazamientos longitudinal,
lateral y vertical sin desconectar entrada o salida.

## Cajas y decoración

Las cajas se ajustan a un punto de la carretera. Para decorar:

1. Selecciona un modelo de la biblioteca.
2. Elige el punto y el lado de la carretera.
3. Define distancia, rotación y una escala uniforme entre 50 % y 300 %.
4. Pulsa **Colocar decoración** y revisa el resultado en **Vista 3D**.

La decoración no genera colisiones. Las barreras continuas siguen controlando
la física del kart. Los props creados desde el editor conservan lado, distancia,
altura y rotación al cambiar la ruta; los props oficiales o colocados manualmente
sin ancla permanecen en sus coordenadas originales hasta su primera edición.
Entonces reciben un ancla compatible dentro de una operación deshacer/rehacer.
Los assets nuevos parten de una escala arcade calibrada por su altura visible.
Al seleccionar una decoración puedes aplicar progreso, distancia, altura,
rotación y escala como una sola operación. La decoración anterior conserva su
tamaño hasta la primera edición explícita de escala; en ese momento adopta su
transformación actual como base y preserva sus proporciones.
Cajas y decoración se duplican con `Ctrl+D` y se eliminan con `Supr`.

## Abrir pistas antiguas

Al abrir una escena creada antes del sistema de anclas, el editor proyecta los
extremos de atajos y las cajas sobre el punto más cercano de `MainRoute`. La
barra inferior muestra un resumen, por ejemplo, “2 atajos y 4 cajas reparados”.

La reparación:

- solo existe en memoria hasta pulsar **Guardar**;
- aparece como un cambio sin guardar;
- se puede deshacer y rehacer como una sola operación;
- no modifica automáticamente el archivo de origen.

## Guardar, probar y publicar

- **Guardar** conserva incluso una pista incompleta como borrador.
- **Abrir** permite recuperar cualquier `.tscn`, aunque todavía no esté publicado.
- Al cambiar de pista se puede Guardar, Descartar o Cancelar.
- **Probar** ejecuta la escena actual con el kart sin añadirla al menú.
- **Publicar** exige una validación correcta y registra automáticamente la pista
  en `levels/track_catalog.tres`. También genera y guarda el plano 2D que aparece
  en el selector vertical de pistas, con distancia, salida, sentido y atajos.

El editor mantiene una copia de recuperación dentro de `user://`; no forma parte
del repositorio ni del APK.

Durante una prueba se muestran tiempo, recuperaciones, salidas del corredor
válido y atajos aceptados. **Volver al editor** o `F8` termina la prueba incluso
en pausa. El editor consume únicamente el resultado de la sesión recién
iniciada, muestra su resumen y no conserva un historial permanente.

## Validación y pruebas

Antes de publicar se comprueban la ruta cerrada, longitud, salida, cajas,
dirección de atajos y recursos obligatorios. Cada problema permite regresar al
paso correspondiente, selecciona el elemento y centra el mapa cuando existe una
posición concreta. Los pasos muestran su cantidad de problemas y actualizan la
validación al terminar cada edición. Una pista inválida conserva en Vista 3D toda carretera,
bordillo y barrera que todavía pueda generarse; solo se omiten sus componentes
inválidos.

Las barreras cerradas usan un anillo indexado con uniones miter limitadas y
bevel en ángulos agudos. Los portales de atajos se abren sobre el lado real y
se conectan al embudo sin tapas perpendiculares; solo los extremos realmente
expuestos reciben un remate redondeado.

Las entradas usan una boca adaptativa de 14–16 m y una transición de 12–14 m.
Las salidas conservan una boca de 12 m y una transición de 8–10 m. Las barreras
del atajo recorren un hombro exterior para mantener libre el corredor del kart.

Las pruebas automatizadas son:

```sh
GODOT_BIN=/home/mintriago/Godot_v4.7.1-stable_linux.x86_64

for suite in \
  tests/track_editor.gd tests/track_barriers.gd \
  tests/track_minimap.gd tests/track_authoring.gd \
  tests/shortcut_drive.gd tests/race_stability.gd
do
  "$GODOT_BIN" --headless --path . --script "$suite" || exit $?
done
```
