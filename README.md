# Coastal Karts

Prototipo original de carreras arcade para Android creado con Godot 4.7. Incluye una
pista costera low-poly de más de 400 metros, dos atajos, barreras continuas,
tres rivales, derrape con miniturbo y dos objetos.

## Controles

| Acción | Android | Teclado |
| --- | --- | --- |
| Dirección | Joystick virtual | A / D |
| Acelerar | GAS | W |
| Frenar o reversa | FRENO | S |
| Derrapar | DERRAPE | Espacio |
| Usar objeto | OBJETO | E |
| Pausa | Botón `Ⅱ` | Escape |
| Recuperar kart | Automático | R |

## Ejecutar

1. Abrir el directorio con Godot 4.7.
2. Ejecutar la escena principal con `F6`/`F5`.
3. Para la prueba sin interfaz, ejecutar:

   ```sh
   godot --headless --path . --script tests/headless_smoke.gd
   ```

La prueba prolongada de estabilidad de pista e IA se ejecuta con:

```sh
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
completo compatible (recomendado: JDK 17) en `Editor Settings > Export > Android`.
El proyecto está diseñado para orientación horizontal y Android 9 o superior.

La exportación por terminal se ejecuta con:

```sh
godot --headless --path . --export-debug Android build/coastal-karts-debug.apk
```

## Rendimiento

- El perfil **Medio** activa sombras y glow.
- El perfil **Bajo** desactiva ambos efectos.
- El objetivo es 60 FPS en un dispositivo Android de gama media.

Todo el arte geométrico y la identidad visual incluidos en este repositorio son
originales. El prototipo no utiliza personajes, nombres, música ni recursos de
Nintendo.
