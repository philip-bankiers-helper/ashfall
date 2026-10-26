extends SceneTree
var rows:Array=[]
var current:Dictionary={}
var current_shots:Array=[]
var wall:StaticBody3D
var elapsed:=0.0
var failures:Array=[]
func _initialize()->void:call_deferred("run")
func capture(origin:Vector3,direction:Vector3,_damage:float)->void:
 var query:=PhysicsRayQueryParameters3D.create(origin,origin+direction*2000.0,524288)
 var hit:=wall.get_world_3d().direct_space_state.intersect_ray(query)
 current_shots.append({"time":elapsed,"origin":[origin.x,origin.y,origin.z],"direction":[direction.x,direction.y,direction.z],"impact":[hit.position.x,hit.position.y,hit.position.z] if not hit.is_empty() else [],"pitch_yaw_deg":[rad_to_deg(asin(clampf(direction.y,-1,1))),rad_to_deg(atan2(direction.x,-direction.z))]})
func run()->void:
 var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
 actor.get_view_camera().global_transform=Transform3D.IDENTITY
 var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
 wall=StaticBody3D.new();wall.collision_layer=524288;wall.collision_mask=0;root.add_child(wall);wall.position=Vector3(0,0,-10)
 var col:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1000,1000,.1);col.shape=box;wall.add_child(col)
 await physics_frame
 for motion in ["fixed","dynamic"]:
  for hz in [72,90,120,240]:
   for index in [0,3,6,8,10,11,17,18,21,23]:
    for held in [false,true]:
     if index==11 and held:continue
     for experiment in [false,true]:
      ProjectSettings.set_setting("ashfall/recoil_endpoint_experiments",experiment)
      rack.selected=index;rack.is_holstered=false;rack._apply_selection()
      var parent=rack.weapons[index];parent.reset_weapon();parent.set_process(false)
      var guns:Array=parent.guns if index==11 else [parent]
      for gun in guns:
       gun.reset_weapon();gun.set_process(false);gun.set_physics_process(false);gun.supported=held;gun._requires_trigger_release=false
       if not gun.shot.is_connected(capture):gun.shot.connect(capture)
      current_shots=[]
      var capacity:int=guns[0].magazine_size
      var duration:float=float(capacity)*guns[0].fire_interval+1.0
      for step in range(ceili(duration*hz)):
       elapsed=float(step)/hz
       var pose:=Transform3D.IDENTITY
       if motion=="dynamic":
        pose.basis=Basis.from_euler(Vector3(deg_to_rad(.5*sin(elapsed*1.3)),deg_to_rad(sin(elapsed*1.7)),0))
        pose.origin=Vector3(.1*sin(elapsed*.9),.05*sin(elapsed*1.1),0)
       actor.get_view_camera().global_transform=pose
       for gun in guns:
        gun._process(0.0 if step==0 else 1.0/hz);gun.supported=held;gun.fire()
      var id:=str(guns[0].get_meta("reference_id",""))
      if current_shots.size()!=capacity*guns.size():failures.append("shot count "+id)
      for shot in current_shots:
       if shot.impact.is_empty():failures.append("wall miss "+id)
      if experiment and motion=="fixed" and id in ["ump","p90","akm","rfb","uzis"]:
       for n in current_shots.size():
        var endpoint:Vector2=load("res://scripts/recoil_endpoint_experiment.gd").sample(id,held,n/guns.size())
        var actual:Array=current_shots[n].pitch_yaw_deg
        if abs(float(actual[0])-endpoint.x)>.02:failures.append("emitted endpoint pitch "+id)
        if id!="uzis" and abs(float(actual[1])-endpoint.y)>.02:failures.append("emitted endpoint yaw "+id)
       if current_shots.size()>guns.size():
        var tail_a:Array=current_shots[-1].pitch_yaw_deg;var tail_b:Array=current_shots[-1-guns.size()].pitch_yaw_deg
        if Vector2(tail_a[0],tail_a[1]).distance_to(Vector2(tail_b[0],tail_b[1]))<.00001:failures.append("last emitted endpoints duplicated "+id)
      rows.append({"motion":motion,"weapon":id,"hz":hz,"supported":held,"experiment":experiment,"capacity":capacity,"hands":guns.size(),"shots":current_shots.duplicate(true)})
      for gun in guns:gun.shot.disconnect(capture)
 # Toggle must have no effect on protected actual rays, cadence or wall impacts.
 for i in range(0,rows.size(),2):
  if rows[i].weapon in ["cx4","mk18","m60","mp5","mp9"]:
   if JSON.stringify(rows[i].shots)!=JSON.stringify(rows[i+1].shots):failures.append("protected trace mismatch "+rows[i].weapon+" "+str(rows[i].hz)+" "+rows[i].motion)
 var path:=OS.get_environment("RECOIL071_OUTPUT")
 if path.is_empty():path="user://recoil-endpoint-071.json"
 var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify({"protocol":"Actual production fire signals intersect physics wall at z=-9.95 front face, fixed camera/held condition, same game cadence both toggles. Source distance unknown: later overlay uses angular projection, not asserted physical source scale.","runs":rows,"failures":failures},"\t"));f.close()
 rack.shutdown();rack.queue_free();actor.queue_free();wall.queue_free()
 await process_frame
 await create_timer(.25).timeout
 print("RESULT ENDPOINT071 runs=",rows.size()," failures=",failures.size());quit(0 if failures.is_empty() else 1)

