# MichiKart xd

Juego de carreras arcade para Android, Linux y Windows creado con Godot 4.7.1.
Incluye doce pistas seleccionables, barreras continuas, atajos físicos, assets
low-poly CC0, ocho pilotos, derrape con miniturbo y seis objetos tropicales.
Las carreras ofrecen 50, 100, 150 y 200 CC con física, cámara, IA y récords
independientes; 150 CC es la selección inicial.

El selector también ofrece **Contrarreloj**: una sesión de un solo kart, sin IA
ni objetos, con récords separados y un fantasma personal compatible con pista y
cilindrada. La reproducción del fantasma puede ocultarse desde Ajustes sin dejar
de grabar nuevos intentos.

El catálogo incluye Impulso, Coco turbo, Burbuja marina, Cáscara resbalosa,
Piña perseguidora y Onda tropical. Todos usan la misma ranura y el mismo botón;
la probabilidad se adapta a la posición de carrera.

## Flujo de juego

**Jugar** utiliza este recorrido:

```text
Modo → Pista o Copa → Vehículo → Preparación → Carrera
```

- **Carrera rápida** permite elegir pista, vehículo y CC antes de competir en
  una parrilla de ocho corredores.
- **Contrarreloj** inicia una sesión individual sin IA ni objetos. Conserva
  récords por pista y CC, graba un fantasma personal y muestra en el minimapa
  únicamente al jugador y la línea de meta.
- **Copa** usa una campaña de siete eventos de tres circuitos. Tropical,
  Horizontes, Salvaje y Extrema forman la escalera principal; Contrastes,
  Expedición y Festival se abren juntas al conseguir cualquier medalla en
  Extrema.
- **Pantalla dividida** enfrenta a J1 y J2 con seis rivales IA. J1 puede usar
  teclado o mando; J2 requiere un mando libre. Ambos eligen piloto único y un
  vehículo de la colección desbloqueada por J1.
- **Red local** conecta hasta cuatro PCs Windows/Linux y completa la parrilla
  de ocho con IA del anfitrión. Admite descubrimiento o IP/puerto manual.

Cada combinación de Copa y dificultad conserva sólo su mejor medalla. Bronce,
Plata y Oro aportan 1, 2 y 3 puntos de carrera, multiplicados ×1 en Relajada,
×2 en Competitiva y ×3 en Experta. Repetir un resultado inferior no aumenta el
progreso; el máximo de la campaña es 126 puntos.

Sólo puede existir una Copa activa. Su vehículo, CC y dificultad quedan fijados
hasta completarla o abandonarla. El menú permite continuar desde la siguiente
carrera y solicita confirmación antes de reemplazarla por otra Copa.

Al terminar la tercera carrera, la celebración avanza por clasificación final,
medalla y recompensas. Una misma finalización puede entregar el premio de Copa
y uno o más hitos globales. Los vehículos obtenidos conservan la marca **Nuevo**
hasta inspeccionarlos en la galería. Las partidas de los esquemas 1–4 migran al
esquema 5 sin perder medallas, telemetría, vehículo equipado, premios vistos ni
una Copa activa.

## Perfil y preparación

**Perfil** resume carreras, victorias, podios, récords y colección. También
muestra los puntos de carrera, el siguiente hito y la mejor medalla por
dificultad de cada Copa, y abre el Garaje; el equipamiento sigue realizándose
exclusivamente desde la galería.

**Preparación** adapta su distribución al ancho disponible. En escritorio
separa evento, showroom y opciones; en pantallas compactas apila el contenido
en una vista desplazable y conserva las acciones al pie. CC y dificultad se
eligen mediante controles táctiles de al menos 48 px.

## Garaje y vehículos

El selector previo a una carrera y el **Garaje** del menú comparten la misma
galería y el mismo showroom 3D. La galería admite teclado, mando, toque,
deslizamiento y flechas laterales.

El Sedán está disponible explícitamente desde el inicio. Otros ocho vehículos
se obtienen con medallas de las cuatro Copas principales y cuatro más en los
hitos de 12, 30, 56 y 90 puntos. Pueden aparecer como **Equipado**,
**Disponible**, **Bloqueado** o **Nuevo**. Un vehículo bloqueado se puede
inspeccionar, pero no equipar. El panel compara velocidad, aceleración, manejo,
peso y miniturbo con el vehículo equipado.

## Editor de pistas

Godot incluye una pestaña principal llamada **Pistas**. No es necesario abrir
escenas, seleccionar nodos ni usar el Inspector:

1. Entrar en **Pistas** desde la barra superior del editor.
2. Abrir Costa Turbo o Circuito Jardín, o pulsar **Nueva**.
3. Seguir los cinco pasos: Configuración, Carretera, Atajos, Objetos y Revisar.
4. Dibujar desde el mapa aéreo y usar **Vista 3D** para comprobar el resultado.
5. Guardar el borrador, probarlo con el kart y publicarlo en el menú.

La carretera, las barreras y sus colisiones se regeneran automáticamente. Los
atajos, cajas y props creados desde el editor siguen la ruta mediante anclas
normalizadas; deshacer y rehacer restaura la carretera y sus dependencias como
una operación. Las escenas antiguas se reparan al abrirlas sin sobrescribirse
hasta pulsar **Guardar**.

## Selector de eventos

El menú principal conserva únicamente las acciones principales. Carrera rápida
y Contrarreloj abren una lista vertical desplazable con descripción, vueltas,
distancia, atajos, récord y plano automático de cada circuito. Las pistas
publicadas desde el editor aparecen automáticamente en **Mis pistas**, separadas
de las pistas oficiales. Una portada opcional puede sustituir el plano sin
cargar la pista 3D en el menú.

Copa abre un selector independiente alimentado por el catálogo de progresión.
Las Copas se ordenan por `sort_order`; las bloqueadas muestran su requisito y
el panel resume puntos actuales y próximo hito.

La guía completa para crear una pista, configurar atajos y registrar assets está
en [docs/track-editor.md](docs/track-editor.md).
La configuración, límites, puertos y modelo autoritativo del multijugador están
en [docs/multiplayer.md](docs/multiplayer.md).

## Controles

| Acción | Android | Teclado |
| --- | --- | --- |
| Dirección | Zona flotante: tocar y arrastrar | A / D |
| Acelerar | Automático | W |
| Frenar o reversa | FRENO | S |
| Derrapar | DERRAPE | Espacio |
| Usar objeto | OBJETO | E |
| Pausa | Botón `Ⅱ` | Escape |
| Recuperar kart | Automático | R |

En Android, los tres botones de acción están separados por prioridad: derrape
grande junto al pulgar derecho, objeto a su izquierda y freno encima. Al mantener
FRENO, la aceleración automática se suspende para permitir frenar o usar reversa.

## Ejecutar

1. Abrir el directorio con Godot 4.7.1.
2. Ejecutar la escena principal con `F6`/`F5`.
3. Para ejecutar la validación habitual sin interfaz:

   ```sh
   tools/run_tests.sh quick
   ```

En esta máquina, los ejemplos siguientes usan esta variable para abreviar el
binario de Godot:

```sh
GODOT_BIN=/home/mintriago/Godot_v4.7.1-stable_linux.x86_64
```

El runner asigna un directorio `user://` aislado y escribible a cada prueba.
Esto evita que la persistencia o la rotación de logs de una suite contaminen a
la siguiente. `quick` también abre sockets UDP locales para su host + tres
clientes LAN. Para ejecutar únicamente esa integración:

```sh
tools/run_lan_loopback.sh
```

Para usar otro binario:

```sh
GODOT_BIN=/ruta/a/Godot_v4.7.1-stable_linux.x86_64 \
  tools/run_tests.sh quick
```

La matriz completa de los doce circuitos, cuatro cilindradas, atajos y
aproximaciones queda reservada para la validación nocturna o previa a una beta:

```sh
tools/run_tests.sh exhaustive
```

Las dos pruebas largas también aceptan filtros para reproducir un caso:

```sh
"$GODOT_BIN" --headless --path . --script tests/shortcut_drive.gd -- \
  --track=dunas_doradas --cc=200 --shortcut=0 --approach=right
"$GODOT_BIN" --headless --path . --script tests/race_stability.gd -- \
  --track=nen_medianoche --cc=200
```

Para abrir directamente la carrera durante una captura o perfilado:

```sh
"$GODOT_BIN" --path . -- --auto-race
"$GODOT_BIN" --path . -- --auto-time-trial
```

## Exportar la beta

La versión actual es `1.3.0-beta.1`. El preset `Android` genera un APK ARM64
para Android 9 (API 28) o superior y declara target SDK 35. Los presets de
Linux y Windows generan ejecutables autocontenidos en `build/`.
Antes de exportar, configura el SDK de Android y
las plantillas de exportación **4.7.1** en el editor. También se requiere un JDK
completo compatible; esta beta se validó con JDK 21. Selecciónalo en
`Editor Settings > Export > Android`.

Las exportaciones de depuración para la beta se ejecutan con:

```sh
"$GODOT_BIN" --headless --path . --install-android-build-template \
  --export-debug Android build/android/michikart-xd.apk
"$GODOT_BIN" --headless --path . \
  --export-debug Linux build/linux/michikart-xd.x86_64
"$GODOT_BIN" --headless --path . \
  --export-debug Windows build/windows/michikart-xd.exe
```

Antes de distribuir, ejecutar `tools/run_tests.sh exhaustive`, comprobar una
partida nueva y una migrada, y verificar controles, audio y fluidez en cada
plataforma. La publicación en tiendas, firma de producción y metadatos
comerciales no forman parte de esta beta.

## Rendimiento

- El perfil **Medio** activa sombras y glow.
- El perfil **Bajo** desactiva ambos efectos.
- Pantalla dividida aplica automáticamente ese presupuesto a sus dos vistas sin
  cambiar el perfil guardado.
- El objetivo es 60 FPS en un dispositivo Android de gama media.

La identidad, la geometría de carretera y el código son originales. Algunos
props low-poly proceden de packs CC0 de Kenney y están documentados en
[assets/ASSETS.md](assets/ASSETS.md). El juego no utiliza personajes,
nombres, música ni recursos de Nintendo.
