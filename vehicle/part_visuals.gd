class_name PartVisuals
## Builds the 3D look of each part. Shared by the garage and the driving game,
## so a part looks the same in both. Parts with no special look are a plain
## coloured cube, so a new part in parts.json shows up without any code.


## Returns a Node3D centred on the part's grid cell. Turn it with its basis
## (the garage and vehicle do), and any thin "shape" boxes turn with it.
## Propellers have a child called "Spinner" that the vehicle spins.
static func create(id: String, def: Dictionary) -> Node3D:
	var color := Color(def.get("color", "#cccccc"))
	var root := Node3D.new()
	root.name = id.capitalize()

	if def.has("wheel"):
		var r := float(def.wheel.get("radius", 0.45))
		root.add_child(cylinder(r, 0.4, color, Vector3(0, 0, PI / 2)))
		root.add_child(cylinder(r * 0.45, 0.42, Color("#9a9a9a"), Vector3(0, 0, PI / 2)))
		return root

	# Thin parts (plates, walls, trays) look exactly like their collision boxes.
	# The first box is the main piece; the rest (like a tray's rim) are a bit darker.
	if def.has("shape"):
		var first := true
		for b in PartCatalog.shape_boxes(def):
			var size: Vector3 = b.size
			root.add_child(box((size - Vector3.ONE * 0.02).max(Vector3.ONE * 0.02), b.offset, color if first else color.darkened(0.25)))
			first = false
		return root

	match id:
		"seat":
			root.add_child(box(Vector3(0.9, 0.3, 0.9), Vector3(0, -0.35, 0), color))
			root.add_child(box(Vector3(0.9, 0.8, 0.2), Vector3(0, 0.05, 0.35), color))
		"float":
			root.add_child(cylinder(0.45, 0.95, color, Vector3(PI / 2, 0, 0)))
		"propeller", "air_propeller":
			root.add_child(cylinder(0.15, 0.6, Color("#5a6270"), Vector3(PI / 2, 0, 0)))
			var blades := Node3D.new()
			blades.name = "Spinner"
			blades.position = Vector3(0, 0, 0.3)
			blades.add_child(box(Vector3(0.9, 0.12, 0.05), Vector3.ZERO, color))
			blades.add_child(box(Vector3(0.12, 0.9, 0.05), Vector3.ZERO, color))
			root.add_child(blades)
		"wing", "flat_wing":
			# A thin board with a rounder front edge. (It still collides like a full cube.)
			root.add_child(box(Vector3(0.98, 0.08, 0.98), Vector3(0, -0.2, 0), color))
			root.add_child(cylinder(0.06, 0.98, color, Vector3(0, 0, PI / 2), Vector3(0, -0.2, -0.46)))
		"spring":
			# A base plate at the back, a coil, and a foot that kicks out forwards
			# (the part's facing). The vehicle moves "Foot" and stretches "Coil" when it fires.
			root.add_child(box(Vector3(0.95, 0.95, 0.2), Vector3(0, 0, 0.38), Color("#5a6270")))
			var coil := Node3D.new()
			coil.name = "Coil"
			coil.position = Vector3(0, 0, 0.28) # the coil grows forwards from the base
			var rings := 4
			for i in rings:
				var ring := cylinder(0.3, 0.08, color, Vector3(PI / 2, 0, 0), Vector3(0, 0, -(i + 0.5) * 0.55 / rings))
				coil.add_child(ring)
			coil.add_child(cylinder(0.08, 0.55, Color("#9a9a9a"), Vector3(PI / 2, 0, 0), Vector3(0, 0, -0.275)))
			root.add_child(coil)
			var foot := box(Vector3(0.8, 0.8, 0.12), Vector3(0, 0, -0.38), Color("#e8a33d"))
			foot.name = "Foot"
			root.add_child(foot)
		"engine":
			root.add_child(box(Vector3(0.9, 0.7, 0.9), Vector3(0, -0.15, 0), color))
			root.add_child(cylinder(0.08, 0.5, Color("#333333"), Vector3.ZERO, Vector3(0.25, 0.35, 0.3)))
		_:
			root.add_child(box(Vector3.ONE * 0.98, Vector3.ZERO, color))
	return root


static func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	return m


static func box(size: Vector3, offset: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material(color)
	mi.mesh = mesh
	mi.position = offset
	return mi


static func cylinder(radius: float, height: float, color: Color, rot: Vector3, offset := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.material = material(color)
	mi.mesh = mesh
	mi.rotation = rot
	mi.position = offset
	return mi


## A small square icon in the part's colour, for buttons.
static func icon(def: Dictionary, size := 20) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(def.get("color", "#cccccc")))
	return ImageTexture.create_from_image(img)
