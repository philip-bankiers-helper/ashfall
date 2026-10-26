extends "res://tests/matador_models_064.gd"
## Independent cross-release regression. The203-record golden model was captured
## from the verified frozen063 embedded PCK, not from a rebuilt064 source tree.
func run()->void:
	var frozen:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/uzi_frozen063.json"))
	var prior:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/uzi_control064.json"))
	check(frozen.capture_kind=="frozen063" and frozen.project_version=="0.6.3" and frozen.source_package_sha256=="9CDF19B74106CEB2D74C05A7559362A905B0D92EF9F99B5D375AD9385DBEBEB1","golden Uzi fixture names the authoritative frozen063 embedded package")
	check(frozen.uzi_mesh_material_records.size()==203 and prior.uzi_mesh_material_records.size()==251 and frozen.uzi_fingerprint!=prior.uzi_fingerprint,"cross-release baseline detects the inherited064Uzi regression instead of preserving its251-record state")
	var actor:=make_actor();var uzis=make_pair(actor,false);var records:=mesh_records(uzis);var fingerprint:=hash_bytes(var_to_bytes(records))
	check(fingerprint==frozen.uzi_fingerprint and records.size()==203,"entire actual dual Uzi canonical geometry/material/texture/transform fingerprint exactly matches frozen063 PCK")
	check(fingerprint!=prior.uzi_fingerprint,"restored Uzi does not retain pre-fix064UMP additions")
	check(snapshots_match(protected_snapshot(uzis),frozen.uzi_protected),"both restored Uzi bore, reload, spin, markers, ammunition, timing and handling snapshots match frozen063")
	check(uzis.find_children("CompactManufacture064","Node3D",true,false).is_empty(),"all actual Uzi and canonical icon copies exclude the UMP064 manufacture root")
	for i in 2:
		var gun=uzis.guns[i]
		check(gun.spin_root.has_node("OriginalUziReceiverDetail063") and gun.magazine.has_node("OriginalUziMagazineDetail063") and gun.bolt.has_node("OriginalUziChargingDetail063") and gun.firing_carrier.has_node("OriginalUziCarrierDetail063"),"Uzi hand"+str(i)+" retains its four distinctive063 detail owners")
		check(not gun.has_meta("_paired_uzi_visual_063"),"Uzi hand"+str(i)+" temporary construction option removed after build")
	var ump=load("res://scripts/compact_smg.gd").new();root.add_child(ump);ump.setup(actor,false);ump.set_process(false);load("res://scripts/arsenal_data.gd").apply(ump,6)
	check(ump.model.has_node("AggressorBody") and ump.magazine.name=="DetachableAggressorMagazine","standalone UMP uses requested uploaded model and independent magazine")
	check(not ump.model.has_node("CompactManufacture064") and not ump.has_meta("_paired_uzi_visual_063"),"uploaded UMP excludes old finish while paired compatibility remains isolated")
	var matadors=make_pair(actor,true)
	check(hash_bytes(var_to_bytes(mesh_records(matadors)))==prior.matador_fingerprint,"complete064Matador geometry/material/texture fingerprint including hidden/canonical states remains unchanged")
	check(snapshots_match(protected_snapshot(matadors),prior.matador_protected),"Matador handling, shot origin, markers, reload, spin and capacities remain current064")
	for i in 2:check(matadors.guns[i].spin_root.has_node("MatadorManufacture064") and not matadors.guns[i].has_meta("_paired_uzi_visual_063"),"Matador hand"+str(i)+" keeps indexed064 manufacture and uses its current construction path")
	check(uzis.guns[0].magazine_size==20 and uzis.guns[1].magazine_size==20 and matadors.guns[0].magazine_size==8 and matadors.guns[1].magazine_size==8,"independent Uzi20/Matador8 capacities are unchanged")
	print("UZI_PRESERVATION064_FINGERPRINT restored=",fingerprint," frozen063=",frozen.uzi_fingerprint," prefixed064=",prior.uzi_fingerprint," records=",records.size())
	uzis.shutdown();ump.shutdown();matadors.shutdown();uzis.free();ump.free();matadors.free();actor.free();await process_frame;OS.delay_msec(180);await process_frame
	print("UZI_PRESERVATION_064 checks=",checks," failures=",failures," cpu_only=true controller_actions=false rendered=false")
	quit(failures)
