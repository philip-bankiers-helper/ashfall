extends SceneTree
const Progress = preload("res://scripts/campaign_progress.gd")
var checks := 0
var failures := 0
var directory := ""
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
func raw(path: String, data: Variant):
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(data if data is String else JSON.stringify(data))
	file.close()
func fresh(label: String) -> String: return directory.path_join(label + ".json")
func quarantines(path: String) -> Array[String]:
	var found: Array[String] = []
	for filename in DirAccess.get_files_at(directory):
		if filename.begins_with(path.get_file()+".quarantine."): found.append(directory.path_join(filename))
	return found
func expanded(mission: String, chapter: int) -> Dictionary:
	return {"version":1,"campaign_id":Progress.CAMPAIGN_ID,"mission_id":mission,"chapter":chapter,"kills":5,"play_time":12.5}
func run():
	directory = ProjectSettings.globalize_path("res://../reports/campaign-progress-tests-" + str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(directory)
	var legacy := directory.path_join("campaign.json")
	for chapter in range(5):
		var old := {"version":1,"chapter":chapter,"kills":24,"play_time":99.5}
		raw(legacy, old)
		var before := FileAccess.get_sha256(legacy)
		var path := fresh("migration" + str(chapter))
		var result := Progress.read_progress(path, legacy)
		check(result.state == "migrated" and result.data.mission_id == Progress.LEGACY_MISSIONS[chapter] and result.source == legacy, "legacy %d maps by stable mission identity" % chapter)
		check(FileAccess.get_sha256(legacy) == before and not FileAccess.file_exists(path), "migration is in-memory and legacy bytes untouched")
	check(Progress.write_progress(legacy,{"mission_id":"relay","kills":0,"play_time":0}) != OK, "writer refuses legacy campaign.json")
	for index in range(7):
		var path := fresh("roundtrip" + str(index))
		var data := {"mission_id":Progress.MISSIONS[index],"kills":13,"play_time":14.25,"jammer_disabled":true,"gate_open":true}
		check(Progress.write_progress(path,data) == OK, "mission checkpoint writes " + data.mission_id)
		var result := Progress.read_progress(path,legacy)
		var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		check(result.state == "valid" and result.data.mission_id == data.mission_id and int(disk.chapter) == index and disk.campaign_id == Progress.CAMPAIGN_ID, "expanded identity authoritative and chapter matches")
		check(not disk.has("jammer_disabled") and not disk.has("gate_open") and result.data.size() == 3, "entry checkpoint excludes partial objective state")
	var path := fresh("recovery")
	check(Progress.write_progress(path,{"mission_id":"dam_crown","kills":18,"play_time":80}) == OK, "initial expanded snapshot")
	check(Progress.write_progress(path,{"mission_id":"spillway","kills":20,"play_time":90}) == OK, "replacement uses verified writer")
	raw(path,"{broken")
	var recovered := Progress.read_progress(path,legacy)
	check(recovered.state == "valid" and recovered.data.mission_id == "dam_crown" and recovered.source == path+".backup", "corrupt primary recovers verified expanded backup")
	check(Progress.read_progress(path,legacy,false).state == "invalid", "strict read rejects corrupt primary")
	raw(path+".pending",expanded("extraction",5))
	check(Progress.read_progress(path,legacy).source == path+".pending", "valid pending precedes backup")
	for suffix in Progress.SUFFIXES:
		var blocked := fresh("future" + str(Progress.SUFFIXES.find(suffix)))
		raw(blocked+suffix,{"version":2,"campaign_id":Progress.CAMPAIGN_ID,"mission_id":"relay"})
		check(Progress.read_progress(blocked,legacy).state == "blocked", "future artifact blocks migration " + suffix)
		check(Progress.write_progress(blocked,{"mission_id":"relay","kills":0,"play_time":0}) != OK, "future artifact cannot be downgraded " + suffix)
	for field in ["campaign_id","mission_id"]:
		var unknown := fresh(field)
		var data := expanded("relay",0)
		data[field] = "unknown-future"
		data.kills = "invalid"
		raw(unknown,data)
		check(Progress.read_progress(unknown,legacy).state == "blocked" and Progress.write_progress(unknown,{"mission_id":"relay","kills":0,"play_time":0}) != OK, "unknown identity blocks downgrade even with malformed stats " + field)
	for suffix in Progress.SUFFIXES:
		var malformed := fresh("malformed" + str(Progress.SUFFIXES.find(suffix)))
		raw(malformed+suffix,"{broken")
		check(Progress.read_progress(malformed,legacy).state == "invalid", "any expanded artifact prevents legacy fallback " + suffix)
	var mismatch := fresh("mismatch")
	raw(mismatch,expanded("extraction",3))
	check(Progress.read_progress(mismatch,legacy).state == "invalid", "numeric3 never silently reinterprets extraction as dam crown")
	raw(mismatch+".backup",expanded("uplink",2))
	var backup_hash := FileAccess.get_sha256(mismatch+".backup")
	check(Progress.read_progress(mismatch,legacy).data.mission_id == "uplink", "identity-index mismatch recovers valid same-campaign backup")
	var invalid_hash := FileAccess.get_sha256(mismatch)
	check(quarantines(mismatch).is_empty(), "backup read does not quarantine or mutate primary")
	check(Progress.write_progress(mismatch,{"mission_id":"dam_crown","kills":0,"play_time":0}) == OK and FileAccess.get_sha256(mismatch+".backup") == backup_hash, "write after recovery succeeds without replacing semantic backup with invalid primary")
	check(quarantines(mismatch).size()==1 and FileAccess.get_sha256(quarantines(mismatch)[0])==invalid_hash, "quarantine retains exact invalid primary bytes")
	check(Progress.read_progress(mismatch,legacy).data.mission_id=="dam_crown", "recovered campaign can continue saving")
	var original_quarantine := quarantines(mismatch)[0]
	raw(mismatch,expanded("extraction",3))
	check(Progress.write_progress(mismatch,{"mission_id":"spillway","kills":1,"play_time":2})==OK and quarantines(mismatch).size()==2 and FileAccess.get_sha256(original_quarantine)==invalid_hash, "repeated quarantine never overwrites earlier evidence")
	for suffix in Progress.SUFFIXES:
		var repair := fresh("repair"+str(Progress.SUFFIXES.find(suffix)))
		var retained := repair+".backup" if suffix!=".backup" else repair
		raw(retained,expanded("uplink",2))
		var invalid := expanded("relay",0)
		invalid.kills=-1
		raw(repair+suffix,invalid)
		var artifact_hash := FileAccess.get_sha256(repair+suffix)
		check(Progress._prepare_known_recovery(repair)==OK, "known invalid artifact safely prepared " + suffix)
		check(Progress.read_progress(repair,legacy).data.mission_id=="uplink", "simulated interruption before writer retains recoverable checkpoint " + suffix)
		check(quarantines(repair+suffix).size()==1 and FileAccess.get_sha256(quarantines(repair+suffix)[0])==artifact_hash, "artifact exact bytes retained " + suffix)
		check(Progress.write_progress(repair,{"mission_id":"dam_crown","kills":5,"play_time":15})==OK, "retry after interrupted preparation commits " + suffix)
	var no_snapshot := fresh("no_snapshot")
	raw(no_snapshot,expanded("extraction",3))
	var only_hash := FileAccess.get_sha256(no_snapshot)
	check(Progress.write_progress(no_snapshot,{"mission_id":"relay","kills":0,"play_time":0})!=OK and FileAccess.get_sha256(no_snapshot)==only_hash and quarantines(no_snapshot).is_empty(), "without valid semantic snapshot write fails without mutation")
	var blocked_family := fresh("blocked_repair")
	raw(blocked_family,expanded("extraction",3))
	raw(blocked_family+".backup",expanded("uplink",2))
	raw(blocked_family+".pending",{"version":2,"campaign_id":Progress.CAMPAIGN_ID,"mission_id":"relay"})
	var blocked_hash := FileAccess.get_sha256(blocked_family)
	check(Progress.write_progress(blocked_family,{"mission_id":"relay","kills":0,"play_time":0})!=OK and FileAccess.get_sha256(blocked_family)==blocked_hash and quarantines(blocked_family).is_empty(), "future artifact blocks all repair mutations before quarantine")
	for field in ["chapter","kills","play_time"]:
		for value in [-1,"bad",true,null]:
			var bad_path := fresh("readbad"+field+str(checks))
			var bad_data := expanded("relay",0)
			bad_data[field] = value
			raw(bad_path,bad_data)
			check(Progress.read_progress(bad_path,legacy).state == "invalid", "malformed stored field rejected without legacy fallback " + field + str(value))
	for invalid in [-1,1.5,1000001,"3",true,null,INF,NAN]:
		check(Progress.write_progress(fresh("badstats"),{"mission_id":"relay","kills":invalid,"play_time":0}) != OK, "invalid kills rejected " + str(invalid))
	for invalid in [-1,31536001,"3",true,null,INF,NAN]:
		check(Progress.write_progress(fresh("badtime"),{"mission_id":"relay","kills":0,"play_time":invalid}) != OK, "invalid play time rejected " + str(invalid))
	check(Progress.read_progress(fresh("empty"),"").state == "missing", "absent expanded and legacy reports missing")
	check(Progress.read_progress(legacy,legacy).state == "blocked", "same-path migration rejected")
	print("CAMPAIGN_PROGRESS_RESULT passes=",checks-failures," failures=",failures," legacy_untouched=true")
	quit(0 if failures == 0 else 1)

