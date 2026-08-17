class_name WeightedScene
extends Resource

## One entry in NodePainter's scenes list. weight is relative, not a strict
## percentage -- 70/30 and 7/3 behave identically, since NodePainter
## normalizes by the total across all entries at pick time.
@export var scene: PackedScene
@export var weight: float = 1.0
