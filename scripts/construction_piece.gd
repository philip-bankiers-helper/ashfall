extends StaticBody3D
## Damageable original cover. Cosmetic shards never participate in physics.
signal destroyed(piece: StaticBody3D)
var max_health := 180.0
var health := 180.0
var broken := false
var visual: MeshInstance3D
var _flash := 0.0
static var _panel_albedo: ImageTexture
static var _panel_roughness: ImageTexture
static var _panel_emission: ImageTexture

func apply_panel_material(material: StandardMaterial3D) -> void:
	# The optional user-supplied crop replaces only the surface finish. The
	# procedural sheet remains a functional fallback, including lightweight mode.
	if ResourceLoader.exists("res://assets/materials/build_panel_user.png"):
		material.albedo_texture=load("res://assets/materials/build_panel_user.png")
		material.albedo_color=Color.WHITE;material.roughness=.78
		# BoxMesh has six faces packed3x2. Repeat one complete panel on each face.
		material.uv1_scale=Vector3(3,2,1);material.texture_repeat=true
		material.emission_enabled=false;material.emission=Color.BLACK
		return
	if _panel_albedo == null:
		var albedo := Image.create(256,256,true,Image.FORMAT_RGB8)
		var roughness := Image.create(256,256,true,Image.FORMAT_RGB8)
		var emission := Image.create(256,256,false,Image.FORMAT_RGB8)
		# Original neutral galvanized sheet: recessed seams, raised ribs, fasteners,
		# directional brushing and scattered scratches. No colored light strips.
		for y in 256:
			for x in 256:
				var u:=x%128;var v:=y%64
				var grain:=float((x*17+y*31+x*y*3)%29)/900.0
				var shade:=.43+grain+sin(float(x)*.35)*.008
				if u<3 or v<3:shade=.075+grain
				elif u==3 or v==3:shade=.62
				elif u in [15,16,111,112]:shade=.57
				elif u in [17,113]:shade=.25
				var bolt:=Vector2(float(u-8),float(v-8)).length()<3 or Vector2(float(u-119),float(v-55)).length()<3
				if bolt:shade=.67 if (u+v)%3 else .24
				if (y*7+x/11)%97==0 and u>21 and u<104:shade+=.12
				albedo.set_pixel(x,y,Color(shade,shade,shade))
				var rough:=.82 if u<4 or v<4 else (.36 if bolt else .61+grain)
				roughness.set_pixel(x,y,Color(rough,rough,rough))
		albedo.generate_mipmaps();roughness.generate_mipmaps()
		_panel_albedo = ImageTexture.create_from_image(albedo)
		_panel_roughness = ImageTexture.create_from_image(roughness)
		_panel_emission = ImageTexture.create_from_image(emission)
	material.albedo_color = Color(.9,.9,.9)
	material.albedo_texture = _panel_albedo
	material.roughness_texture = _panel_roughness
	material.emission_texture = _panel_emission
	material.emission_enabled = false
	material.emission = Color.BLACK
	material.emission_energy_multiplier = 0.5

func configure(hp: float, mesh: MeshInstance3D) -> void:
	max_health = maxf(hp, 1.0)
	health = max_health
	visual = mesh
	set_process(false)

func hit(damage: float, _point := Vector3.ZERO, _direction := Vector3.ZERO) -> void:
	if broken or not is_finite(damage) or damage <= 0.0:
		return
	health = maxf(0.0, health - damage)
	_flash = 0.12
	set_process(true)
	if health <= 0.0:
		_break_panel("damage")

func collapse()->void:
	_break_panel("support")

func _break_panel(reason:String)->void:
	if broken:return
	broken=true;set_meta("break_reason",reason)
	collision_layer=0;collision_mask=0;remove_from_group("climbable")
	if visual!=null:visual.visible=false
	destroyed.emit(self)
	queue_free()

func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	if visual != null and visual.material_override is StandardMaterial3D:
		var material := visual.material_override as StandardMaterial3D
		material.albedo_color = Color(.9,.9,.9).lerp(Color(.19,.19,.19), 1.0 - health / max_health)
		material.emission_enabled = _flash > 0.0
		material.emission = Color(1,.24,.05) if _flash > 0.0 else Color.BLACK
	if _flash <= 0.0:
		set_process(false)
