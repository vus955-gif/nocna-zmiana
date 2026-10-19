extends TestCase
## The dawn card: the night survived, the Dust carried and, on Floor I, the
## secrets found (tonight and in all) with the rewards claimed.

var screen: DawnScreen


func before_each() -> void:
	screen = DawnScreen.new()
	add_child(screen)


func test_the_card_without_secrets_reads_as_before() -> void:
	screen.play(3, 40)
	assert_true(screen.text().contains("Przetrwałeś noc 3."))
	assert_true(screen.text().contains("Pył przy sobie: 40"))
	assert_false(screen.text().contains("Sekrety"), "no secrets line for a level without them")
	assert_eq(screen.secrets_text(), "")


func test_the_card_counts_the_secrets_and_the_rewards() -> void:
	screen.play(3, 40, {"found": 7, "total": 27, "tonight": 2, "rewards": 5, "rewards_total": 27})
	assert_eq(screen.secrets_text(), "Sekrety: 7/27 (tej nocy +2) · nagrody 5/27")
	assert_true(screen.text().contains("Sekrety: 7/27"))
	screen.play(4, 10, {"found": 7, "total": 0})
	assert_eq(screen.secrets_text(), "", "a level with no secrets shows no line")
