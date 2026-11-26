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


## A round white spot that fades out softly to its edge: the shape of a
## puff of smoke or a drop of spray.
static func soft_dot() -> GradientTexture2D:
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var dot := GradientTexture2D.new()
	dot.gradient = fade
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 64
	dot.height = 64
	return dot


## Skin: smooth, blended paint with no dark gaps, the way a portrait painter
## works a face, so that features stay readable.
static func skin(colour: Color) -> ShaderMaterial:
	var mat := material(colour, 0.06, 0.7)
	mat.set_shader_parameter("variation", 0.05)
	mat.set_shader_parameter("relief", 0.3)
	mat.set_shader_parameter("ground", 0.0)
	return mat


## A model that brings its own picture (texture): the picture gives the
## colours, and the brush strokes are laid lightly over it. The strokes are
## kept faint because on a body that bends they cannot follow the cloth.
static func textured(picture: Texture2D, wash: Color = Color(1.0, 1.0, 1.0)) -> ShaderMaterial:
	var mat := material(wash, 0.12, 0.75)
	mat.set_shader_parameter("picture", picture)
	mat.set_shader_parameter("has_picture", true)
	mat.set_shader_parameter("variation", 0.05)
	mat.set_shader_parameter("relief", 0.35)
	mat.set_shader_parameter("ground", 0.0)
	return mat


## Cloth: softer and less broken than wood or rock.
static func cloth(colour: Color) -> ShaderMaterial:
	var mat := material(colour, 0.12, 0.75)
	mat.set_shader_parameter("variation", 0.1)
	mat.set_shader_parameter("relief", 0.7)
	mat.set_shader_parameter("ground", 0.08)
	return mat
