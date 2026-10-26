extends SceneTree
var rows:Array=[]
const OLD_UMP={"one":{"samples_pitch_yaw_deg":[[0.0,0.0],[0.387244944306711,-0.044361879172028926],[0.774489888613422,-0.08872375834405785],[1.4041264515262113,-0.17577430866285698],[2.1145602206410268,-0.27705441603057956],[2.790849753456244,-0.35496791934673805],[3.4329950499718627,-0.4095148186113325],[4.06819141465436,-0.461471718882338],[4.6825409838374945,-0.505658622172577],[5.296890553020629,-0.5498455254628158],[5.886971960144975,-0.5820885176977375],[6.47705336726932,-0.6143315099326592],[7.031464773597982,-0.6527444501913724],[7.573986179661417,-0.6932140397913494],[8.105882787533973,-0.7262484075799265],[8.627154597215656,-0.7518475535571039],[9.140004776501922,-0.7779202894340104],[9.62759006460194,-0.8054137950101048],[10.115175352701957,-0.8329073005861991],[10.527396628707496,-0.875282774594034],[10.939617904713035,-0.917658248601869],[11.316569530399423,-0.9491838772031921],[11.68176460597943,-0.9770928906690114],[11.961651621447054,-1.0862952189758643],[12.156230576802294,-1.2767908621237511],[12.427266414729775,-1.4049893546958132],[12.92767290037398,-1.346296395540399],[13.428079386018183,-1.2876034363849849]],"source_case":"ump_one","source_frame":"unpublished-analysis-frame","source_sha256":"b7a5fae80ed8c79c93a9b2dae555cc52acc1aec0618b9ba35aa0575c3251fb9b","component_count":13,"component_centers_px":[[1135.7777777777778,530.8055555555555],[1133.7317073170732,513.219512195122],[1129.0645161290322,481.06451612903226],[1126.5531914893618,452.0851063829787],[1124.52,424.4],[1123.037037037037,397.81481481481484],[1121.1764705882354,373.3529411764706],[1120.0,349.8103448275862],[1118.7368421052631,327.7368421052632],[1116.7906976744187,309.0232558139535],[1115.5094339622642,292.39622641509436],[1106.774193548387,283.51612903225805],[1109.4637223974764,260.602523659306]],"camera_K_conditional":{"f":1147.17,"cx":957.71,"cy":419.02},"order":"INFERRED bottom-to-top spatial envelope; resampled component index to runtime capacity, not recovered individual shots","limits":["Partial merged clouds, wrist/spread and uncorrected late-view plane/roll; experimental best fit, not intrinsic reconstruction.","Equal component-index resampling invents missing shot placement explicitly; original magazine/rate unchanged."]},"two":{"samples_pitch_yaw_deg":[[0.0,0.0],[0.20026189124902327,-0.034588882281763225],[0.40052378249804654,-0.06917776456352645],[0.6607964624345057,-0.09267344573588923],[0.9710781329438283,-0.10692479265041833],[1.2800436794597274,-0.12315314916691761],[1.5758479860413943,-0.1591516017031189],[1.8716522926230612,-0.1951500542393202],[2.1690991400342163,-0.21793554531184772],[2.467484582205079,-0.23317077269084732],[2.7653708131722023,-0.25122652942188206],[3.061010593722502,-0.28197466823707495],[3.3566503742728013,-0.3127228070522679],[3.6152994008683423,-0.33363128527248087],[3.8600768947308484,-0.35084989076957634],[4.098676274017896,-0.36202462924510365],[4.320800681103719,-0.3570823889964489],[4.542925088189543,-0.3521401487477942],[4.767750220275813,-0.3740960428944904],[4.993175513473295,-0.4020293002401535],[5.210198477557582,-0.42522246010558423],[5.412517365693781,-0.44012044938060846],[5.61483625382998,-0.45501843865563263],[5.7630028160118085,-0.46193943661592696],[5.905754145598199,-0.4680627354447482],[6.13056884491755,-0.518167563956492],[6.453859587916453,-0.6210502280877425],[6.777150330915356,-0.7239328922189934]],"source_case":"ump_two","source_frame":"unpublished-analysis-frame","source_sha256":"50b8611a311015bb1600c0bbef7230443cc045412278fd845dda3b1b803d3ce5","component_count":12,"component_centers_px":[[805.4848484848485,514.2424242424242],[803.7547169811321,504.33962264150944],[803.0416666666666,489.0208333333333],[801.24,474.44],[800.4772727272727,459.75],[798.9375,445.2083333333333],[798.075,433.175],[798.3225806451613,422.258064516129],[796.9230769230769,411.1794871794872],[796.1764705882352,401.2352941176471],[795.8695652173913,394.2173913043478],[790.7095588235294,378.31617647058823]],"camera_K_conditional":{"f":1147.17,"cx":957.71,"cy":419.02},"order":"INFERRED bottom-to-top spatial envelope; resampled component index to runtime capacity, not recovered individual shots","limits":["Partial merged clouds, wrist/spread and uncorrected late-view plane/roll; experimental best fit, not intrinsic reconstruction.","Equal component-index resampling invents missing shot placement explicitly; original magazine/rate unchanged."]}}
var new_ump:Dictionary={}
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
 new_ump=load("res://scripts/recoil_endpoint_experiment.gd").manifest().profiles.ump.duplicate(true)
 var actor=load("res://scripts/player.gd").new();root.add_child(actor);actor.setup(false);actor.set_process(false);actor.set_physics_process(false)
 actor.get_view_camera().global_transform=Transform3D.IDENTITY
 var rack=load("res://scripts/weapon_rack.gd").new();root.add_child(rack);rack.setup(actor);rack.set_process(false)
 wall=StaticBody3D.new();wall.collision_layer=524288;wall.collision_mask=0;root.add_child(wall);wall.position=Vector3(0,0,-10)
 var col:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1000,1000,.1);col.shape=box;wall.add_child(col)
 await physics_frame
 for motion in ["fixed","dynamic"]:
  for hz in [72,90,120,240]:
   for index in [0,3,6,8,17,18]:
    for held in [false,true]:
     if index==11 and held:continue
     for experiment in [false,true]:
      ProjectSettings.set_setting("ashfall/recoil_endpoint_experiments",true)
      load("res://scripts/recoil_endpoint_experiment.gd").manifest().profiles.ump=new_ump.duplicate(true) if experiment else OLD_UMP.duplicate(true)
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
 load("res://scripts/recoil_endpoint_experiment.gd").manifest().profiles.ump=new_ump.duplicate(true)
 for row in rows:
  if row.weapon=="ump" and row.experiment and row.motion=="fixed":
   if abs(row.shots[11].pitch_yaw_deg[1])>.001:failures.append("early section not vertical")
   if row.shots[19].pitch_yaw_deg[1]<=0:failures.append("middle section not right")
   if row.shots[27].pitch_yaw_deg[1]>=0:failures.append("late section not left")
 # Toggle must have no effect on protected actual rays, cadence or wall impacts.
 for i in range(0,rows.size(),2):
  if rows[i].weapon in ["cx4","mk18","m60","mp5","mp9"]:
   if JSON.stringify(rows[i].shots)!=JSON.stringify(rows[i+1].shots):failures.append("protected trace mismatch "+rows[i].weapon+" "+str(rows[i].hz)+" "+rows[i].motion)
 var path:=OS.get_environment("UMP072_OUTPUT")
 if path.is_empty():path="user://recoil-endpoint-071.json"
 var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify({"protocol":"Actual production fire signals intersect physics wall at z=-9.95 front face, fixed camera/held condition, same game cadence both toggles. Source distance unknown: later overlay uses angular projection, not asserted physical source scale.","runs":rows,"failures":failures},"\t"));f.close()
 rack.shutdown();rack.queue_free();actor.queue_free();wall.queue_free()
 await process_frame
 await create_timer(.25).timeout
 print("RESULT UMP072 runs=",rows.size()," failures=",failures.size());quit(0 if failures.is_empty() else 1)

