class_name VoiceRules
extends RefCounted
## Does a line's rule (data/voice/lines.json) fit an event's payload? Pure.
## A condition absent from the rule does not filter; a payload without the
## field fails rules that ask for it (except "speaker", which only filters
## when the payload names one — the death comment's turn).


static func matches(rule: Dictionary, payload: Dictionary) -> bool:
	if rule.has("night") and int(rule.night) != int(payload.get("night", -1)):
		return false
	if rule.has("night_min") and int(payload.get("night", 0)) < int(rule.night_min):
		return false
	# kind: the coffee drunk in the café (espresso, large, special), the room
	# entered (haven) or the secret's reward (small, medium, great); room, gate
	# and modifier: the room entered, the gate opened, the night's modifier
	for field in ["zone", "guardian", "goal", "kind", "room", "gate", "modifier"]:
		if rule.has(field) and StringName(rule[field]) != StringName(payload.get(field, "")):
			return false
	# count: shards, exhibits destroyed, secrets found, the tiredness stage; hour: the clock's
	for field in ["count", "hour"]:
		if rule.has(field) and int(rule[field]) != int(payload.get(field, -1)):
			return false
	if payload.has("speaker") and StringName(rule.get("speaker", "")) != StringName(payload.speaker):
		return false
	return true
