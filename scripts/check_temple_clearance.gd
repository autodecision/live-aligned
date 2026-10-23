extends "res://scripts/check_south_garden.gd"
## Regression: landing/jumping/walking on the rail must never trap the capsule.
var landings:int=0
var jumps:int=0
var exits:int=0
func tick(count:int)->void:
 for i:int in count:
  await physics_frame
  player._physics_process(1./60.)
func rail_trial(point:Vector3,direction:Vector3)->void:
 Input.action_release('move_forward')
 player.position=point+Vector3.UP*1.4;player.velocity=Vector3.ZERO
 await tick(90)
 assert(player.is_on_floor(),'Failed to land on rail '+str(player.position))
 assert(absf(player.position.y-point.y)<.015,'Landed under the beam '+str(player.position))
 landings+=1
 var before:float=player.position.y
 Input.action_press('jump')
 await tick(1)
 Input.action_release('jump')
 var peak:float=player.position.y
 for i:int in 90:
  await tick(1)
  peak=maxf(peak,player.position.y)
 assert(peak>before+1.2,'Rail jump failed')
 assert(player.is_on_floor() and absf(player.position.y-before)<.015,'Cannot reland on rail')
 jumps+=1
 var start:Vector3=player.position
 player.rotation.y=atan2(-direction.x,-direction.z)
 Input.action_press('move_forward')
 await tick(26)
 Input.action_release('move_forward')
 var travel:float=Vector2(player.position.x-start.x,player.position.z-start.z).length()
 assert(travel>1.3,'Rail trapped the player '+str(start)+' -> '+str(player.position))
 exits+=1
func jump_onto(point:Vector3,toward:Vector3)->void:
 player.position=point-toward*.9-Vector3.UP*.95;player.velocity=Vector3.ZERO
 await tick(30)
 var floor_y:float=player.position.y
 assert(player.is_on_floor())
 player.walk_speed=2.5
 player.rotation.y=atan2(-toward.x,-toward.z)
 Input.action_press('jump')
 await tick(1)
 Input.action_release('jump')
 Input.action_press('move_forward')
 var braking:bool=false
 for i:int in 80:
  var speed:float=Vector3(player.velocity.x,0,player.velocity.z).dot(toward)
  var remaining:float=(point-player.position).dot(toward)
  if not braking and remaining<=speed*speed/(2.*player.air_control*player.walk_speed)+.03:
   braking=true
   player.rotation.y=atan2(toward.x,toward.z)
  if braking and speed<.12:
   Input.action_release('move_forward')
  await tick(1)
 Input.action_release('move_forward')
 assert(player.is_on_floor() and absf(player.position.y-point.y)<.02,'Jump onto rail failed: '+str(player.position))
 assert(Vector2(player.position.x-point.x,player.position.z-point.z).length()<.2,'Jump missed rail')
 assert(player.position.y>floor_y+.8)
 player.walk_speed=5.
 var start:Vector3=player.position
 player.rotation.y=atan2(toward.x,toward.z)
 Input.action_press('move_forward')
 await tick(24)
 Input.action_release('move_forward')
 assert(player.position.distance_to(start)>1.,'Jump onto rail trapped the capsule')
 jumps+=1;landings+=1;exits+=1
func run()->void:
 Engine.physics_ticks_per_second=240;Engine.time_scale=4.
 main=load('res://scenes/main.tscn').instantiate()
 root.add_child(main)
 player=main.get_node('Player');player.set_physics_process(false);player.set_process_unhandled_input(false)
 for npc in main.get_node('IslandCharacters').get_children():npc.set_physics_process(false);npc.position=Vector3(0,-100,0)
 await physics_frame
 var map:Node3D=main.get_node('TempleMap')
 var plan:Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://assets/temple_clearance.json'))
 for label:String in plan.removed_props:assert(not map.get_node(NodePath(label)).visible)
 for label:String in plan.positions:assert(map.get_node(NodePath(label)).position.distance_to(vec(plan.positions[label]))<.001)
 var colors_checked:int=0
 for label:String in plan.sea_rocks:
  var rock:MeshInstance3D=map.get_node(NodePath(label))
  assert(rock.material_override==null)
  for i:int in rock.mesh.get_surface_count():
   var material:StandardMaterial3D=rock.mesh.surface_get_material(i)
   assert(material.vertex_color_use_as_albedo)
   assert(material.albedo_texture!=null,'Missing albedo texture on '+label)
   assert(material.normal_enabled and material.normal_texture!=null,'Missing normal map on '+label)
   assert(material.uv1_world_triplanar,'Missing triplanar mapping on '+label)
   var arrays:=rock.mesh.surface_get_arrays(i)
   var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
   assert(colors.size()>0)
   for c:Color in colors:
    assert(absf(c.r-c.g)<0.20 and absf(c.r-c.b)<0.20,'Unnatural rainbow color detected on '+label)
   colors_checked+=colors.size()
 var urn:MeshInstance3D=map.get_node('Vase_Stairs_Plinth')
 var foot:Vector3=urn.global_transform*(urn.get_aabb().position+Vector3(urn.get_aabb().size.x*.5,0,urn.get_aabb().size.z*.5))
 var q:=PhysicsRayQueryParameters3D.create(foot+Vector3.UP*.02,foot-Vector3.UP*.08);q.exclude=[player.get_rid()]
 assert(not main.get_world_3d().direct_space_state.intersect_ray(q).is_empty(),'Urn lacks floor support')
 # Reproduce the old failure at mid-beam, posts and the L corner, plus the
 # original two terrace rail segments. Move along and toward the terrace.
 for row:Array in [
  [Vector3(5,1,11.8),Vector3.FORWARD],
  [Vector3(3.65,1,11.8),Vector3.LEFT],
  [Vector3(9.1,1,11.8),Vector3.LEFT],
  [Vector3(9.1,1,11.8),Vector3.FORWARD],
  [Vector3(9.1,1,8.5),Vector3.LEFT],
  [Vector3(6.7,4.5,-7.5),Vector3.LEFT],
  [Vector3(6.7,4.5,-10),Vector3.BACK]]:
  await rail_trial(row[0],row[1])
 await jump_onto(Vector3(5,1,11.8),Vector3.BACK)
 await jump_onto(Vector3(9.1,1,9.8),Vector3.RIGHT)
 await jump_onto(Vector3(6.7,4.5,-9),Vector3.RIGHT)
 # Ordinary movement around the moved plant, both terrace legs and the urn.
 for route:Array in [
  [[-5.1,.05,10.9],[-5.1,.05,9.7]],
  [[-2.4,.05,10.75],[2,.05,10.75],[8.2,.05,10.75]],
  [[8.2,.05,10.75],[8.2,.05,8.8]],
  [[5.1,3.55,-4.8],[5.1,3.55,-7.0]]]:
  for reverse:bool in [false,true]:
   if not await walk(route,reverse):quit(1);return
 var report:Dictionary={'rail_landings':landings,'rail_jumps':jumps,'rail_exits':exits,'player_walks':walks,'removed_ferns':plan.removed_props.size(),'reference_colored_formations':plan.sea_rocks.size(),'colored_vertices':colors_checked,'urn_supported':true}
 print('TEMPLE_CLEARANCE_PASS ',JSON.stringify(report))
 quit()
