extends Node3D

const MAX_POINTS := 2200000
const STATIC_LIMIT := 1950000
const CACHE_VERSION := 4
const GRASS_STRIDE := 5
const CHUNK_SIZE := 32.0
const DOT_SHADER := preload("res://prototypes/pointillist/pointillist.gdshader")
const UNDERWATER_SHADER := preload("res://prototypes/pointillist/underwater_dots.gdshader")
const VISION_SHADER := preload("res://prototypes/pointillist/vision_waves.gdshader")
const VISION_PATTERN := preload("res://prototypes/pointillist/vision_pattern.gd")
const CACHE := "res://assets/pointillist_world_cache.scn"

class DotChunk:
    var positions := PackedVector3Array()
    var colors := PackedColorArray()

var point_count := 0
var source_mesh_count := 0
var chunk_count := 0
var image_cache: Dictionary = {}
var chunks: Dictionary = {}
var point_material: ShaderMaterial
var _daylight_timer := 0.0
var _land_backing: ShaderMaterial
var _sea_backing: StandardMaterial3D
var _structure_colors: Dictionary = {}
var _structure_backings: Dictionary = {}
var _underwater_backings: Dictionary = {}
var _vision_layer: CanvasLayer
var _vision_material: ShaderMaterial
var _vision_time := 0.0

func set_effect_enabled(enabled: bool) -> void:
    if _vision_layer != null:
        _vision_layer.visible = enabled

func install_vision_effect() -> void:
    if _vision_layer != null:
        return
    _vision_layer = CanvasLayer.new()
    _vision_layer.name = "PointillistVision"
    _vision_layer.layer = 0  # The game's HUD and menus use layer 1.
    add_child(_vision_layer)
    var veil := ColorRect.new()
    veil.name = "VisionWaves"
    veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _vision_material = ShaderMaterial.new()
    _vision_material.shader = VISION_SHADER
    _vision_material.set_shader_parameter("wave_pattern", VISION_PATTERN.create_texture())
    veil.material = _vision_material
    _vision_layer.add_child(veil)

func _process(delta: float) -> void:
    if _vision_material != null:
        _vision_time = fmod(_vision_time + delta * 1.35, TAU)
        _vision_material.set_shader_parameter("phase_rotation", Vector2(cos(_vision_time), sin(_vision_time)))
    _daylight_timer += delta
    if _daylight_timer < 0.1 or point_material == null:
        return
    _daylight_timer = 0.0
    var clock := get_parent().get_node_or_null("DayNightCycle")
    if clock != null:
        var daylight: float = clock.daylight
        point_material.set_shader_parameter("daylight", daylight)
        var tint := Color(0.24, 0.31, 0.46).lerp(Color.WHITE, daylight)
        if _land_backing != null:
            _land_backing.set_shader_parameter("daylight_tint", tint)
        if _sea_backing != null:
            _sea_backing.albedo_color = Color(0.08, 0.41, 0.53) * tint
        for role in _structure_backings:
            var backing: StandardMaterial3D = _structure_backings[role]
            backing.albedo_color = _structure_colors[role] * tint
        for role in _underwater_backings:
            var underwater: ShaderMaterial = _underwater_backings[role]
            underwater.set_shader_parameter("daylight_tint", tint)

func backing_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = color
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material

func underwater_material(base: Color, light: Color, dark: Color, density: float) -> ShaderMaterial:
    var material := ShaderMaterial.new()
    material.shader = UNDERWATER_SHADER
    material.set_shader_parameter("base_color", base)
    material.set_shader_parameter("light_dot", light)
    material.set_shader_parameter("dark_dot", dark)
    material.set_shader_parameter("dots_per_meter", density)
    return material

func underwater_role(node_path: String, key: String) -> String:
    if not "/OceanGround/" in node_path:
        return ""
    if key.begins_with("ocean_seabed"):
        return "sand"
    if key.begins_with("ocean_rock_base_") or key.begins_with("ocean_toe_"):
        return "rock"
    if key.begins_with("ocean_footings_"):
        return "stone"
    return ""

func structure_role(node_path: String, key: String) -> String:
    if "/IslandBridges/" in node_path:
        if "cedar_grain" in key:
            return "bridge_cedar"
        if "coastal_limestone" in key:
            return "bridge_stone"
        if "dark_heartwood" in key:
            return "bridge_heartwood"
        if "bronze_fasteners" in key:
            return "bridge_bronze"
    if "/TempleMap/" in node_path:
        if key.begins_with("temple_cella_") or key in [
            "temple_colonnade", "temple_entablature", "temple_stylobate",
            "temple_entrance_east_jamb", "temple_entrance_west_jamb",
            "temple_entrance_lintel", "temple_entrance_over_door",
            "temple_entrance_cornice"
        ]:
            return "temple_stone"
    return ""

func palette(name: String) -> Color:
    var key := name.to_lower()
    if "water" in key or "sea" in key or "ocean" in key or "pond" in key:
        return Color(0.12, 0.69, 0.83)
    if "leaf" in key or "foliage" in key or "fern" in key or "grass" in key or "meadow" in key:
        return Color(0.25, 0.48, 0.16)
    if "tree" in key or "olive" in key or "bark" in key or "wood" in key:
        return Color(0.42, 0.32, 0.17)
    if "sand" in key or "beach" in key or "shore" in key:
        return Color(0.83, 0.75, 0.55)
    if "rock" in key or "cliff" in key or "terrain" in key or "island" in key:
        return Color(0.54, 0.59, 0.37)
    if "roof" in key or "tile" in key:
        return Color(0.67, 0.35, 0.25)
    if "bridge" in key or "plank" in key or "rail" in key:
        return Color(0.53, 0.34, 0.22)
    return Color(0.85, 0.78, 0.60)

func material_for_surface(node: MeshInstance3D, surface: int) -> Material:
    var material: Material = node.get_surface_override_material(surface)
    if material == null:
        material = node.mesh.surface_get_material(surface)
    return material

func color_for_surface(node: MeshInstance3D, material: Material) -> Color:
    var base := palette(String(node.name) + " " + (material.resource_name if material != null else ""))
    if material is BaseMaterial3D:
        var tint: Color = material.albedo_color
        if tint.r + tint.g + tint.b < 2.8:
            base = base.lerp(tint, 0.55)
    return base

func image_for_material(material: Material) -> Image:
    if not material is BaseMaterial3D or material.albedo_texture == null:
        return null
    var texture: Texture2D = material.albedo_texture
    var id := texture.get_instance_id()
    if not image_cache.has(id):
        var loaded: Image = texture.get_image()
        if loaded != null and loaded.is_compressed():
            loaded.decompress()
        image_cache[id] = loaded
    return image_cache[id]

func add_point(position: Vector3, color: Color) -> void:
    var key := Vector2i(floori(position.x / CHUNK_SIZE), floori(position.z / CHUNK_SIZE))
    var chunk: DotChunk = chunks.get(key)
    if chunk == null:
        chunk = DotChunk.new()
        chunks[key] = chunk
    chunk.positions.append(position - Vector3(key.x * CHUNK_SIZE, 0.0, key.y * CHUNK_SIZE))
    chunk.colors.append(color)
    point_count += 1

func convert_dynamic_mesh(node: MeshInstance3D) -> void:
    var points := ArrayMesh.new()
    for surface in node.mesh.get_surface_count():
        if node.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
            continue
        var arrays := node.mesh.surface_get_arrays(surface)
        var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
        if vertices.is_empty():
            continue
        var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
        var source_colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
        var material := material_for_surface(node, surface)
        var tint := color_for_surface(node, material)
        var image := image_for_material(material)
        var colors := PackedColorArray()
        for i in vertices.size():
            var value := tint
            if image != null and uvs.size() == vertices.size():
                var uv := uvs[i]
                value = image.get_pixel(posmod(int(floor(uv.x * image.get_width())), image.get_width()), posmod(int(floor(uv.y * image.get_height())), image.get_height()))
                if material is BaseMaterial3D:
                    value *= material.albedo_color
            if source_colors.size() == vertices.size():
                value *= source_colors[i]
            value.a = 1.0
            colors.append(value)
        arrays[Mesh.ARRAY_COLOR] = colors
        arrays[Mesh.ARRAY_INDEX] = null
        points.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
        points.surface_set_material(points.get_surface_count() - 1, point_material)
    if points.get_surface_count() == 0:
        return
    node.mesh = points
    node.material_override = null
    for surface in points.get_surface_count():
        node.set_surface_override_material(surface, null)
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func convert_scene(scene: Node3D, rebuild: bool = false) -> void:
    point_material = ShaderMaterial.new()
    point_material.shader = DOT_SHADER
    install_vision_effect()
    var cached: Node3D
    if not rebuild and ResourceLoader.exists(CACHE):
        cached = (load(CACHE) as PackedScene).instantiate()
    var use_cache := cached != null and int(cached.get_meta("version", 0)) == CACHE_VERSION
    if cached != null and not use_cache:
        cached.free()
        cached = null
    _land_backing = underwater_material(Color(0.29, 0.43, 0.38), Color(0.68, 0.72, 0.51), Color(0.17, 0.36, 0.37), 5.5)
    _land_backing.set_shader_parameter("waterline_y", -4.55)
    _sea_backing = backing_material(Color(0.08, 0.41, 0.53))
    _structure_colors = {
        "temple_stone": Color(0.57, 0.54, 0.46),
        "bridge_cedar": Color(0.40, 0.28, 0.18),
        "bridge_stone": Color(0.57, 0.53, 0.42),
        "bridge_heartwood": Color(0.22, 0.16, 0.12),
        "bridge_bronze": Color(0.33, 0.27, 0.17)
    }
    _structure_backings.clear()
    for role in _structure_colors:
        _structure_backings[role] = backing_material(_structure_colors[role])
    _underwater_backings = {
        "sand": underwater_material(Color(0.38, 0.49, 0.45), Color(0.79, 0.81, 0.65), Color(0.24, 0.45, 0.47), 6.0),
        "rock": underwater_material(Color(0.26, 0.39, 0.37), Color(0.61, 0.69, 0.52), Color(0.17, 0.33, 0.35), 5.0),
        "stone": underwater_material(Color(0.46, 0.50, 0.44), Color(0.83, 0.83, 0.68), Color(0.26, 0.40, 0.41), 6.0)
    }
    var meshes: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
    # Sample from the actual assembled runtime scene, after independent assets
    # and scoped replacements have been installed by their normal scripts.
    for entry in meshes:
        var node := entry as MeshInstance3D
        if node.mesh == null:
            continue
        if node.is_ancestor_of(self):
            continue
        var node_path := String(node.get_path())
        var key := String(node.name).to_lower()
        if key == "underwateratmosphere":
            continue
        var submerged_role := underwater_role(node_path, key)
        if submerged_role != "":
            # OceanGround hides deep buffers above water and restores them on
            # descent. Set their material even when they start hidden.
            node.material_override = _underwater_backings[submerged_role]
            node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            continue
        if not node.is_visible_in_tree():
            continue
        if "/Player/" in node_path or "/IslandCharacters/" in node_path or "Koi" in node_path:
            convert_dynamic_mesh(node)
            continue
        var role := structure_role(node_path, key)
        var open_water := key == "mediterranean_sea" or "ocean_horizon_water" in key
        var budget := 800
        if "olive" in key or "tree" in key:
            budget = 1800
        elif "terrain" in key or "island" in key or "cliff" in key:
            budget = 50000
        elif "sea" in key or "ocean" in key:
            budget = 80000
        elif "temple" in key or "pagoda" in key:
            budget = 15000
        if role == "temple_stone" and key.begins_with("temple_cella_"):
            budget = 6500
        elif role == "bridge_cedar" or role == "bridge_heartwood":
            budget = 12000
        elif role == "bridge_stone":
            budget = 4000
        elif role == "bridge_bronze":
            budget = 2000
        var points_before := point_count
        for surface in node.mesh.get_surface_count():
            if use_cache or point_count >= STATIC_LIMIT or open_water:
                break
            if node.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
                continue
            var arrays := node.mesh.surface_get_arrays(surface)
            var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
            if vertices.is_empty():
                continue
            var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
            var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
            var vertex_colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
            var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
            var triangle_count: int = (indices.size() if not indices.is_empty() else vertices.size()) / 3
            if triangle_count == 0:
                continue
            var count: int = mini(budget, triangle_count * 3)
            var area_weighted := role != "" and (key.begins_with("temple_cella_") or "/IslandBridges/" in node_path)
            if area_weighted:
                count = budget
            count = mini(count, STATIC_LIMIT - point_count)
            var triangle_cdf := PackedFloat32Array()
            var total_area := 0.0
            if area_weighted:
                for t in triangle_count:
                    var tri := t * 3
                    var ia: int = indices[tri] if not indices.is_empty() else tri
                    var ib: int = indices[tri + 1] if not indices.is_empty() else tri + 1
                    var ic: int = indices[tri + 2] if not indices.is_empty() else tri + 2
                    total_area += (vertices[ib] - vertices[ia]).cross(vertices[ic] - vertices[ia]).length()
                    triangle_cdf.append(total_area)
                area_weighted = total_area > 0.0
            var material := material_for_surface(node, surface)
            var color := color_for_surface(node, material)
            var image := image_for_material(material)
            var random := RandomNumberGenerator.new()
            random.seed = absi(hash(String(node.get_path()) + ":" + str(surface)))
            var emitted := 0
            var attempts := 0
            while emitted < count and attempts < count * 8:
                attempts += 1
                var triangle := random.randi_range(0, triangle_count - 1) * 3
                if area_weighted:
                    var target := random.randf() * total_area
                    var low := 0
                    var high := triangle_count - 1
                    while low < high:
                        var mid := (low + high) / 2
                        if triangle_cdf[mid] < target:
                            low = mid + 1
                        else:
                            high = mid
                    triangle = low * 3
                var a: int = indices[triangle] if not indices.is_empty() else triangle
                var b: int = indices[triangle + 1] if not indices.is_empty() else triangle + 1
                var c: int = indices[triangle + 2] if not indices.is_empty() else triangle + 2
                var root := sqrt(random.randf())
                var x := 1.0 - root
                var y := root * (1.0 - random.randf())
                var z := 1.0 - x - y
                var local := vertices[a] * x + vertices[b] * y + vertices[c] * z
                var shade := 0.82
                var local_normal := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).normalized()
                if normals.size() == vertices.size():
                    local_normal = (normals[a] * x + normals[b] * y + normals[c] * z).normalized()
                    shade = 0.62 + 0.38 * maxf(0.0, (node.global_transform.basis * local_normal).normalized().dot(Vector3(0.4, 0.8, 0.2)))
                var value := color
                if image != null and uvs.size() == vertices.size():
                    var uv := uvs[a] * x + uvs[b] * y + uvs[c] * z
                    var px := image.get_pixel(posmod(int(floor(uv.x * image.get_width())), image.get_width()), posmod(int(floor(uv.y * image.get_height())), image.get_height()))
                    if px.a < 0.3:
                        continue
                    value = px
                    if material is BaseMaterial3D:
                        value *= material.albedo_color
                if vertex_colors.size() == vertices.size():
                    var vc := vertex_colors[a] * x + vertex_colors[b] * y + vertex_colors[c] * z
                    value *= vc
                value.a = 1.0
                if role != "":
                    local += local_normal * 0.025
                add_point(node.global_transform * local, value * shade)
                emitted += 1
        if role != "" and not use_cache:
            print("POINTILLIST_STRUCTURE ", node.name, " dots=", point_count - points_before)
        source_mesh_count += 1
        # The north island is named Meadow_Ground, so the terrain check misses it.
        if "terrain" in key or "distant_islands" in key or key == "north_pagoda_pagoda_meadow_ground":
            node.material_override = _land_backing
        elif key == "mediterranean_sea" or "ocean_horizon_water" in key:
            node.material_override = _sea_backing
        elif role != "":
            node.material_override = _structure_backings[role]
        else:
            node.hide()
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    if not use_cache:
        # The vast imported horizon has triangles kilometers from gameplay.
        # Bounded water dots avoid thousands of distant draw chunks.
        var sea_random := RandomNumberGenerator.new()
        sea_random.seed = 20261021
        for i in 170000:
            if point_count >= MAX_POINTS:
                break
            var x := sea_random.randf_range(-170.0, 170.0)
            var z := sea_random.randf_range(-170.0, 170.0)
            var shade := sea_random.randf_range(0.86, 1.12)
            var water_color := Color(0.09, 0.61, 0.79, 0.5) * shade
            add_point(Vector3(x, -4.55, z), water_color)
    for entry in scene.find_children("*", "MultiMeshInstance3D", true, false):
        var patch := entry as MultiMeshInstance3D
        if patch.multimesh == null or not patch.is_visible_in_tree():
            continue
        var tint := palette(String(patch.name) + " grass")
        if not use_cache:
            for i in range(0, patch.multimesh.instance_count, GRASS_STRIDE):
                if point_count >= MAX_POINTS:
                    break
                var transform: Transform3D = patch.global_transform * patch.multimesh.get_instance_transform(i)
                add_point(transform.origin + Vector3(0, 0.10, 0), tint)
        patch.hide()
    if use_cache:
        add_child(cached)
        for entry in cached.find_children("*", "MeshInstance3D", true, false):
            var dot_mesh := entry as MeshInstance3D
            dot_mesh.mesh.surface_set_material(0, point_material)
        point_count = int(cached.get_meta("point_count", 0))
        chunk_count = int(cached.get_meta("chunk_count", 0))
        image_cache.clear()
        print("POINTILLIST_CACHE ", point_count, " dots in ", chunk_count, " chunks")
        return
    var dot_root := Node3D.new()
    dot_root.name = "DotChunks"
    add_child(dot_root)
    for key: Vector2i in chunks:
        var chunk: DotChunk = chunks[key]
        var arrays: Array = []
        arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX] = chunk.positions
        arrays[Mesh.ARRAY_COLOR] = chunk.colors
        var points := ArrayMesh.new()
        points.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arrays)
        points.surface_set_material(0, point_material)
        var instance := MeshInstance3D.new()
        instance.name = "Dots_%d_%d" % [key.x,key.y]
        instance.mesh = points
        instance.position = Vector3(key.x * CHUNK_SIZE, 0.0, key.y * CHUNK_SIZE)
        instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        dot_root.add_child(instance)
        instance.owner = dot_root
        chunk_count += 1
    dot_root.set_meta("point_count", point_count)
    dot_root.set_meta("chunk_count", chunk_count)
    dot_root.set_meta("version", CACHE_VERSION)
    var packed := PackedScene.new()
    if packed.pack(dot_root) == OK:
        var saved := ResourceSaver.save(packed, CACHE)
        if saved != OK:
            push_warning("Pointillist cache save failed: " + str(saved))
    chunks.clear()
    image_cache.clear()
    print("POINTILLIST_WORLD ", point_count, " dots in ", chunk_count, " chunks from ", source_mesh_count, " source meshes")
