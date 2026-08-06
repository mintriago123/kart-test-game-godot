# Coastal Karts

Prototipo original de carreras arcade para Android creado con Godot 4.7. Incluye
dos pistas seleccionables, tres atajos físicos, barreras continuas, assets
low-poly CC0, tres rivales, derrape con miniturbo y dos objetos.

## Editor de pistas

Godot incluye una pestaña principal llamada **Pistas**. No es necesario abrir
escenas, seleccionar nodos ni usar el Inspector:

1. Entrar en **Pistas** desde la barra superior del editor.
2. Abrir Costa Turbo o Circuito Jardín, o pulsar **Nueva**.
3. Seguir los cinco pasos: Configuración, Carretera, Atajos, Objetos y Revisar.
4. Dibujar desde el mapa aéreo y usar **Vista 3D** para comprobar el resultado.
5. Guardar el borrador, probarlo con el kart y publicarlo en el menú.

La carretera, las barreras y sus colisiones se regeneran automáticamente. El
editor permite deshacer cambios de ruta y conserva una recuperación temporal
de los borradores sin guardar.

## Selector de pistas

El menú principal conserva únicamente las acciones principales. **Jugar** abre
una pantalla desplazable con la descripción, vueltas, distancia, atajos, récord
y un plano automático de cada circuito. Las pistas publicadas desde el editor
aparecen automáticamente en **Mis pistas**, separadas de las pistas oficiales.
Una portada opcional puede sustituir el plano sin cargar la pista 3D en el menú.

La guía completa para crear una pista, configurar atajos y registrar assets está
en [docs/track-editor.md](docs/track-editor.md).

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

1. Abrir el directorio con Godot 4.7.
2. Ejecutar la escena principal con `F6`/`F5`.
3. Para la prueba integral sin interfaz, ejecutar:

   ```sh
   godot --headless --path . --script tests/headless_smoke.gd
   ```

Las pruebas específicas del sistema de pistas se ejecutan con:

```sh
godot --headless --path . --script tests/track_authoring.gd
godot --headless --path . --script tests/track_editor.gd
godot --headless --path . --script tests/track_minimap.gd
godot --headless --path . --script tests/shortcut_drive.gd
godot --headless --path . --script tests/race_stability.gd
```

Para abrir directamente la carrera durante una captura o perfilado:

```sh
godot --path . -- --auto-race
```

## Exportar a Android

El preset `Android` genera un APK ARM64 de desarrollo en
`build/coastal-karts-debug.apk`. Antes de exportar, configura el SDK de Android y
las plantillas de exportación **4.7.1** en el editor. También se requiere un JDK
completo compatible (configurado en este proyecto con JDK 21) en
`Editor Settings > Export > Android`.
El proyecto está diseñado para orientación horizontal y Android 9 o superior.

La exportación por terminal se ejecuta con:

```sh
godot --headless --path . --export-debug Android build/coastal-karts-debug.apk
```

## Rendimiento

- El perfil **Medio** activa sombras y glow.
- El perfil **Bajo** desactiva ambos efectos.
- El objetivo es 60 FPS en un dispositivo Android de gama media.

La identidad, la geometría de carretera y el código son originales. Algunos
props low-poly proceden de packs CC0 de Kenney y están documentados en
[assets/ASSETS.md](assets/ASSETS.md). El prototipo no utiliza personajes,
nombres, música ni recursos de Nintendo.
