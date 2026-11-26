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


## Skin: smooth, blended paint with no dark gaps, the way a portrait painter
## works a face, so that features stay readable.
static func skin(colour: Color) -> ShaderMaterial:
	var mat := material(colour, 0.06, 0.7)
	mat.set_shader_parameter("variation", 0.05)
	mat.set_shader_parameter("relief", 0.3)
	mat.set_shader_parameter("ground", 0.0)
	return mat


## Cloth: softer and less broken than wood or rock.
static func cloth(colour: Color) -> ShaderMaterial:
	var mat := material(colour, 0.12, 0.75)
	mat.set_shader_parameter("variation", 0.1)
	mat.set_shader_parameter("relief", 0.7)
	mat.set_shader_parameter("ground", 0.08)
	return mat
