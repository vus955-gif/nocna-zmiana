extends TestCase
## The owner's rule: every attack of an exhibit is telegraphed for at least
## 0.6 s - long enough for a human to read it and answer. The wax figure's
## chop, the wolf's and the raptor's pounce, the mummy's claws and the relief
## figures' blows used to be quicker (0.55, 0.45, 0.3, 0.55, 0.5).

const MIN_TELEGRAPH := 0.6


func test_every_exhibit_winds_up_for_at_least_0_6_s() -> void:
	for kind: GDScript in [WaxFigure, Wolf, Knight, Bust, Raptor, Portrait, Mummy, ScarabSwarm, Hoplite, ReliefWarrior, ReliefLion,
			FlyingBook, Totem, Jaguar, FuDog, SamuraiArmor]:
		var exhibit: Enemy = kind.new()
		assert_true(exhibit.brain.windup >= MIN_TELEGRAPH - 0.0001, "%s winds up for %.2f s" % [kind.get_global_name(), exhibit.brain.windup])
		exhibit.free()


func test_every_move_winds_up_for_at_least_0_6_s() -> void:
	var windups := {
		"mummy claws": MummyMoves.CLAW_WINDUP, "mummy lash": MummyMoves.LASH_WINDUP,
		"relief strike": ReliefMoves.STRIKE_WINDUP, "relief throw": ReliefMoves.THROW_WINDUP,
		"fu dog charge": FuDogMoves.CHARGE_WINDUP, "fu dog roar": FuDogMoves.ROAR_WINDUP, "fu dog paw": FuDogMoves.PAW_WINDUP,
		"jaguar": JaguarMoves.WINDUP, "book dive": FlyingBook.DIVE_WINDUP, "totem spit": Totem.SPIT_WINDUP,
		"samurai thrust": SamuraiArmor.THRUST_WINDUP,
	}
	for move: String in windups:
		assert_true(float(windups[move]) >= MIN_TELEGRAPH - 0.0001, "%s: %.2f s" % [move, windups[move]])
