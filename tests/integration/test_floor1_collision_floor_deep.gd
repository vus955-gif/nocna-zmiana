extends "res://tests/integration/test_floor1_collision_floor.gd"
## The deep variant of test_floor1_collision_floor: the lattice every
## metre (about 21 000 points, 0.8 million steps of the guard, about a
## minute): bash tools/run_tests.sh --filter=deep.


func spacing() -> float:
	return 1.0
