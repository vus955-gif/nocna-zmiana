class_name GuardianLooks
## The materials of the guardians' effects (beams, sinews of light, warning
## marks, shockwave rings), made in one place so the night's shader warm-up
## (ShaderWarmUp) can show the renderer one of each kind before a fight
## draws it for the first time. Every call makes a new material (effects
## animate their own colour and alpha); warm_set() gives one of each kind.


## Glowing, added to what is behind (light: a beam, a seam, a rim).
static func glow(color: Color, alpha: float, two_sided: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(color, alpha)
	if two_sided:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## A see-through shade laid over the floor (a shadow).
static func shade(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, alpha)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## One material of every kind above (for the shader warm-up).
static func warm_set() -> Array[Material]:
	return [glow(Color.WHITE, 0.5), glow(Color.WHITE, 0.5, true), shade(Color.BLACK, 0.5)]
