extends SceneTree
var xr: XRInterface
var elapsed := 0.0
var tick := 0
var hands: Array[XRController3D] = []
func _initialize() -> void:
    call_deferred("setup")
func setup() -> void:
    print("XR_DIAG START UTC ", Time.get_datetime_string_from_system(true))
    print("AUDIO driver=", AudioServer.get_driver_name(), " mix=", AudioServer.get_mix_rate(), " devices=", AudioServer.get_output_device_list(), " selected=", AudioServer.output_device)
    xr = XRServer.find_interface("OpenXR")
    if not xr:
        print("XR_DIAG NO_INTERFACE")
        quit(2)
        return
    for s in xr.get_signal_list():
        var signal_name: String = s.name
        if signal_name.begins_with("session_"):
            xr.connect(signal_name, func(): print("XR_SESSION_SIGNAL ", signal_name))
    print("XR init_before=", xr.is_initialized())
    if not xr.is_initialized():
        print("XR initialize_result=", xr.initialize())
    print("XR initialized=", xr.is_initialized(), " system=", xr.get_system_info())
    root.use_xr = xr.is_initialized()
    var origin := XROrigin3D.new()
    root.add_child(origin)
    var cam := XRCamera3D.new()
    origin.add_child(cam)
    if not xr.is_initialized():
        cam.position.y = 1.6
    for side in ["left_hand", "right_hand"]:
        var hand := XRController3D.new()
        hand.tracker = StringName(side)
        origin.add_child(hand)
        hands.append(hand)
    var world := WorldEnvironment.new()
    world.environment = Environment.new()
    world.environment.background_mode = Environment.BG_COLOR
    world.environment.background_color = Color(0.015,0.04,0.07)
    world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    world.environment.ambient_light_color = Color.WHITE
    world.environment.ambient_light_energy = 0.7
    root.add_child(world)
    var label := Label3D.new()
    label.text = "ASHFALL\nOpenXR link diagnostic\nMove both controllers and press triggers"
    label.position = Vector3(0,1.6,-2)
    label.font_size = 50
    label.pixel_size = 0.0015
    root.add_child(label)
func _process(delta: float) -> bool:
    elapsed += delta
    if elapsed > tick + 1:
        tick += 1
        if xr and xr.is_initialized():
            print("XR_SAMPLE t=", tick, " status=", xr.get_tracking_status(), " trackers=", XRServer.get_trackers(XRServer.TRACKER_ANY))
        for hand in hands:
            print("HAND ", hand.tracker, " active=", hand.get_is_active(), " tracking=", hand.get_has_tracking_data(), " pos=", hand.global_position, " trigger=", hand.get_float("trigger"), " grip=", hand.get_float("grip"), " axis=", hand.get_vector2("primary"))
    if elapsed > 30 and not "--keep-open" in OS.get_cmdline_user_args():
        print("XR_DIAG END")
        quit()
    return false


