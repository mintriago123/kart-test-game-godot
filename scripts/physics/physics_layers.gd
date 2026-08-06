class_name PhysicsLayers
extends RefCounted

const WORLD := 1 << 0
const KARTS := 1 << 1
const ITEM_BOXES := 1 << 2
const SHORTCUTS := 1 << 3
const MAIN_BARRIERS := 1 << 4
const SHORTCUT_BARRIERS := 1 << 5
const PROJECTILES := 1 << 6

const DRIVABLE_SURFACES := WORLD | SHORTCUTS
const BARRIERS := MAIN_BARRIERS | SHORTCUT_BARRIERS
