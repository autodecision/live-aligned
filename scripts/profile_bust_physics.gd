extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var tag:=OS.get_environment("BUST_PROFILE_TAG")
 if tag.is_empty():tag="after"
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 var player=main.get_node("Player");player.set_physics_process(false);player.capture_mouse(true);player.rotation.y=-PI/2.
 Input.action_press("move_forward")
 var trials:=[]
 for enabled in [false,true]:
  for body in main.get_node("TempleMap").find_children("*","CollisionShape3D",true,false):
   if "Altar_Marble_Bust" in String(body.get_path()):body.disabled=not enabled
  await physics_frame
  for height in [5.12,5.7]:
   print("BUST_TRIAL_START ",enabled," ",height)
   player.global_position=Vector3(3.,height,-7.3);player.velocity=Vector3.ZERO
   var times:=[];var max_usec:=0
   for i in range(45):
    await physics_frame
    var t:=Time.get_ticks_usec();player._physics_process(1./60.);var dt:=Time.get_ticks_usec()-t
    times.append(dt);max_usec=max(max_usec,dt)
   var total:=0
   for t in times:total+=t
   var row={"collision":enabled,"start_height":height,"mean_usec":float(total)/times.size(),"max_usec":max_usec,"end":str(player.global_position)};trials.append(row);print("BUST_PHYSICS ",JSON.stringify(row))
 Input.action_release("move_forward")
 FileAccess.open("/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/bust_physics_"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(trials,"  "))
 quit()
