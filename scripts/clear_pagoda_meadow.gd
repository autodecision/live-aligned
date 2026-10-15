extends SceneTree
const GrassCover = preload("res://scripts/island_ground_cover.gd")
const OUT="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/"
func _initialize()->void:call_deferred("run")
func segment_distance(p:Vector2,a:Vector2,b:Vector2)->float:
 var d:=b-a
 return p.distance_to(a+d*clampf((p-a).dot(d)/maxf(d.length_squared(),.00001),0.,1.))
func run()->void:
 var plan:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/north_pagoda.json"))
 var library=load("res://assets/original_grass.glb").instantiate();var meshes:={}
 for m in library.find_children("*","MeshInstance3D",true,false):meshes[String(m.name)]=m.mesh.get_aabb()
 var removed:Array=[];var counts:={};var path:Array=plan.path
 var routes:Array=plan.get("sidewalk_routes",[{"path":path,"half_widths":[]}])
 if FileAccess.file_exists(OUT+"north_pagoda_grass_clearing.json"):
  var previous:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"north_pagoda_grass_clearing.json"));removed=previous.origins;counts=previous.by_asset
 for file in ["gscatter_ground_cover_instances.json","north_pagoda_cover.json"]:
  var rows:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/"+file));var kept:Array=[]
  for row in rows:
   var p:=Vector2(row.origin[0],-row.origin[2]);var reject:=false
   if p.x>54 and p.x<106 and p.y>35 and p.y<83:
    var b: Array=row.basis;var basis:=Basis(Vector3(b[0][0],b[0][1],b[0][2]),Vector3(b[1][0],b[1][1],b[1][2]),Vector3(b[2][0],b[2][1],b[2][2]));var radius:=.0;var bounds:AABB=meshes[GrassCover.grass_asset_name(row.asset)]
    basis=basis.scaled(Vector3.ONE*GrassCover.grass_asset_scale(row.asset))
    for j in range(8):
     var v:=basis*bounds.get_endpoint(j);radius=maxf(radius,Vector2(v.x,v.z).length())
    for route in routes:
     var points:Array=route.path
     for i in range(points.size()-1):
      var width:float=maxf(route.half_widths[i],route.half_widths[i+1]) if not route.half_widths.is_empty() else float(plan.path_half_width)
      if segment_distance(p,Vector2(points[i][0],-points[i][2]),Vector2(points[i+1][0],-points[i+1][2]))<width+radius+.20:reject=true;break
     if reject:break
    var d:=p-Vector2(92,64);var q:=Vector2(cos(plan.yaw)*d.x+sin(plan.yaw)*d.y,-sin(plan.yaw)*d.x+cos(plan.yaw)*d.y)
    if absf(q.x)<7.35+radius and absf(q.y)<7.35+radius:reject=true
    if absf(q.x)<2.05+radius and q.y> -11.2-radius and q.y< -6.5:reject=true
   if reject:removed.append(row.origin);counts[row.asset]=counts.get(row.asset,0)+1
   else:kept.append(row)
  FileAccess.open("res://assets/"+file,FileAccess.WRITE).store_string(JSON.stringify(kept))
  if file=="north_pagoda_cover.json":plan.cover_count=kept.size()
 FileAccess.open("res://assets/north_pagoda.json",FileAccess.WRITE).store_string(JSON.stringify(plan,"  "))
 FileAccess.open(OUT+"north_pagoda.json",FileAccess.WRITE).store_string(JSON.stringify(plan,"  "))
 FileAccess.open(OUT+"north_pagoda_grass_clearing.json",FileAccess.WRITE).store_string(JSON.stringify({"removed":removed.size(),"by_asset":counts,"origins":removed,"checked_full_scaled_mesh_bounds":true},"  "))
 library.free();print("PAGODA_GRASS_CLEARED ",removed.size()," protruding plants");quit()
