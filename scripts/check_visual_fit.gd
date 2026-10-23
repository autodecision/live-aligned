extends SceneTree
## Exercise the added landing barrier and export actual walking poses for cloth QA.
const OUT="/tmp/live-aligned-fit/"
var main:Node3D
func _initialize()->void:call_deferred("run")
func point(x:float,y:float,z:float)->Vector3:
 return Vector3(92+cos(-.88)*x-sin(-.88)*y,5.5+z,-64-sin(-.88)*x-cos(-.88)*y)
func components(t:Transform3D)->Array:
 return [[t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x],
         [t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y],
         [t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z],[0,0,0,1]]
func run()->void:
 Engine.physics_ticks_per_second=240;Engine.time_scale=4.
 DirAccess.make_dir_recursive_absolute(OUT)
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 var player:CharacterBody3D=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false)
 main.get_node("DayNightCycle").running=false
 for npc in main.get_node("IslandCharacters").get_children():npc.set_physics_process(false)
 await physics_frame
 var angle:float=-PI/2+.58
 var radial:=Vector2(cos(angle),sin(angle));var normal:=Vector2(-sin(angle),cos(angle))
 var blocked:=0
 for radius in [.9,1.55,2.18]:
  var start:Vector2=radial*float(radius)-normal*.45
  var goal:Vector2=radial*float(radius)+normal*.7
  player.position=point(start.x,start.y,9.84);player.velocity=Vector3.ZERO
  var toward:Vector3=point(goal.x,goal.y,9.8)-player.position;toward.y=0;player.rotation.y=atan2(-toward.x,-toward.z)
  for frame in 90:
   Input.action_press("move_forward");await physics_frame;player._physics_process(1./60.)
  Input.action_release("move_forward")
  var delta:Vector3=player.position-point(radial.x*float(radius),radial.y*float(radius),9.8)
  var world_normal:Vector3=(point(normal.x,normal.y,9.8)-point(0,0,9.8)).normalized()
  assert(delta.dot(world_normal)<-.28,"Player crossed top landing guard")
  assert(player.position.y>15.15,"Player fell through protected landing edge")
  blocked+=1
 player.position=Vector3(-20,4,0)
 var npc:PS3CharacterNPC=main.get_node("IslandCharacters/Scientist")
 var poses:Array=[]
 npc.current_activity="travel";npc.current_state=PS3CharacterNPC.State.WALK;npc.rotation.y=0;npc._motion_weight=1.
 var sites:=[Vector3(-3.5,.06,10.5),Vector3(-3.5,2.1,6.),Vector3(-3.5,2.1,6.)]
 for site_index in sites.size():
  var site:Vector3=sites[site_index]
  var query:=PhysicsRayQueryParameters3D.create(site+Vector3.UP*3.,site-Vector3.UP*3.,1);query.exclude=[npc.get_rid(),player.get_rid()]
  var floor_hit:=main.get_world_3d().direct_space_state.intersect_ray(query)
  assert(not floor_hit.is_empty());npc.position=Vector3(site.x,floor_hit.position.y+.015,site.z)
  npc.rotation.y=PI if site_index==2 else 0.
  for motion in [0.,.5,1.]:
   var count:=1 if motion==0. else 48
   for frame in count:
    npc._motion_weight=motion;npc._phase=float(frame)/48.;npc._animate(0.,1.55)
    var bones:Dictionary={}
    for bone in npc._bones:
     var index:int=npc._bones[bone]
     bones[bone]=components(npc.skeleton.get_bone_global_pose(index)*npc.skeleton.get_bone_global_rest(index).affine_inverse())
    poses.append({"site":str(site)+(" descending" if site_index==2 else ""),"phase":npc._phase,"motion_weight":motion,"bones":bones})
 FileAccess.open(OUT+"scientist_poses.json",FileAccess.WRITE).store_string(JSON.stringify(poses))
 var rock:MeshInstance3D=main.get_node("TempleMap/Large_Rock_Main_02")
 var fitted:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/forecourt_rock_grounding.json"))
 assert(rock.position.distance_to(Vector3(fitted.position[0],fitted.position[1],fitted.position[2]))<.001,"Rock override disagrees with saved placement")
 assert(rock.material_override!=null,"Rock lost its material")
 var report:={"guard_blocked_player_at_radii":blocked,"walking_poses_exported":poses.size(),"rock_material_and_placement":true}
 FileAccess.open(OUT+"runtime_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("VISUAL_FIT_RUNTIME_PASS ",JSON.stringify(report))
 if "--capture" in OS.get_cmdline_user_args():await capture_views()
 main.free();quit()

func capture_views()->void:
 root.size=Vector2i(1200,900);root.grab_focus()
 main.get_node("Player/CanvasLayer").hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 main.get_node("DayNightCycle").set_phase(.25)
 main.get_node("VisualLab").select_preset(0)
 var camera:=Camera3D.new();main.add_child(camera);camera.current=true
 for npc in main.get_node("IslandCharacters").get_children():npc.hide()
 for name in ["Envoy","Scientist","Robot"]:
  var npc:PS3CharacterNPC=main.get_node("IslandCharacters/"+name)
  npc.position=Vector3(-1.5,.06,10.5);npc.rotation.y=0.;npc.show();npc.current_activity="travel";npc.current_state=PS3CharacterNPC.State.WALK
  npc._motion_weight=1.;npc._phase=.4 if name=="Scientist" else 0.;npc._animate(0.,1.5)
  camera.fov=40.
  if name=="Envoy":
   camera.position=npc.position+Vector3(.42,1.68,-1.35);camera.look_at(npc.position+Vector3(0,1.58,0))
  elif name=="Scientist":
   camera.position=npc.position+Vector3(-.65,1.25,2.45);camera.look_at(npc.position+Vector3(0,1.05,0))
  else:
   camera.position=npc.position+Vector3(-1.2,1.4,-1.7);camera.look_at(npc.position+Vector3(-.4,1.2,0))
  await photograph(camera,name+"_fit")
  npc.hide()
 camera.fov=64.
 var views={
  "rock_front":[Vector3(-3.5,3.3,24.8),Vector3(-7.8,3.7,22.3)],
  "rock_left":[Vector3(-12.4,3.3,25.7),Vector3(-7.8,3.7,22.3)],
  "pagoda_guard":[point(-2.7,-4.,11.5),point(.6,-1.3,9.95)]}
 for name in views:
  camera.position=views[name][0];camera.look_at(views[name][1]);await photograph(camera,name)
func photograph(_camera:Camera3D,label:String)->void:
 for frame in 12:await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(OUT+label+".png")
