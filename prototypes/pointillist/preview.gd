extends SceneTree

const OUTPUT := "/home/allister/Projects/live-aligned-previews/pointillist-2026-10-21/"
const VIEWS := [
 ["temple", Vector3(-17,12,29), Vector3(-3,5,0)],
 ["meadow", Vector3(-12,4,12), Vector3(-18,2,3)],
 ["water", Vector3(18,1,17), Vector3(11,-3,7.5)],
 ["garden", Vector3(101,7,46), Vector3(100,4.7,32)]
]
const STRUCTURE_VIEWS := [
 ["bridge_south", Vector3(11,12,28), Vector3(-1,1.6,20)],
 ["bridge_north", Vector3(28,11,-23), Vector3(20,1,-32)],
 ["bridge_north_south", Vector3(63,11,-30), Vector3(78,5,-12)],
 ["temple_pillars", Vector3(3,6.7,2.5), Vector3(-1.3,7.5,-1)],
 ["temple_side", Vector3(-7.15,6.3,-12.2), Vector3(-7.15,6.5,-2)]
]
const UNDERWATER_VIEWS := [
 ["bridge_underwater", Vector3(63,-8.0,14), Vector3(60,-8.4,24)],
 ["rock_underwater", Vector3(118,-8.2,75), Vector3(131,-8.8,72)],
 ["island_toe", Vector3(-32,-8.0,64), Vector3(-15,-8.5,44)]
]
const HILL_VIEWS := [
 ["north_bridge_shore", Vector3(42,-2.9,-40), Vector3(83,4,-70)],
 ["pagoda_shore", Vector3(69,-2.6,-48), Vector3(88,4,-70)],
 ["north_bridge_exterior", Vector3(37,-2.9,-40), Vector3(83,4,-70)],
 ["north_coast_exterior", Vector3(32,-3.2,-52), Vector3(83,4,-70)],
 ["western_sea", Vector3(23,-3.6,-52), Vector3(57,0,-55)],
 ["south_bridge_shore", Vector3(64,-2.9,17), Vector3(109,4,33)]
]
var rendered: SubViewport
var camera: Camera3D
var measured_viewport: Viewport
var real_benchmark := false
var sample_usec := 3000000

func _initialize() -> void:
    call_deferred("run")

func draw_frame() -> void:
    await process_frame
    if not real_benchmark:
        RenderingServer.force_draw(false)

func measure(label: String) -> Dictionary:
    var start := Time.get_ticks_usec()
    while Time.get_ticks_usec() - start < 1000000:
        await draw_frame()
    start = Time.get_ticks_usec()
    var last := start
    var times: Array[float] = []
    var gpu_ms := 0.0
    var draw_calls := 0.0
    var process_ms := 0.0
    var physics_ms := 0.0
    var render_cpu_ms := 0.0
    while Time.get_ticks_usec() - start < sample_usec:
        await draw_frame()
        var now := Time.get_ticks_usec()
        times.append((now - last) / 1000.0)
        last = now
        gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(measured_viewport.get_viewport_rid())
        draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
        process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
        physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
        render_cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(measured_viewport.get_viewport_rid())
    times.sort()
    var row := {"case":label,"fps":times.size()*1000000.0/(last-start),"median_ms":times[times.size()/2],"p95_ms":times[int(times.size()*.95)],"gpu_ms":gpu_ms/times.size(),"render_cpu_ms":render_cpu_ms/times.size(),"process_ms":process_ms/times.size(),"physics_ms":physics_ms/times.size(),"draw_calls":draw_calls/times.size(),"frames":times.size()}
    print("POINTILLIST_BENCH ", JSON.stringify(row))
    return row

func run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Native renderer required")
        quit(2)
        return
    var args := OS.get_cmdline_user_args()
    if args.has("long"):
        sample_usec = 10000000
    var play := args.has("play")
    var original := args.has("original")
    var live_bench := args.has("live")
    var walk_check := args.has("walk")
    real_benchmark = args.has("real")
    var direct := play or real_benchmark
    root.size = Vector2i(1920,1080)
    if real_benchmark:
        root.always_on_top = true
    root.grab_focus()
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    Engine.max_fps = 0
    if not direct:
        RenderingServer.set_render_loop_enabled(false)
        rendered = SubViewport.new()
        rendered.size = Vector2i(1920,1080)
        rendered.own_world_3d = true
        rendered.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        root.add_child(rendered)
        var preview := TextureRect.new()
        preview.texture = rendered.get_texture()
        preview.size = Vector2(1920,1080)
        root.add_child(preview)
        await process_frame
        RenderingServer.force_draw(true)
    if direct:
        var placeholder := ColorRect.new()
        placeholder.color = Color(0.04, 0.09, 0.13)
        placeholder.size = Vector2(1920,1080)
        root.add_child(placeholder)
        await process_frame
        RenderingServer.force_draw(true)
        await process_frame
        placeholder.queue_free()
        root.grab_focus()
    var main: Node3D = load("res://scenes/main.tscn").instantiate()
    if direct:
        root.add_child(main)
    else:
        rendered.add_child(main)
    var player: CharacterBody3D = main.get_node("Player")
    if not direct and not live_bench and not walk_check:
        player.set_physics_process(false)
        player.set_process_unhandled_input(false)
        player.visible = false
        player.get_node("CanvasLayer").hide()
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        main.get_node("CharacterDialogue").hide()
        main.get_node("VisualLab").select_preset(0)
        main.get_node("VisualLab")._launcher.hide()
        main.get_node("DayNightCycle").running = false
        main.get_node("DayNightCycle").set_phase(.25)
        main.get_node("AnimatedWater").set_process(false)
        main.get_node("AnimatedWater").set_water_time(12.0)
        for npc in main.get_node("IslandCharacters").get_children():
            npc.set_physics_process(false)
        main.get_node("SouthGarden").set_process(false)
    if args.has("night"):
        main.get_node("DayNightCycle").running = false
        main.get_node("DayNightCycle").set_phase(0.75)
    var viewport: Viewport = root if direct else rendered
    measured_viewport = viewport
    viewport.msaa_3d = Viewport.MSAA_DISABLED
    viewport.scaling_3d_scale = 1.0
    main.get_node("MediterraneanSun").shadow_enabled = false
    var world := Node3D.new()
    world.name = "PointillistRenderer"
    world.set_script(load("res://prototypes/pointillist/pointillist_world.gd"))
    main.add_child(world)
    if not original:
        world.call("convert_scene", main, args.has("rebuild"))
        if args.has("no_filter"):
            world.call("set_effect_enabled", false)
    if real_benchmark:
        root.grab_focus()
    if args.has("no_garden_process"):
        main.get_node("SouthGarden").set_process(false)
    if args.has("no_npc_physics"):
        for npc in main.get_node("IslandCharacters").get_children():
            npc.set_physics_process(false)
    if args.has("npc_normal_speed"):
        for npc in main.get_node("IslandCharacters").get_children():
            npc.set("travel_speed_multiplier", 1.0)
    if play or walk_check or args.has("npc_speed_1_5"):
        for npc in main.get_node("IslandCharacters").get_children():
            npc.set("travel_speed_multiplier", 1.5)
    if walk_check:
        var start := player.global_position
        var actor_starts := {}
        for actor in main.get_node("IslandCharacters").get_children():
            actor_starts[String(actor.name)] = actor.global_position
        player.is_mouse_captured = true
        Input.action_press("move_forward")
        for i in 120:
            await physics_frame
        Input.action_release("move_forward")
        var moved := player.global_position.distance_to(start)
        var actor_movement := {}
        for actor in main.get_node("IslandCharacters").get_children():
            actor_movement[String(actor.name)] = actor.global_position.distance_to(actor_starts[String(actor.name)])
        print("POINTILLIST_WALK ", JSON.stringify({"moved_m":moved,"start":str(start),"end":str(player.global_position),"on_floor":player.is_on_floor(),"actors_moved_m":actor_movement}))
        quit(0 if moved > 1.0 else 4)
        return
    if play:
        print("POINTILLIST_PLAY_READY")
        return
    camera = Camera3D.new()
    main.add_child(camera)
    camera.current = true
    camera.fov = 65
    RenderingServer.viewport_set_measure_render_time(measured_viewport.get_viewport_rid(), true)
    var output := OUTPUT + ("hills_original/" if original and args.has("hills") else "hills/" if args.has("hills") else "underwater/" if args.has("underwater") else "structures/" if args.has("structures") else "night/" if args.has("night") else "real/" if real_benchmark else "live/" if live_bench else "fixed/")
    DirAccess.make_dir_recursive_absolute(output)
    var rows := []
    var views := HILL_VIEWS if args.has("hills") else UNDERWATER_VIEWS if args.has("underwater") else STRUCTURE_VIEWS if args.has("structures") else VIEWS
    for view in views:
        if args.has("garden") and view[0] != "garden":
            continue
        camera.position = view[1]
        camera.look_at(view[2])
        rows.append(await measure(view[0]))
        measured_viewport.get_texture().get_image().save_png(output + view[0] + ".png")
    var invalid := false
    for row in rows:
        if row.gpu_ms < 0.01:
            invalid = true
    if real_benchmark and rows.size() > 1:
        var same_render_stats := true
        for row in rows.slice(1):
            if absf(row.draw_calls - rows[0].draw_calls) > 0.01 or absf(row.gpu_ms - rows[0].gpu_ms) > 0.01:
                same_render_stats = false
                break
        invalid = invalid or same_render_stats
    var report := {"resolution":[1920,1080],"gpu":RenderingServer.get_video_adapter_name(),"dots":world.get("point_count"),"source_meshes":world.get("source_mesh_count"),"chunks":world.get("chunk_count"),"live":live_bench,"real":real_benchmark,"valid":not invalid,"rows":rows}
    FileAccess.open(output + "report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("POINTILLIST_BENCH_COMPLETE" if not invalid else "POINTILLIST_BENCH_INVALID: renderer statistics did not advance")
    quit(3 if invalid else 0)
