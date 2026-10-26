extends Node
## Event-only interaction cues. Hover changes are debounced; no per-frame playback.
const Reference=preload("res://scripts/reference_audio_099.gd")
var game:Node
var previous_owned:Array=[]
var previous_targets:Dictionary={}
var next_hover_ms:=0
static func play_ui(owner:Node,kind:String)->AudioStreamPlayer:
	var sound:AudioStreamWAV=Reference.generic(kind,0)
	if sound==null:return null
	var voice:=AudioStreamPlayer.new();voice.bus="Music" if kind=="game_start_music" else "SFX";voice.volume_db=-10 if kind=="game_start_music" else -8
	if kind=="game_start_music" and "game" in owner and is_instance_valid(owner.game.music):voice.volume_db+=linear_to_db(maxf(.0001,owner.game.music.get_volume()))
	voice.stream=sound;owner.add_child(voice);voice.finished.connect(voice.queue_free);voice.play();return voice
static func play_at(owner:Node,kind:String,point:Vector3)->AudioStreamPlayer3D:
	var sound:AudioStreamWAV=Reference.generic(kind,0)
	if sound==null:return null
	var voice:=AudioStreamPlayer3D.new();voice.bus="SFX";voice.volume_db=-12;voice.max_distance=8;voice.stream=sound;owner.add_child(voice);voice.global_position=point;voice.finished.connect(voice.queue_free);voice.play();return voice
func setup(value:Node)->void:
	game=value;process_priority=125;previous_owned=game.weapon_inventory.owned.duplicate();game.weapon_inventory.changed.connect(_inventory_changed)
func _inventory_changed()->void:
	var added:=false
	for index in game.weapon_inventory.owned:
		if index not in previous_owned:added=true;break
	previous_owned=game.weapon_inventory.owned.duplicate()
	if added and game.player.input_enabled and not game.front_end_active:play_at(self,"item_pickup",game.player.get_weapon_hand().global_position)
func _process(_delta:float)->void:
	if not game.player.input_enabled or game.paused or game.front_end_active:
		previous_targets.clear();return
	var current:Dictionary={}
	for system in [game.weapon_inventory,game.ammo_pickups,game.field_consumables]:
		for ring in system.aim_rings.values():
			if not is_instance_valid(ring) or not ring.is_visible_in_tree():continue
			var title:=""
			for label in ring.find_children("*","Label3D",true,false):title+=label.text
			var key:=str(ring.get_instance_id());current[key]=title
			if previous_targets.get(key,"")!=title and not title.is_empty() and Time.get_ticks_msec()>=next_hover_ms:
				play_at(self,"item_highlight",ring.global_position);next_hover_ms=Time.get_ticks_msec()+150
	previous_targets=current
