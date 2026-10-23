"""Slope all three islands into the water by adding outward coastal land and walkable beaches.

Usage:
  1. Run build_and_export() against improvements/mediterranean_temple_improved.blend
  2. Run install_saved() against assets/mediterranean_temple.blend and
     improvements/mediterranean_temple_improved.blend
"""
import hashlib
import json
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

PROJECT = Path(__file__).resolve().parent.parent
OUT = Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements')


def clamp(x, lo=0.0, hi=1.0):
    return max(lo, min(hi, x))


def smooth(a, b, x):
    if abs(b - a) < 1e-9:
        return 1.0 if x >= b else 0.0
    t = clamp((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def ramp_mix(t, linear_weight=0.82):
    t = clamp(t, 0.0, 1.0)
    s = t * t * (3.0 - 2.0 * t)
    return linear_weight * t + (1.0 - linear_weight) * s


def window_1d(x, lo_outer, lo_inner, hi_inner, hi_outer):
    return smooth(lo_outer, lo_inner, x) * (1.0 - smooth(hi_inner, hi_outer, x))


def mesh_digest(mesh):
    h = hashlib.sha256()
    for v in mesh.vertices:
        h.update(f'{v.co.x:.5f},{v.co.y:.5f},{v.co.z:.5f};'.encode())
    for p in mesh.polygons:
        h.update((','.join(str(i) for i in p.vertices) + ';').encode())
    return {
        'vertices': len(mesh.vertices),
        'polygons': len(mesh.polygons),
        'sha256': h.hexdigest()[:16],
    }


def north_vertices_sha256(mesh):
    north = [
        (round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4))
        for v in mesh.vertices
        if v.co.y >= 0.0
    ]
    return len(north), hashlib.sha256(repr(north).encode()).hexdigest()


def count_flat_sea_triangles(mesh):
    verts = [v.co for v in mesh.vertices]
    flat = 0
    for poly in mesh.polygons:
        ids = poly.vertices
        for k in range(1, len(ids) - 1):
            zs = [verts[ids[0]].z, verts[ids[k]].z, verts[ids[k + 1]].z]
            low, high = min(zs), max(zs)
            if high - low < 0.02 and low > -5.30 and high < -4.70:
                flat += 1
    return flat


def collect_prop_pins(scene):
    pins = []
    for obj in scene.objects:
        if obj.type != 'MESH':
            continue
        name = obj.name.replace('-convcol', '').replace('-col', '')
        if name.startswith(('Main_Island_Olive_', 'Island_North_Olive_', 'Island_South_Olive_')):
            pins.append((obj.location.x, obj.location.y, 1.45))
        elif name.startswith(('Large_Rock_Main_', 'Large_Rock_North_', 'Large_Rock_South_')):
            pins.append((obj.location.x, obj.location.y, 1.65))
    lanterns_path = PROJECT / 'assets/island_lantern_positions.json'
    if lanterns_path.exists():
        for row in json.loads(lanterns_path.read_text()):
            bx, by, _ = row['blender_position']
            pins.append((bx, by, 1.35))
    return pins


def pin_preservation_weight(x, y, pins):
    # Returns 0.0 at pinned prop centers and 1.0 outside their protective radius.
    w = 1.0
    for px, py, rad in pins:
        d = math.hypot(x - px, y - py)
        if d < rad + 1.1:
            w = min(w, smooth(rad * 0.55, rad + 1.1, d))
    return w


# ==============================================================================
# 1. MAIN ISLAND (Cliff_Terrain / bridge_approach_terrain.glb)
# ==============================================================================

def reshape_main_island(cliff_obj, pins):
    mesh = cliff_obj.data
    nx, ny = 268, 277
    grid_count = nx * ny
    assert len(mesh.vertices) >= grid_count, len(mesh.vertices)

    old_coords = [v.co.copy() for v in mesh.vertices[:grid_count]]

    # Bridge mouth protection zones:
    # Main_North start: (20.5, 31.5), dir=(0.8848, 0.4659)
    # Main_South start: (-1.0, -22.0), dir=(0.9965, -0.083)
    mn_start = Vector((20.5, 31.5))
    mn_dir = Vector((0.8848, 0.4659)).normalized()
    mn_side = Vector((-mn_dir.y, mn_dir.x))

    def bridge_and_interior_mask(x, y):
        # Returns 0.0 inside protected interior/waterfall/bridge corridors, 1.0 outside.
        # 1) Temple plaza, pools, retaining walls, guard rails:
        w_interior = 1.0 - window_1d(x, -16.5, -14.2, 11.2, 13.0) * window_1d(y, -15.5, -13.5, 18.8, 20.8)
        # 2) Waterfall channel on East side (x > 7.5, y in [-14.0, -1.5]):
        w_fall = 1.0 - smooth(7.0, 9.5, x) * window_1d(y, -15.0, -13.2, -2.2, -0.5)
        # 3) Main_North bridge mouth and under-deck:
        rel_n = Vector((x - mn_start.x, y - mn_start.y))
        along_n = rel_n.dot(mn_dir)
        cross_n = abs(rel_n.dot(mn_side))
        w_mn = 1.0 - window_1d(along_n, -3.5, -1.8, 7.5, 10.5) * (1.0 - smooth(2.8, 5.2, cross_n))
        # 4) Main_South bridge mouth and under-deck (-1.0, -22.0):
        w_ms = 1.0 - smooth(-2.8, -1.4, x) * window_1d(y, -26.5, -24.5, -19.2, -17.2)
        return min(w_interior, w_fall, w_mn, w_ms)

    new_verts = []
    for k, co in enumerate(old_coords):
        x0, y0, z0 = co.x, co.y, co.z
        protect = bridge_and_interior_mask(x0, y0)
        prop_w = pin_preservation_weight(x0, y0, pins)

        # Stretch only deep underwater outer grid vertices (z0 <= -5.8m) outward so the
        # coastal slopes have a generous horizontal run without moving any land feature.
        deep_w = smooth(-5.8, -9.8, z0) * protect
        dx_stretch = 0.0
        dy_stretch = 0.0
        if y0 < -24.0:
            dy_stretch -= 8.5 * smooth(-24.0, -41.0, y0) * deep_w
        if y0 > 30.0:
            dy_stretch += 6.0 * smooth(30.0, 49.0, y0) * deep_w
        if x0 > 19.5:
            dx_stretch += 8.5 * smooth(19.5, 44.0, x0) * deep_w
        if x0 < -22.0:
            dx_stretch -= 6.5 * smooth(-22.0, -48.0, x0) * deep_w

        x = x0 + dx_stretch
        y = y0 + dy_stretch

        # Base underwater floor elevation: lift -10.0m abyss to a continuous -7.25..-7.85m seabed
        # with gentle radial gradient so no flat triangles ever occur near sea level (-5.0m).
        radial_d = math.hypot(x / 46.0, y / 46.0)
        z_seabed = -7.15 - 0.85 * clamp((radial_d - 0.65) / 0.55, 0.0, 1.0)
        z_target = max(z0, z_seabed if z0 < -6.2 else z0)

        # --- General Outward Coastal Slopes Around Remaining Main Island Perimeter ---
        # Adds natural sloped land shoulders on West, NW, North, and SE coasts.
        a = math.atan2(y, x)
        mod = (
            1.0
            + 0.08 * math.cos(2.0 * a - 0.4)
            + 0.06 * math.sin(3.0 * a + 0.7)
            - 0.04 * math.cos(5.0 * a)
        )
        r_ell = math.hypot(x / 30.5, (y - 3.5) / 31.5) / mod
        if r_ell > 0.72 and protect > 0.0:
            t_c = clamp((r_ell - 0.78) / (1.52 - 0.78), 0.0, 1.0)
            z_apron = 2.15 - (2.15 - (-7.35)) * ramp_mix(t_c, 0.80)
            outer_mask = smooth(0.82, 0.94, r_ell) * protect * prop_w
            if z0 < 2.15 and outer_mask > 0.0:
                z_cand = max(z_target, z_apron)
                z_target = z_target * (1.0 - outer_mask) + z_cand * outer_mask

        # --- Walkable Corridor 1: Main Island South Beach ---
        # Centered at x in [-13.5, -3.5], sloping from the South Meadow rim at y = -27.0 (z = +3.28m)
        # down through waterline (y ~ -43.5, z = -5.0m) to bottom (y = -48.5, z = -7.25m),
        # with curved crest and height feathering on the western shoulder (x0 < -12.0).
        y_crest = -27.0 + 2.5 * smooth(-11.0, -18.5, x0)
        z_crest = 3.28 - 0.85 * smooth(-12.0, -19.0, x0)
        w_south_lane = (
            window_1d(x0, -19.5, -13.5, -3.4, -1.65)
            * smooth(y_crest + 1.5, y_crest - 0.5, y0)
            * protect
        )
        if w_south_lane > 0.0:
            t_s = clamp((y_crest - y) / (y_crest - (-48.5)), 0.0, 1.0)
            z_south_ramp = z_crest - (z_crest - (-7.25)) * ramp_mix(t_s, 0.88)
            z_added_s = max(z_target, z_south_ramp)
            z_target = z_target * (1.0 - w_south_lane) + z_added_s * w_south_lane

        # --- Walkable Corridor 2: Main Island East Beach ---
        # Centered at y = 16.5 (between Olive_39 at y=14.70 and Olive_40/Lantern_03 at y=18.50),
        # continuing the natural 8-deg East Terrace path (x = 14..19.5, z = 2.32..1.52m)
        # smoothly down from x = 19.5 (z = +1.52m) to x = 48.0 (z = -7.25m).
        flare = smooth(20.5, 25.5, x0)
        y_lo_out = 14.3 - 8.5 * flare
        y_lo_in = 15.55 - 6.0 * flare
        y_hi_in = 17.55 + 6.5 * flare
        y_hi_out = 18.6 + 9.0 * flare
        w_east_lane = window_1d(y0, y_lo_out, y_lo_in, y_hi_in, y_hi_out) * smooth(18.5, 20.0, x0) * protect
        if w_east_lane > 0.0:
            t_e2 = clamp((x - 19.5) / (48.0 - 19.5), 0.0, 1.0)
            z_east_ramp = 1.52 - (1.52 - (-7.25)) * ramp_mix(t_e2, 0.88)
            center_lane = window_1d(y0, 15.1, 15.75, 17.35, 18.0)
            eff_w = w_east_lane * max(prop_w, center_lane)
            z_added_e = max(z0, z_east_ramp)
            z_target = z_target * (1.0 - eff_w) + z_added_e * eff_w

        new_verts.append((x, y, z_target))

    # Build complete 276 x 267 quad grid so there are zero loose vertices or underwater holes.
    new_faces = []
    for j in range(ny - 1):
        row = j * nx
        for i in range(nx - 1):
            k = row + i
            new_faces.append((k, k + 1, k + 1 + nx, k + nx))

    old_mats = list(mesh.materials)
    new_mesh = bpy.data.meshes.new(mesh.name + '_Sloped')
    new_mesh.from_pydata(new_verts, [], new_faces)
    new_mesh.update()
    for mat in old_mats:
        new_mesh.materials.append(mat)
    uv = new_mesh.uv_layers.new(name='UVMap')
    for poly in new_mesh.polygons:
        poly.use_smooth = True
        for li in poly.loop_indices:
            co = new_mesh.vertices[new_mesh.loops[li].vertex_index].co
            uv.data[li].uv = ((co.x + 48.0) / 92.0, (co.y + 41.0) / 90.0)

    cliff_obj.data = new_mesh
    return {
        'digest': mesh_digest(new_mesh),
        'flat_sea_triangles': count_flat_sea_triangles(new_mesh),
    }


# ==============================================================================
# 2. SOUTH ISLAND (Distant_Islands y < 0 / south_garden_terrain.glb)
# ==============================================================================

def reshape_south_island(distant_obj, pins):
    mesh = distant_obj.data
    north_count = 6735
    nx, ny = 133, 109
    assert len(mesh.vertices) == north_count + nx * ny, len(mesh.vertices)

    # Verify northern vertices (0..6734) are untouched before and after.
    _, sha_before = north_vertices_sha256(mesh)

    cx, cy = 103.5, -34.0
    rx, ry = 29.0, 21.0
    r_rim = 0.60

    for j in range(ny):
        for i in range(nx):
            idx = north_count + j * nx + i
            v = mesh.vertices[idx]
            x0 = 70.0 + 0.5 * i
            y0 = -61.0 + 0.5 * j
            z0 = v.co.z

            # Smoothly protect the North shore, both bridge landings, and the steep West rock bluff
            # (where Large_Rock_South sits at 83.0, -37.5 and the grid ends at x0 = 70.0).
            t_east_guard = smooth(94.0, 108.0, x0)
            y_guard_start = -24.2 * (1.0 - t_east_guard) + (-17.5) * t_east_guard
            y_guard_full = -28.0 * (1.0 - t_east_guard) + (-22.0) * t_east_guard
            w_north_guard = smooth(y_guard_start, y_guard_full, y0)
            x_eff = x0 + 0.65 * max(0.0, -38.5 - y0)
            w_beach_sector = smooth(84.5, 93.5, x_eff)
            w_guard = w_north_guard * w_beach_sector
            if w_guard <= 0.0:
                continue

            prop_w = pin_preservation_weight(x0, y0, pins)

            # Unstretched elliptical coordinate r0 depends ONLY on (x0, y0) so grid stretching
            # is 100% C1-smooth and never bunches at z0 height variations.
            a0 = math.atan2((y0 - cy) / ry, (x0 - cx) / rx)
            mod0 = (
                1.0
                + 0.05 * math.sin(3.0 * a0 + 0.4)
                + 0.035 * math.sin(5.0 * a0 - 0.8)
                + 0.02 * math.cos(7.0 * a0)
            )
            r0 = math.hypot((x0 - cx) / rx, (y0 - cy) / ry) / mod0

            stretch_gate = smooth(0.60, 0.75, r0) * w_guard
            dx = 16.5 * smooth(118.0, 136.0, x0) * stretch_gate
            dy = -15.5 * smooth(-42.0, -61.0, y0) * stretch_gate

            x = x0 + dx
            y = y0 + dy

            # Continuous wrap-around coastal slope parameterized by Euclidean distance d_out_m (meters)
            # outside the elliptical plateau rim r_rim = 0.60, giving an identical ~23.8-deg walkable
            # beach slope across the entire East, Southeast, South, and Southwest coast with zero seams.
            a = math.atan2((y - cy) / ry, (x - cx) / rx)
            mod = (
                1.0
                + 0.05 * math.sin(3.0 * a + 0.4)
                + 0.035 * math.sin(5.0 * a - 0.8)
                + 0.02 * math.cos(7.0 * a)
            )
            r = math.hypot((x - cx) / rx, (y - cy) / ry) / mod
            scale_m = mod * math.hypot(rx * math.cos(a), ry * math.sin(a))
            d_out_m = max(0.0, (r - r_rim) * scale_m)

            if d_out_m <= 0.0:
                h_general = 4.65
            elif d_out_m <= 28.5:
                t_g = d_out_m / 28.5
                h_general = 4.65 - (4.65 - (-7.95)) * ramp_mix(t_g, 0.88)
            else:
                t_deep = clamp((d_out_m - 28.5) / 4.5, 0.0, 1.0)
                h_general = -7.95 - 2.95 * ramp_mix(t_deep, 0.85)

            # Smoothly shave the old 1.5m cliff lip at r0=0.60..0.65 on the East/SE/South beaches
            # while purely adding land (max(z0, h_general)) on the Southwest transition.
            shave_rim_w = smooth(98.0, 106.0, x0) * smooth(-26.0, -31.0, y0) * prop_w
            h_target = h_general * shave_rim_w + max(z0, h_general) * (1.0 - shave_rim_w)

            coast_w = smooth(0.595, 0.65, r0) * w_guard * prop_w
            z_new = z0 * (1.0 - coast_w) + h_target * coast_w

            v.co.x = x
            v.co.y = y
            v.co.z = z_new

    mesh.update()
    n_count, sha_after = north_vertices_sha256(mesh)
    assert n_count == north_count and sha_before == sha_after, (n_count, sha_before, sha_after)
    flat_sea = count_flat_sea_triangles(mesh)
    assert flat_sea == 0, f'Expected 0 flat sea-level triangles on Distant_Islands, got {flat_sea}'
    return {
        'digest': mesh_digest(mesh),
        'north_vertices': n_count,
        'north_sha256': sha_after,
        'flat_sea_triangles': flat_sea,
    }


# ==============================================================================
# 3. NORTH ISLAND (North_Pagoda_Pagoda_Meadow_Ground / north_pagoda.glb)
# ==============================================================================

def reshape_north_island_meadow(meadow_obj, distant_obj, bank_mn_obj):
    dg = bpy.context.evaluated_depsgraph_get()
    surfaces = [BVHTree.FromObject(o, dg) for o in [distant_obj, bank_mn_obj] if o is not None]

    def old_height(x, y):
        hs = []
        for b in surfaces:
            p, _, _, _ = b.ray_cast(Vector((x, y, 70.0)), Vector((0.0, 0.0, -1.0)))
            if p is not None:
                hs.append(p.z)
        return max(hs) if hs else -10.0

    # Read the existing 87 x 83 grid (i in 0..86, j in 0..82) from North_Pagoda_Pagoda_Meadow_Ground
    # so every interior vertex (where existing z >= 3.60m) retains its exact post-sidewalk-repair z!
    old_mesh = meadow_obj.data
    nx_old, ny_old = 86, 82
    assert len(old_mesh.vertices) == (nx_old + 1) * (ny_old + 1), len(old_mesh.vertices)
    existing_z = {}
    existing_orig_z = {}
    orig_attr = old_mesh.attributes.get('sidewalk_original_z')
    for i in range(nx_old + 1):
        for j in range(ny_old + 1):
            k = i * (ny_old + 1) + j
            existing_z[i, j] = old_mesh.vertices[k].co.z
            existing_orig_z[i, j] = orig_attr.data[k].value if orig_attr else old_mesh.vertices[k].co.z

    # Exact grid steps from build_north_pagoda.py:
    dx_step = 56.0 / nx_old   # 0.65116279m
    dy_step = 60.0 / ny_old   # 0.73170732m

    # Main_North bridge end: (52.5, 42.5), North_South bridge start: (67.0, 38.0)
    def bridge_clear_weight(x, y):
        d_mn = math.hypot(x - 52.5, y - 42.5)
        d_ns = math.hypot(x - 67.0, y - 38.0)
        return smooth(4.5, 8.5, d_mn) * smooth(4.5, 8.5, d_ns)

    def main_lobe_sloped(x, y):
        dx, dy = (x - 92.0) / 23.0, (y - 64.0) / 23.0
        a = math.atan2(dy, dx)
        r = math.hypot(dx, dy) / (
            1.0 + 0.045 * math.sin(5.0 * a) + 0.025 * math.sin(9.0 * a + 1.4) + 0.02 * math.sin(13.0 * a)
        )
        if r < 0.51:
            return 5.5
        if r < 0.82:
            return (
                5.5
                - 1.55 * smooth(0.51, 0.82, r)
                + 0.16 * math.sin(x * 0.47) * math.sin(y * 0.43) * smooth(0.51, 0.70, r)
            )
        z_rim = 3.95 + 0.16 * math.sin(x * 0.47) * math.sin(y * 0.43) * (1.0 - smooth(0.82, 1.05, r))
        # Keep North edge <= y=98.5 (inside Mediterranean_Sea y<=100); give East/SE/South 28m walkable run
        north_w = max(0.0, math.sin(a)) ** 2
        r_end = 2.04 * (1.0 - 0.30 * north_w)
        t = clamp((r - 0.82) / (r_end - 0.82), 0.0, 1.0)
        return z_rim - (z_rim - (-7.50)) * ramp_mix(t, 0.85)

    def connector_sloped(x, y):
        r = math.hypot((x - 80.0) / 14.0, (y - 49.0) / 12.0)
        if r <= 0.65:
            return 4.0
        bw = bridge_clear_weight(x, y)
        r_end = 1.10 * (1.0 - bw) + 2.15 * bw
        t = clamp((r - 0.65) / (r_end - 0.65), 0.0, 1.0)
        return 4.0 - (4.0 - (-7.50)) * ramp_mix(t, 0.82)

    def west_lobe_coastal_apron(x, y):
        # Adds an outward coastal slope around the North/NW/West perimeter of the western lobe (58, 54)
        # while staying strictly below Distant_Islands on the interior (r_w <= 1.0) and clear of both bridges.
        dx, dy = (x - 58.0) / 13.2, (y - 54.0) / 14.8
        a = math.atan2(dy, dx)
        # Active on North, NW, West (away from the southern bridge landings and eastern connector)
        dir_w = (1.0 - smooth(-0.35, 0.25, math.cos(a)) * smooth(-0.6, 0.2, -math.sin(a))) * bridge_clear_weight(x, y)
        if dir_w <= 0.01:
            return -10.0
        mod = 1.0 + 0.05 * math.cos(3.0 * a) + 0.04 * math.sin(4.0 * a + 0.6)
        r_w = math.hypot(dx, dy) / mod
        if r_w < 0.86:
            return -10.0
        t = clamp((r_w - 0.88) / (1.95 - 0.88), 0.0, 1.0)
        z_apron = 3.55 - (3.55 - (-7.50)) * ramp_mix(t, 0.82)
        return -10.0 + (z_apron - (-10.0)) * dir_w * smooth(0.86, 0.96, r_w)

    def new_lobe(x, y):
        return max(main_lobe_sloped(x, y), connector_sloped(x, y), west_lobe_coastal_apron(x, y))

    # Lattice extension bounds covering the full sloped North Island footprint:
    # i in [-38 .. 118] -> x in [39.26 .. 140.84]
    # j in [-22 .. 88]  -> y in [17.90 .. 98.39]
    i_min, i_max = -38, 118
    j_min, j_max = -22, 88
    ni = i_max - i_min + 1
    nj = j_max - j_min + 1

    grid_verts = []
    grid_orig_z = []
    grid_lobe = []
    grid_old = []

    for ii in range(ni):
        i = i_min + ii
        x = 64.0 + dx_step * i
        for jj in range(nj):
            j = j_min + jj
            y = 34.0 + dy_step * j
            oh = old_height(x, y)
            lb = new_lobe(x, y)
            if (i, j) in existing_z and existing_z[i, j] >= 3.60:
                # Preserve exact interior plateau & sidewalk-graded elevation!
                z = existing_z[i, j]
                oz = existing_orig_z[i, j]
                lb = max(lb, z)
            else:
                z = max(oh, lb)
                oz = z
            grid_verts.append((x, y, z))
            grid_orig_z.append(oz)
            grid_lobe.append(lb)
            grid_old.append(oh)

    faces = []
    for ii in range(ni - 1):
        for jj in range(nj - 1):
            a = ii * nj + jj
            b = a + nj
            indices = (a, b, b + 1, a + 1)
            # Include cell if new_lobe contributes above Distant_Islands or forms the underwater coastal apron
            if max(grid_lobe[k] - grid_old[k] for k in indices) < 0.025:
                continue
            if max(grid_verts[k][2] for k in indices) <= -7.49 and min(grid_verts[k][2] for k in indices) <= -7.49:
                # Keep a 2-ring underwater floor apron around the toe of the slope, omit far-field empty ocean
                xs = [grid_verts[k][0] for k in indices]
                ys = [grid_verts[k][1] for k in indices]
                cx_m, cy_m = sum(xs) * 0.25, sum(ys) * 0.25
                if math.hypot((cx_m - 92.0) / 23.0, (cy_m - 64.0) / 23.0) > 2.22 and math.hypot((cx_m - 58.0) / 13.2, (cy_m - 54.0) / 14.8) > 2.10:
                    continue
            faces.append((a, b, b + 1))
            faces.append((a, b + 1, a + 1))

    # Compact to only vertices referenced by faces (plus keep clean UVs and sidewalk_original_z)
    used = sorted({vi for f in faces for vi in f})
    remap = {old_i: new_i for new_i, old_i in enumerate(used)}
    compact_verts = [grid_verts[old_i] for old_i in used]
    compact_orig_z = [grid_orig_z[old_i] for old_i in used]
    compact_faces = [tuple(remap[vi] for vi in f) for f in faces]

    old_mats = list(old_mesh.materials)
    new_mesh = bpy.data.meshes.new('Pagoda_Meadow_Ground_Sloped')
    new_mesh.from_pydata(compact_verts, [], compact_faces)
    new_mesh.update()
    for mat in old_mats:
        new_mesh.materials.append(mat)
    uv = new_mesh.uv_layers.new(name='UVMap')
    for poly in new_mesh.polygons:
        poly.use_smooth = True
        for li in poly.loop_indices:
            co = new_mesh.vertices[new_mesh.loops[li].vertex_index].co
            uv.data[li].uv = (co.x * 0.25, co.y * 0.25)

    attr = new_mesh.attributes.new('sidewalk_original_z', 'FLOAT', 'POINT')
    for d, oz in zip(attr.data, compact_orig_z):
        d.value = oz

    meadow_obj.data = new_mesh
    return {
        'digest': mesh_digest(new_mesh),
        'flat_sea_triangles': count_flat_sea_triangles(new_mesh),
    }


# ==============================================================================
# 4. GROUND COVER RESEATING & SCOPED EXPORTS
# ==============================================================================

def reseat_ground_cover(surfaces_old, surfaces_new):
    def sample_height(surfaces, x, y):
        vals = []
        for s in surfaces:
            p, _, _, _ = s.ray_cast(Vector((x, y, 60.0)), Vector((0.0, 0.0, -1.0)))
            if p is not None:
                vals.append(p.z)
        return max(vals) if vals else None

    moved = {}
    for fname in ['gscatter_ground_cover_instances.json', 'north_pagoda_cover.json']:
        path = PROJECT / 'assets' / fname
        rows = json.loads(path.read_text())
        count = 0
        for row in rows:
            x, old_z, neg_y = row['origin']
            y = -neg_y
            h_old = sample_height(surfaces_old, x, y)
            h_new = sample_height(surfaces_new, x, y)
            if h_old is not None and h_new is not None:
                dh = h_new - h_old
                if abs(dh) > 0.001:
                    row['origin'][1] = old_z + dh
                    count += 1
        path.write_text(json.dumps(rows, separators=(',', ':')))
        out_copy = OUT / fname
        if out_copy.exists():
            out_copy.write_text(json.dumps(rows, separators=(',', ':')))
        moved[fname] = count
    return moved


def build_and_export():
    cliff = bpy.data.objects.get('Cliff_Terrain') or bpy.data.objects.get('Cliff_Terrain-col')
    distant = bpy.data.objects.get('Distant_Islands') or bpy.data.objects.get('Distant_Islands-col')
    meadow = bpy.data.objects.get('North_Pagoda_Pagoda_Meadow_Ground')
    bank_mn = bpy.data.objects.get('Landing_Bank_Main_North')
    bank_ms = bpy.data.objects.get('Landing_Bank_Main_South')
    bank_ns = bpy.data.objects.get('Landing_Bank_North_South')
    assert cliff and distant and meadow, (cliff, distant, meadow)

    bpy.context.view_layer.update()
    dg_old = bpy.context.evaluated_depsgraph_get()
    surfaces_old = [
        BVHTree.FromObject(o, dg_old)
        for o in [cliff, distant, meadow, bank_mn, bank_ms, bank_ns]
        if o is not None
    ]

    pins = collect_prop_pins(bpy.context.scene)

    main_report = reshape_main_island(cliff, pins)
    south_report = reshape_south_island(distant, pins)
    north_report = reshape_north_island_meadow(meadow, distant, bank_mn)

    bpy.context.view_layer.update()
    dg_new = bpy.context.evaluated_depsgraph_get()
    surfaces_new = [
        BVHTree.FromObject(o, dg_new)
        for o in [cliff, distant, meadow, bank_mn, bank_ms, bank_ns]
        if o is not None
    ]
    grass_moved = reseat_ground_cover(surfaces_old, surfaces_new)

    # 1. Export assets/bridge_approach_terrain.glb & improvements/bridge_approach_terrain.blend
    old_cliff_name = cliff.name
    cliff.name = 'Cliff_Terrain'
    bpy.ops.object.select_all(action='DESELECT')
    cliff.select_set(True)
    bpy.context.view_layer.objects.active = cliff
    bpy.ops.export_scene.gltf(
        filepath=str(PROJECT / 'assets/bridge_approach_terrain.glb'),
        export_format='GLB',
        use_selection=True,
        export_cameras=False,
        export_lights=False,
        export_animations=False,
    )
    bpy.data.libraries.write(
        str(OUT / 'bridge_approach_terrain.blend'),
        {cliff},
        fake_user=True,
        compress=True,
    )
    cliff.name = old_cliff_name

    # 2. Export assets/pagoda_sidewalk_terrain.glb & improvements/pagoda_sidewalk_terrain.blend
    sidewalk_clones = []
    for src_obj, clone_name in [(distant, 'Sidewalk_Distant_Islands'), (bank_mn, 'Sidewalk_Landing_Bank_Main_North')]:
        c = src_obj.copy()
        c.data = src_obj.data.copy()
        c.name = clone_name
        bpy.context.scene.collection.objects.link(c)
        sidewalk_clones.append(c)
    bpy.ops.object.select_all(action='DESELECT')
    for c in sidewalk_clones:
        c.select_set(True)
    bpy.context.view_layer.objects.active = sidewalk_clones[0]
    bpy.ops.export_scene.gltf(
        filepath=str(PROJECT / 'assets/pagoda_sidewalk_terrain.glb'),
        export_format='GLB',
        use_selection=True,
        export_cameras=False,
        export_lights=False,
        export_animations=False,
    )
    bpy.data.libraries.write(
        str(OUT / 'pagoda_sidewalk_terrain.blend'),
        set(sidewalk_clones),
        fake_user=True,
        compress=True,
    )
    for c in sidewalk_clones:
        bpy.data.objects.remove(c, do_unlink=True)

    # 3. Export assets/south_garden_terrain.glb & update improvements/south_garden.blend
    sg_clones = []
    for src_obj, clone_name in [
        (distant, 'SouthGarden_Distant_Islands'),
        (bank_ms, 'SouthGarden_Landing_Bank_Main_South'),
        (bank_ns, 'SouthGarden_Landing_Bank_North_South'),
    ]:
        c = src_obj.copy()
        c.data = src_obj.data.copy()
        c.name = clone_name
        bpy.context.scene.collection.objects.link(c)
        sg_clones.append(c)
    bpy.ops.object.select_all(action='DESELECT')
    for c in sg_clones:
        c.select_set(True)
    bpy.context.view_layer.objects.active = sg_clones[0]
    bpy.ops.export_scene.gltf(
        filepath=str(PROJECT / 'assets/south_garden_terrain.glb'),
        export_format='GLB',
        use_selection=True,
        export_cameras=False,
        export_lights=False,
        export_animations=False,
    )
    for c in sg_clones:
        bpy.data.objects.remove(c, do_unlink=True)

    # Update SouthGarden_Distant_Islands inside improvements/south_garden.blend
    bpy.ops.wm.open_mainfile(filepath=str(OUT / 'south_garden.blend'))
    sg_di = bpy.data.objects.get('SouthGarden_Distant_Islands')
    assert sg_di is not None
    with bpy.data.libraries.load(str(OUT / 'pagoda_sidewalk_terrain.blend'), link=False) as (src, dst):
        dst.objects = ['Sidewalk_Distant_Islands']
    loaded_di = dst.objects[0]
    sg_di.data = loaded_di.data.copy()
    sg_di.data.name = 'SouthGarden_Distant_Islands'
    bpy.data.objects.remove(loaded_di, do_unlink=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'south_garden.blend'), compress=True)

    # 4. Update North_Pagoda_Pagoda_Meadow_Ground inside improvements/north_pagoda.blend & export assets/north_pagoda.glb
    bpy.ops.wm.open_mainfile(filepath=str(OUT / 'north_pagoda.blend'))
    np_meadow = bpy.data.objects.get('North_Pagoda_Pagoda_Meadow_Ground')
    assert np_meadow is not None
    with bpy.data.libraries.load(str(OUT / 'pagoda_sidewalk_terrain.blend'), link=False) as (src, dst):
        dst.objects = ['Sidewalk_Distant_Islands', 'Sidewalk_Landing_Bank_Main_North']
    tmp_di, tmp_mn = dst.objects
    bpy.context.scene.collection.objects.link(tmp_di)
    bpy.context.scene.collection.objects.link(tmp_mn)
    bpy.context.view_layer.update()
    reshape_north_island_meadow(np_meadow, tmp_di, tmp_mn)
    bpy.data.objects.remove(tmp_di, do_unlink=True)
    bpy.data.objects.remove(tmp_mn, do_unlink=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'north_pagoda.blend'), compress=True)
    bpy.ops.export_scene.gltf(
        filepath=str(PROJECT / 'assets/north_pagoda.glb'),
        export_format='GLB',
        export_cameras=False,
        export_lights=False,
        export_animations=False,
    )

    report = {
        'main_island': main_report,
        'south_island': south_report,
        'north_island': north_report,
        'grass_reseated': grass_moved,
    }
    for path in [PROJECT / 'assets/island_shore_slopes.json', OUT / 'island_shore_slopes.json']:
        path.write_text(json.dumps(report, indent=2))
    return report


def install_saved():
    path = bpy.data.filepath
    cliff_dst = bpy.data.objects.get('Cliff_Terrain-col') or bpy.data.objects.get('Cliff_Terrain')
    di_dst = bpy.data.objects.get('Distant_Islands-col') or bpy.data.objects.get('Distant_Islands')
    pm_dst = bpy.data.objects.get('North_Pagoda_Pagoda_Meadow_Ground')
    assert cliff_dst is not None and di_dst is not None and pm_dst is not None, (cliff_dst, di_dst, pm_dst)

    # 1. Install Cliff_Terrain from bridge_approach_terrain.blend
    with bpy.data.libraries.load(str(OUT / 'bridge_approach_terrain.blend'), link=False) as (src, dst):
        dst.objects = ['Cliff_Terrain']
    cliff_src = dst.objects[0]
    cliff_dst.data = cliff_src.data
    bpy.data.objects.remove(cliff_src, do_unlink=True)

    # 2. Install Distant_Islands from pagoda_sidewalk_terrain.blend
    with bpy.data.libraries.load(str(OUT / 'pagoda_sidewalk_terrain.blend'), link=False) as (src, dst):
        dst.objects = ['Sidewalk_Distant_Islands']
    di_src = dst.objects[0]
    di_dst.data = di_src.data
    bpy.data.objects.remove(di_src, do_unlink=True)

    # 3. Install North_Pagoda_Pagoda_Meadow_Ground from north_pagoda.blend
    with bpy.data.libraries.load(str(OUT / 'north_pagoda.blend'), link=False) as (src, dst):
        dst.objects = ['North_Pagoda_Pagoda_Meadow_Ground']
    pm_src = dst.objects[0]
    pm_dst.data = pm_src.data
    bpy.data.objects.remove(pm_src, do_unlink=True)

    # 4. Sync GScatter_*_Meadow and North_Pagoda_Meadow_* point heights
    rows = json.loads((PROJECT / 'assets/gscatter_ground_cover_instances.json').read_text())
    pagoda_rows = json.loads((PROJECT / 'assets/north_pagoda_cover.json').read_text())
    lookup = {(r['asset'], round(r['origin'][0], 3), round(-r['origin'][2], 3)): r['origin'][1] for r in rows + pagoda_rows}

    for i in range(3):
        obj = bpy.data.objects.get(f'North_Pagoda_Meadow_{i}')
        if obj is None:
            continue
        pts = [r for r in pagoda_rows if r['asset'] == f'GScatter_ShortSward_{i}']
        mesh = bpy.data.meshes.new(f'North_Pagoda_Meadow_{i}_SlopedSynced')
        mesh.from_pydata([(r['origin'][0], -r['origin'][2], r['origin'][1]) for r in pts], [], [])
        rot = mesh.attributes.new('rotation', 'FLOAT_VECTOR', 'POINT')
        scl = mesh.attributes.new('scale', 'FLOAT_VECTOR', 'POINT')
        for j, r in enumerate(pts):
            rot.data[j].vector = r['blender_rotation']
            scl.data[j].vector = r['blender_scale']
        obj.data = mesh

    synced = 0
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH' or not (obj.name.startswith('GScatter_') and obj.name.endswith('_Meadow')):
            continue
        asset = obj.name.removesuffix('_Meadow')
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        inv = obj.matrix_world.inverted()
        for v in bm.verts:
            p = obj.matrix_world @ v.co
            key = (asset, round(p.x, 3), round(p.y, 3))
            if key in lookup:
                p.z = lookup[key]
                v.co = inv @ p
                synced += 1
        bm.to_mesh(obj.data)
        bm.free()

    bpy.context.scene['island_shore_slopes'] = (
        'Outward coastal land slopes and walkable water/seabed beaches on Main, North, and South islands; scoped exports only.'
    )
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)
    return {
        'saved': path,
        'cliff_digest': mesh_digest(cliff_dst.data),
        'distant_digest': mesh_digest(di_dst.data),
        'meadow_digest': mesh_digest(pm_dst.data),
        'meadow_points_synced': synced,
    }
