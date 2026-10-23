class_name StoryVignettes
## What happened to the staff, told by things left lying about (plan
## docs/superpowers/plans/2026-10-21-opowiesc-muzeum.md, 2.2): one trail in
## each wing that ends somewhere that matters - a secret behind a wall, a
## cage on a rope, a haven that held. Each trail is a handful of props on
## the vignette_<wing>_<kind>[_<n>] markers of the story layer
## (src/level/floor1/zones/story.gd; StoryProps builds them) and ONE of them
## can be looked at (E: two short sentences on the card, no note to read).
## Texts: STORY_<WING>_WHO (who left it), _TITLE (the thing), _TEXT.
## Pure data.

const PREFIX := "vignette_"
## Wing -> the marker of the prop the guard can look at.
const KEY_PROPS := {
	&"egypt": &"vignette_egypt_toolbox",
	&"assyria": &"vignette_assyria_torch",
	&"greece": &"vignette_greece_basket",
	&"enlightenment": &"vignette_enlightenment_torch",
	&"asia": &"vignette_asia_hammer",
	&"americas": &"vignette_americas_clipboard",
}
## Wing -> the doorway its trail ends at: the serdab's cracked wall (a
## blast), the royal cage on its rope, the loft's hatch on its rope, the
## librarian's office (the haven that held), the vault chained from the hall,
## the stairs down to the boarded-up store.
const ENDS := {
	&"egypt": &"egypt_tombs_serdab",
	&"assyria": &"assyria_lions_cage",
	&"greece": &"greece_gallery_loft",
	&"enlightenment": &"enlightenment_library_librarian",
	&"asia": &"asia_armor_vault",
	&"americas": &"americas_stairs_north",
}
## Props hung on a wall (the marker on the wall's face, -Z out of it); the
## rest lie or stand on the floor.
const WALL_KINDS: Array[StringName] = [&"stethoscope", &"chalk_tally", &"chalk_cross"]


## [wing, kind] of a vignette marker (vignette_<wing>_<kind>[_<n>]); [&"", &""]
## for another marker.
static func parse(marker: StringName) -> Array[StringName]:
	var text := String(marker)
	if not text.begins_with(PREFIX):
		return [&"", &""]
	var rest := text.trim_prefix(PREFIX)
	for wing: StringName in KEY_PROPS:
		if rest.begins_with(String(wing) + "_"):
			var kind := rest.trim_prefix(String(wing) + "_")
			var parts := kind.rsplit("_", true, 1)
			if parts.size() == 2 and parts[1].is_valid_int():
				kind = parts[0]
			return [wing, StringName(kind)]
	return [&"", &""]


static func is_key(marker: StringName) -> bool:
	return KEY_PROPS.values().has(marker)


static func on_wall(kind: StringName) -> bool:
	return WALL_KINDS.has(kind)


static func who_key(wing: StringName) -> String:
	return "STORY_%s_WHO" % String(wing).to_upper()


static func title_key(wing: StringName) -> String:
	return "STORY_%s_TITLE" % String(wing).to_upper()


static func text_key(wing: StringName) -> String:
	return "STORY_%s_TEXT" % String(wing).to_upper()
