class_name Atmosphere
extends Node3D
## Sky, sun, clouds and air. It owns the lights and the fog and changes them
## with the weather and the time of day. Other systems read `horizon` to
## colour themselves to match (the sea mirrors it).

const SKY_SHADER := preload("res://shaders/sky.gdshader")

const FAIR_ZENITH := Color(0.13, 0.36, 0.78)
const FAIR_HORIZON := Color(0.62, 0.80, 0.95)
const FOUL_ZENITH := Color(0.08, 0.10, 0.13)
const FOUL_HORIZON := Color(0.34, 0.36, 0.37)
const LOW_SUN := Color(1.0, 0.88, 0.70)
const HIGH_SUN := Color(1.0, 0.97, 0.90)

var horizon := FAIR_HORIZON  ## the colour of the sky where it meets the sea
var shelter: float = 0.0     ## 0 = out on deck, 1 = below, where little daylight reaches

var _sky_mat: ShaderMaterial
var _env: Environment
var _sun: DirectionalLight3D
var _cloud_time: float = 0.0


func _ready() -> void:
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	# The clouds move, so the sky is redrawn as it changes.
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_REALTIME

	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 0.8
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_white = 6.0
	# Whites that glow: bright things bleed light into what is around them.
	_env.glow_enabled = true
	_env.glow_intensity = 0.45
	_env.glow_bloom = 0.05
	_env.glow_hdr_threshold = 0.9
	# Distance haze, plus fog with real depth that catches the sunlight.
	_env.fog_enabled = true
	_env.fog_density = 0.00012
	_env.fog_sky_affect = 0.15       # haze on the sea and land, but a clear sky
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_density = 0.0003
	_env.volumetric_fog_sky_affect = 0.1
	_env.volumetric_fog_anisotropy = 0.7
	_env.volumetric_fog_length = 500.0
	_env.volumetric_fog_ambient_inject = 0.4

	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)

	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	# Shadows are kept close to the ship so that they are finely drawn, and
	# given a soft edge like the sun's own, which hides any stepping.
	_sun.directional_shadow_max_distance = 110.0
	_sun.light_angular_distance = 0.8
	_sun.shadow_blur = 1.5
	_sun.rotation_degrees = Vector3(-27.0, -125.0, 0.0)
	_sun.light_volumetric_fog_energy = 0.7
	add_child(_sun)
	apply(0.0, 1.0, 90.0, 0.0, 0.0)


## Sets the look of the day.
##   gloom       0 = bright, 1 = squall dark
##   visibility  1 = clear, lower = thick
##   wind_from   compass degrees, to drive the clouds
##   day_part    how far through the ship's day, 0..1
func apply(gloom: float, visibility: float, wind_from: float, day_part: float,
		delta: float) -> void:
	_cloud_time += delta * (1.0 + 2.0 * gloom)

	# The sun itself stays where it is: a sun that creeps across the sky
	# makes every shadow on deck crawl. Only its colour changes through the
	# day, warmer and cooler by turns.
	var height := 0.5 + 0.5 * sin(TAU * day_part)
	_sun.light_color = LOW_SUN.lerp(HIGH_SUN, height)
	_sun.light_energy = lerpf(1.6, 0.25, gloom)

	horizon = FAIR_HORIZON.lerp(LOW_SUN, 0.08 * (1.0 - height)).lerp(FOUL_HORIZON, gloom)
	var blow := Compass.to_vector(wind_from) * -0.013
	_sky_mat.set_shader_parameter("zenith", FAIR_ZENITH.lerp(FOUL_ZENITH, gloom))
	_sky_mat.set_shader_parameter("horizon", horizon)
	_sky_mat.set_shader_parameter("coverage", lerpf(0.45, 0.92, gloom))
	_sky_mat.set_shader_parameter("cloud_shade",
			Color(0.55, 0.61, 0.74).lerp(Color(0.14, 0.15, 0.18), gloom))
	_sky_mat.set_shader_parameter("cloud_lit",
			Color(1.0, 0.98, 0.94).lerp(Color(0.45, 0.46, 0.48), gloom))
	_sky_mat.set_shader_parameter("drift", blow)
	_sky_mat.set_shader_parameter("cloud_time", _cloud_time)

	var thick := clampf(1.0 - visibility, 0.0, 1.0)
	_env.fog_light_color = horizon
	_env.fog_density = lerpf(0.00012, 0.005, thick)
	_env.fog_sky_affect = lerpf(0.15, 1.0, thick)
	_env.volumetric_fog_albedo = horizon.lerp(Color(1.0, 1.0, 1.0), 0.3)
	_env.volumetric_fog_density = lerpf(0.0003, 0.014, thick) * (1.0 - 0.8 * shelter)
	_env.volumetric_fog_sky_affect = lerpf(0.1, 1.0, thick)
	_env.ambient_light_energy = lerpf(0.8, 0.1, shelter)
