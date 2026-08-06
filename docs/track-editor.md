# Editor guiado de pistas

El editor se abre desde la pestaña **Pistas** de la barra superior de Godot.
Está diseñado para trabajar sin el árbol de nodos, el Inspector ni herramientas
de curvas.

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

- Pequeña para carreras rápidas.
- Mediana como opción recomendada.
- Grande para recorridos largos.

Las plantillas incluyen una carretera cerrada y cuatro cajas de objetos. Las
pistas nuevas se guardan en `levels/tracks/<identificador>.tscn`.

## Editar la carretera

- Arrastra un punto para moverlo sobre el mapa.
- Usa **Añadir punto después** para ampliar el trazado.
- Usa **Eliminar punto** para simplificarlo; siempre deben quedar cuatro.
- El control **Altura** crea pendientes sencillas.
- **Marcar como salida** mueve la parrilla, la meta y el inicio lógico.
- Las flechas amarillas indican el sentido de carrera.
- `Ctrl+Z`/los botones de flecha permiten deshacer y rehacer la ruta.

El mapa se actualiza durante el movimiento y la carretera 3D se reconstruye al
terminar, evitando que el editor se bloquee.

## Atajos

Selecciona un punto de entrada y otro de salida. La salida debe estar al menos
dos puntos después de la entrada siguiendo las flechas. El editor ajusta la
dirección de ambas conexiones y abre las barreras automáticamente.

Los errores se explican con mensajes como “entra a contravía” o “sale antes de
entrar”. Un atajo inválido puede guardarse como borrador, pero no probarse ni
publicarse.

## Cajas y decoración

Las cajas se ajustan a un punto de la carretera. Para decorar:

1. Selecciona un modelo de la biblioteca.
2. Elige el punto y el lado de la carretera.
3. Define distancia y rotación.
4. Pulsa **Colocar decoración** y revisa el resultado en **Vista 3D**.

La decoración no genera colisiones. Las barreras continuas siguen controlando
la física del kart.

## Guardar, probar y publicar

- **Guardar** conserva incluso una pista incompleta como borrador.
- **Abrir** permite recuperar cualquier `.tscn`, aunque todavía no esté publicado.
- Al cambiar de pista se puede Guardar, Descartar o Cancelar.
- **Probar** ejecuta la escena actual con el kart sin añadirla al menú.
- **Publicar** exige una validación correcta y registra automáticamente la pista
  en `levels/track_catalog.tres`.

El editor mantiene una copia de recuperación dentro de `user://`; no forma parte
del repositorio ni del APK.

## Validación y pruebas

Antes de publicar se comprueban la ruta cerrada, longitud, salida, cajas,
dirección de atajos y recursos obligatorios. Cada problema permite regresar al
paso correspondiente.

Las pruebas automatizadas son:

```sh
godot --headless --path . --script tests/track_editor.gd
godot --headless --path . --script tests/track_authoring.gd
godot --headless --path . --script tests/shortcut_drive.gd
godot --headless --path . --script tests/race_stability.gd
```
