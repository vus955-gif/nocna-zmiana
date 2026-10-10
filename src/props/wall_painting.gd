class_name WallPainting
extends StaticBody3D
## An ordinary framed painting on the gallery wall: with a portrait id
## exactly what a sleeping Portrait of that id looks like (the same face,
## its eyes looking straight out), but it never wakes; with one of
## PaintingArt.SCENE_IDS a landscape or still life (no eyes). Shots hit it
## like the wall (it is level geometry). The level mixes these with real
## Portraits. The Blender "portrait" model when there is one
## (PaintingArt.model), else the greybox (PaintingArt.build).
##
## Place with create(transform, painting_id): the origin is the middle of
## the canvas on the wall surface, -Z faces the room.

var painting_id: StringName = &""
## Named parts: frame, canvas, eyes (model) or the greybox's parts.
var parts: Dictionary = {}
## The painting model (null: greybox).
var model: Node3D = null


static func create(at: Transform3D, id: StringName) -> WallPainting:
	var painting := WallPainting.new()
	painting.transform = at
	painting.painting_id = id
	painting.name = "Painting_%s" % id
	return painting


func _init() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0


func _ready() -> void:
	model = PaintingArt.model(painting_id)
	var outer := PaintingArt.CANVAS_SIZE + Vector2.ONE * PaintingArt.FRAME_WIDTH * 2.0
	var depth := PaintingArt.DEPTH
	if model != null:
		model.name = "Model"
		add_child(model)
		parts = ArtLibrary.parts(model)
		outer = PaintingArt.MODEL_OUTER
		depth = PaintingArt.MODEL_DEPTH
	else:
		parts = PaintingArt.build(self, painting_id)
	var shape := BoxShape3D.new()
	shape.size = Vector3(outer.x, outer.y, depth)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0.0, 0.0, -depth * 0.5)
	add_child(collider)
