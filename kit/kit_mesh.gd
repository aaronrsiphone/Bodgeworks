class_name KitMesh
## Makes the curved meshes for the design kit (kit/kit.gd) in code, so we don't
## need a 3D modelling program:
##   rounded_box  a box with soft, rounded edges (the "toy" look)
##   lathe        a shape spun around an axis, like clay on a pottery wheel (wheels, tanks, hulls)
##   loft         a 2D outline swept through a row of slices (wings, fuselages)
##
## Godot draws the front of a triangle when its corners go clockwise as you look
## at it. _tri() sorts that out, so the builders below only say which way is "out".

## Bends sharper than this many degrees get a hard edge; gentler ones are shaded smooth.
const SMOOTH_ANGLE := 40.0


## A box of `size` whose edges and corners are rounded with `radius`.
## `steps` is how many slices each rounded edge gets (more = smoother).
static func rounded_box(size: Vector3, radius: float, steps := 3) -> ArrayMesh:
	var h := size * 0.5
	var r := minf(radius, minf(h.x, minf(h.y, h.z)) * 0.98)
	var inner := h - Vector3.ONE * r
	var st := _begin()
	# Each of the 6 faces is a grid on the outside of a sharp box. Every grid
	# point is pulled onto the rounded shape: find the nearest point of the
	# smaller "inner" box, then step out from it by r.
	for axis in 3:
		for sgn: float in [-1.0, 1.0]:
			var face_n := Vector3.ZERO
			face_n[axis] = sgn
			var ua := (axis + 1) % 3
			var va := (axis + 2) % 3
			var us := _box_coords(inner[ua], r, steps)
			var vs := _box_coords(inner[va], r, steps)
			for i in us.size() - 1:
				for j in vs.size() - 1:
					var corners := []
					for c: Array in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
						var q := Vector3.ZERO
						q[axis] = sgn * h[axis]
						q[ua] = us[c[0]]
						q[va] = vs[c[1]]
						var core := q.clamp(-inner, inner)
						var d := q - core
						var n := d.normalized() if d.length() > 0.00001 else face_n
						corners.append([core + n * r, n])
					_quad(st, corners, face_n)
	return st.commit()


## Spins a 2D outline around the Y axis. Each profile point is (distance from
## the axis, height). List the points going up the OUTSIDE of the shape, e.g.
## bottom centre -> out -> up -> top centre, so the outside faces outwards.
static func lathe(profile: PackedVector2Array, segments := 24) -> ArrayMesh:
	var st := _begin()
	var normals := _profile_normals(profile, false)
	for s in segments:
		var a0 := TAU * s / segments
		var a1 := TAU * (s + 1) / segments
		for i in profile.size() - 1:
			var n0: Vector2 = normals[i][0]
			var n1: Vector2 = normals[i][1]
			var p0 := profile[i]
			var p1 := profile[i + 1]
			var corners := [
				[_spin(p0, a0), _spin_n(n0, a0)],
				[_spin(p0, a1), _spin_n(n0, a1)],
				[_spin(p1, a1), _spin_n(n1, a1)],
				[_spin(p1, a0), _spin_n(n1, a0)],
			]
			var seg := (p1 - p0)
			var out := _spin_n(Vector2(seg.y, -seg.x).normalized(), (a0 + a1) * 0.5)
			_quad(st, corners, out)
	return st.commit()


## Sweeps a closed 2D outline through `sections` (one Transform3D per slice:
## the outline's x/y go along the slice's basis.x/basis.y, placed at its origin).
## Slices can shrink, slide or turn, which gives tapered and swept wings.
## The two ends are closed off flat.
static func loft(profile: PackedVector2Array, sections: Array, caps := true) -> ArrayMesh:
	var st := _begin()
	var normals := _profile_normals(profile, true)
	var n := profile.size()
	for s in sections.size() - 1:
		var t0: Transform3D = sections[s]
		var t1: Transform3D = sections[s + 1]
		var nb0 := t0.basis.inverse().transposed()
		var nb1 := t1.basis.inverse().transposed()
		for i in n:
			var j := (i + 1) % n
			var na: Vector2 = normals[i][0]
			var nc: Vector2 = normals[i][1]
			var corners := [
				[t0 * _v3(profile[i]), (nb0 * _v3(na)).normalized()],
				[t0 * _v3(profile[j]), (nb0 * _v3(nc)).normalized()],
				[t1 * _v3(profile[j]), (nb1 * _v3(nc)).normalized()],
				[t1 * _v3(profile[i]), (nb1 * _v3(na)).normalized()],
			]
			var out: Vector3 = (corners[0][1] + corners[1][1] + corners[2][1] + corners[3][1]).normalized()
			_quad(st, corners, out)
	if caps:
		_cap(st, profile, sections[0], sections[1])
		_cap(st, profile, sections[-1], sections[-2])
	return st.commit()


# --- 2D outlines (profiles) for loft() and lathe() -------------------------------------

## A wing cross-section, `chord` long (front edge at -chord/2), `thickness` as a
## fraction of the chord. `camber` bends it so it lifts even when level.
static func airfoil(chord: float, thickness := 0.14, camber := 0.03, points := 14) -> PackedVector2Array:
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	for k in points + 1:
		var x := 0.5 - 0.5 * cos(PI * k / points) # bunch points up near the round front edge
		# The classic NACA thickness formula, nudged so the back edge isn't knife-thin.
		var yt := 5.0 * thickness * (0.2969 * sqrt(x) - 0.126 * x - 0.3516 * x * x + 0.2843 * x * x * x - 0.1015 * x * x * x * x)
		yt = maxf(yt, thickness * 0.08)
		var yc := camber * 4.0 * x * (1.0 - x)
		upper.append(Vector2((x - 0.5) * chord, (yc + yt) * chord))
		lower.append(Vector2((x - 0.5) * chord, (yc - yt) * chord))
	# Go round: back edge along the top to the front, then along the bottom back.
	var out := PackedVector2Array()
	for k in range(points, -1, -1):
		out.append(upper[k])
	for k in range(1, points):
		out.append(lower[k])
	return out


## A rectangle with rounded corners, centred on (0, 0).
static func rounded_rect(w: float, h: float, r: float, steps := 4) -> PackedVector2Array:
	r = minf(r, minf(w, h) * 0.5 * 0.999)
	var out := PackedVector2Array()
	var cx := w * 0.5 - r
	var cy := h * 0.5 - r
	for corner: Array in [[cx, cy, 0.0], [-cx, cy, 0.5 * PI], [-cx, -cy, PI], [cx, -cy, 1.5 * PI]]:
		for k in steps + 1:
			var a: float = corner[2] + 0.5 * PI * k / steps
			out.append(Vector2(corner[0] + r * cos(a), corner[1] + r * sin(a)))
	return out


## A lathe outline for a cylinder `height` tall with rounded rims.
## A bevel equal to the radius gives a capsule (round ends).
static func cylinder_profile(radius: float, height: float, bevel: float, steps := 4) -> PackedVector2Array:
	bevel = minf(bevel, minf(radius, height * 0.5) * 0.999)
	var h := height * 0.5
	var out := PackedVector2Array([Vector2(0, -h)])
	for k in steps + 1: # bottom rim
		var a := -0.5 * PI + 0.5 * PI * k / steps
		out.append(Vector2(radius - bevel + bevel * cos(a), -h + bevel + bevel * sin(a)))
	for k in steps + 1: # top rim
		var a := 0.5 * PI * k / steps
		out.append(Vector2(radius - bevel + bevel * cos(a), h - bevel + bevel * sin(a)))
	out.append(Vector2(0, h))
	return out


## A lathe outline for a ring (a tube bent round, like a tyre or a fan duct):
## a rounded rectangle `width` wide (across the ring) and `height` tall, `radius` from the axis.
static func ring_profile(radius: float, width: float, height: float, bevel: float, steps := 4) -> PackedVector2Array:
	# rounded_rect goes anticlockwise, which climbs up the outer side: just what lathe() wants.
	var out := PackedVector2Array()
	for q in rounded_rect(width, height, bevel, steps):
		out.append(q + Vector2(radius, 0))
	out.append(out[0]) # close the loop
	return out


# --- helpers ---------------------------------------------------------------------------

static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## Positions along one side of a rounded box face: the flat middle, plus
## `steps` points round each edge spaced by equal angles (so curves look even).
static func _box_coords(inner: float, r: float, steps: int) -> Array:
	var out := []
	for k in steps + 1:
		out.append(-inner - r * tan(0.25 * PI * (1.0 - float(k) / steps)))
	for k in steps + 1:
		out.append(inner + r * tan(0.25 * PI * float(k) / steps))
	return out


## Two triangles for four corners ([position, normal] each, in order around the quad).
static func _quad(st: SurfaceTool, c: Array, out: Vector3) -> void:
	_tri(st, c[0], c[1], c[2], out)
	_tri(st, c[0], c[2], c[3], out)


## One triangle, turned so that its front faces `out`. Skips squashed (zero-area) ones.
static func _tri(st: SurfaceTool, a: Array, b: Array, c: Array, out: Vector3) -> void:
	var cross: Vector3 = (b[0] - a[0]).cross(c[0] - a[0])
	if cross.length_squared() < 1e-12:
		return
	if cross.dot(out) > 0.0: # Godot wants clockwise when seen from the front
		var tmp := b
		b = c
		c = tmp
	for v: Array in [a, b, c]:
		st.set_normal(v[1])
		st.add_vertex(v[0])


## For each edge of a 2D outline, the normal at its start and end: shared with the
## neighbouring edge if the bend is gentle (smooth), the edge's own if it's sharp.
## `closed` outlines wrap round; open ones (lathe) don't.
static func _profile_normals(p: PackedVector2Array, closed: bool) -> Array:
	var n := p.size()
	var edges := n if closed else n - 1
	var sign := 1.0
	if closed and _area(p) < 0.0:
		sign = -1.0 # clockwise outline: flip so normals still point out
	var edge_n := []
	for i in edges:
		var d := p[(i + 1) % n] - p[i]
		edge_n.append(Vector2(d.y, -d.x).normalized() * sign if d.length() > 1e-6 else Vector2.ZERO)
	var out := []
	for i in edges:
		var here: Vector2 = edge_n[i]
		var prev_i := (i - 1 + edges) % edges if closed else i - 1
		var next_i := (i + 1) % edges if closed else i + 1
		var start := here
		var end := here
		if prev_i >= 0 and _smooth(edge_n[prev_i], here):
			start = (edge_n[prev_i] + here).normalized()
		if next_i < edges and _smooth(here, edge_n[next_i]):
			end = (here + edge_n[next_i]).normalized()
		out.append([start, end])
	return out


static func _smooth(a: Vector2, b: Vector2) -> bool:
	return a != Vector2.ZERO and b != Vector2.ZERO and absf(a.angle_to(b)) < deg_to_rad(SMOOTH_ANGLE)


## Signed area: positive when the outline goes anticlockwise.
static func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		var q := p[(i + 1) % p.size()]
		a += p[i].x * q.y - q.x * p[i].y
	return a * 0.5


## Closes off one end of a loft with a fan of triangles. `other` is the next
## slice in, so we know which way is out.
static func _cap(st: SurfaceTool, p: PackedVector2Array, t: Transform3D, other: Transform3D) -> void:
	var centre := Vector2.ZERO
	for q in p:
		centre += q
	centre /= p.size()
	var c3 := t * _v3(centre)
	var n := t.basis.x.cross(t.basis.y).normalized()
	if n.dot(c3 - other * _v3(centre)) < 0.0:
		n = -n
	for i in p.size():
		_tri(st, [c3, n], [t * _v3(p[i]), n], [t * _v3(p[(i + 1) % p.size()]), n], n)


static func _v3(p: Vector2) -> Vector3:
	return Vector3(p.x, p.y, 0.0)


static func _spin(p: Vector2, a: float) -> Vector3:
	return Vector3(p.x * cos(a), p.y, p.x * sin(a))


static func _spin_n(n: Vector2, a: float) -> Vector3:
	return Vector3(n.x * cos(a), n.y, n.x * sin(a)).normalized()
