class_name Paint
extends RefCounted
## Makes materials that look painted in oils. Every solid thing in the
## world uses one of these, so the brush strokes sit on the objects
## themselves. If the mesh has colours of its own (per point, or per copy in
## a batch), they are multiplied in.

const SHADER := preload("res://shaders/painted.gdshader")


## `stroke` is the length of a brush stroke up close, in the object's units.
static func material(colour: Color, stroke: float = 0.3, roughness: float = 0.6) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("tint", colour)
	mat.set_shader_parameter("stroke", stroke)
	mat.set_shader_parameter("roughness", roughness)
	return mat
