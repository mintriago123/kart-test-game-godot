# Plan de refactor — Arquitectura del AI

Fecha: 2026-08-28
Estado: en ejecución

## Contexto

El AI de los rivales (`scripts/vehicles/ai_driver.gd`) creció a 603 líneas con responsabilidades mezcladas (conducción, sensores, evasión, drift, atajos, items, recovery, telemetry). El tuning está en magic numbers sueltos por el código y la dificultad se aplica como un único `apply_to(AiProfile)` que no separa la "personalidad del rival" del "balance de la sesión".

## Objetivos

1. **Data-driven tuning** — todos los magic numbers extraídos a un recurso `AiTuning.tres`.
2. **Separación personalidad/buff** — `AiPersonality` (datos del rival) vs `DifficultyBuff` (multiplicadores por dificultad).
3. **Subsistemas testeables** — `scripts/ai/` con un script por responsabilidad.
4. **Compatibilidad** — los `.tres` existentes de rivales y dificultades siguen funcionando sin cambios.
5. **Tests para lógica crítica** — safe_speed, item_decision, drift_decision.

## Fases

### Fase 0 — `AiTuning.tres`

Recurso nuevo con todos los magic numbers del AI.

- `scripts/data/ai_tuning.gd` — clase con `@export` agrupados (steering, speed planning, safe speed, sensors, wall contact, section variation, drift decision, racer avoidance, barrier steering, wall recovery, strategy tick, debug).
- `tuning/ai_tuning.tres` — recurso con los valores actuales como defaults.

Compatibilidad: el AI usa valores por defecto si no se pasa un `AiTuning`. No rompe nada.

### Fase 1 — Split `AiPersonality` + `DifficultyBuff`

- `scripts/data/ai_personality.gd` — precision, aggression, drift_usage, risk_tolerance, shortcut_probability, item_efficiency, reaction_time.
- `scripts/data/difficulty_buff.gd` — response_multiplier, lookahead_max_multiplier, wall_recovery_speed_ratio, launch_aggression_bias, avoidance_weight_max, top_speed_bias.
- `scripts/data/ai_profile.gd` — pasa a ser wrapper con `@export` (getters/setters) que delegan a `personality` + `buff`. **Mantiene compat con `.tres` existentes** porque los `@export` siguen funcionando como antes.
- `scripts/data/difficulty_definition.gd` — `apply_to` ahora produce un `AiProfile` con `personality` y `buff` separados. `top_speed_bias` migra a `buff`. Los nuevos campos tienen defaults neutros.

### Fase 2 — Subsistemas en `scripts/ai/`

Carpeta nueva con un script por responsabilidad:

- `scripts/ai/ai_steering_controller.gd` — `compute_line_steer`, `apply_barrier_steering`, `apply_racer_avoidance`, `update_smoothed_steer`.
- `scripts/ai/ai_speed_planner.gd` — `compute_lookahead`, `compute_safe_speed`, `compute_target_speed`, `update_throttle`, `update_brake`. **`safe_speed` partido en line_limit + turn_limit + lateral_limit + barrier_limit.**
- `scripts/ai/ai_drift_decision.gd` — `update` con commit/cancel según umbrales del tuning.
- `scripts/ai/ai_shortcut_planner.gd` — `select_branch` (decisión de atajos).
- `scripts/ai/ai_item_decision.gd` — `should_use`, `notify_item_used`, **cooldown por tipo de item** (no global).
- `scripts/ai/ai_recovery_state.gd` — máquina de estados DRIVING / AVOIDING_WALL / WALL_RECOVERY + grace/grace timers.
- `scripts/ai/ai_sensors.gd` — sense barriers (3-ray cast).
- `scripts/ai/perceived_frame.gd` — struct simple con los datos de percepción.
- `scripts/ai/ai_decision.gd` — struct simple con throttle/brake/steer/drift/use_item.

`scripts/vehicles/ai_driver.gd` pasa de 603 a ~250 líneas. Queda como orquestador que:
1. Recibe dependencias en `setup()`.
2. Ejecuta `_perceive_frame` → `_decide` → `_actuate` cada frame.

### Fase 5 — Strategy @ 10 Hz

Decisiones de orden superior (atajos, variación de sección, decisiones de item que no dependen de sensores inmediatos) corren a 10 Hz en lugar de cada frame.

Táctica (steer, throttle, brake, drift) sigue cada frame.

Configurable vía `AiTuning.strategy_tick_hz`.

### Fase 6 — Cooldown por tipo de item

`AiItemDecision` mantiene `Dictionary[StringName item_id -> seconds_remaining]`. Cada tipo de item tiene su propio cooldown, no global.

### Fase 7 — `aggression` desaturation

`aggression` se usa solo para `safe_speed * lerpf(0.96, 1.0, aggression)`. El overdrive real va por `top_speed_bias` (en `DifficultyBuff`), que puede pasar de 1.0 sin saturar.

Resultado: Coral/Nube en experta pueden tener `top_speed_bias = 0.06` (6% real sobre safe_speed), no solo aggression = 1.0 saturado.

### Fase 8 — `_legacy_drive` reducido

`_legacy_drive` ya no duplica toda la lógica. Se reduce a un fallback mínimo que va recto a media velocidad si no hay `RacingLine`. Si todas las pistas tienen `RacingLine`, este path nunca se ejecuta.

### Fase 9 — Debug logging opcional

`AiTuning.enable_debug_logging` activa un log periódico del estado del AI (velocidad, target, steer, item). Útil para dev builds.

## Archivos

### Nuevos (13)

- `scripts/data/ai_tuning.gd`
- `scripts/data/ai_personality.gd`
- `scripts/data/difficulty_buff.gd`
- `scripts/ai/ai_steering_controller.gd`
- `scripts/ai/ai_speed_planner.gd`
- `scripts/ai/ai_drift_decision.gd`
- `scripts/ai/ai_shortcut_planner.gd`
- `scripts/ai/ai_item_decision.gd`
- `scripts/ai/ai_recovery_state.gd`
- `scripts/ai/ai_sensors.gd`
- `scripts/ai/perceived_frame.gd`
- `scripts/ai/ai_decision.gd`
- `tuning/ai_tuning.tres`

### Modificados (6)

- `scripts/data/ai_profile.gd` (wrapper con @export para compat)
- `scripts/data/difficulty_definition.gd` (`apply_to` actualizado)
- `scripts/vehicles/ai_driver.gd` (orquestador delgado)
- `scripts/game/race_world.gd` (sin cambios funcionales, ajuste de tipos)
- `progression/difficulties/expert.tres` (sin cambios — defaults neutros)
- `progression/racers/*.tres` (sin cambios — @export sigue funcionando)

### Tests nuevos (5)

- `tests/unit/ai/ai_tuning_sanity.gd`
- `tests/unit/ai/difficulty_buff_test.gd`
- `tests/unit/ai/ai_speed_planner_test.gd`
- `tests/unit/ai/ai_drift_decision_test.gd`
- `tests/unit/ai/ai_item_decision_test.gd`

## Orden de ejecución

1. Fase 0: AiTuning
2. Fase 1: Personality/Buff split
3. Fase 2: Subsistemas
4. Fase 5: Strategy @ 10 Hz
5. Fase 6: Items por tipo
6. Fase 7: Aggression desaturation
7. Fase 8: legacy fallback
8. Fase 9: Debug logging
9. Tests
10. Validación final con test suite completo

## Estimación

~12h total. Bajo riesgo, todas las fases reversibles.
