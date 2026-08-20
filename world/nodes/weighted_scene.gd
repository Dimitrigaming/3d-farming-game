class_name WeightedScene
extends Resource

## One entry in NodePainter's scenes list. weight is relative, not a strict
## percentage -- 70/30 and 7/3 behave identically, since NodePainter
## normalizes by the total across all entries at pick time.
@export var scene: PackedScene
@export var weight: float = 1.0
## RockField-only: overrides the field's own hp export for just this variant
## (e.g. a boulder should take a lot more hits than a pebble in the same
## field). -1 means "use the field's default", not "0 HP".
@export var hp_override: int = -1
## RockField-only: same idea as hp_override, for drops_min/drops_max -- a
## boulder should also yield more stone than a pebble. -1 on either means
## "use the field's default" for that bound.
@export var drops_min_override: int = -1
@export var drops_max_override: int = -1
