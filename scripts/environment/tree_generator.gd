extends Node2D

const TreeScript = preload("res://scripts/environment/tree.gd")

const CLUSTER_COUNT = 6       # number of tree clusters
const TREES_PER_CLUSTER_MIN = 3
const TREES_PER_CLUSTER_MAX = 6
const CLUSTER_SPREAD = 140.0  # radius within which trees in a cluster scatter
const WORLD_HALF = 1300.0
const CLEAR_RADIUS = 320.0    # keep the spawn area open
const MIN_TREE_SPACING = 55.0 # minimum gap between individual trees

var _player: Node2D = null

func _ready() -> void:
	z_index = 6
	z_as_relative = false
	_generate()

func _process(_delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
	for child in get_children():
		child._player = _player

func _generate() -> void:
	var placed: Array = []
	for _c in CLUSTER_COUNT:
		var cluster_center := _random_world_pos()
		var count := randi_range(TREES_PER_CLUSTER_MIN, TREES_PER_CLUSTER_MAX)
		for _t in count:
			for _attempt in 15:
				var offset := Vector2(randf_range(-CLUSTER_SPREAD, CLUSTER_SPREAD),
						randf_range(-CLUSTER_SPREAD, CLUSTER_SPREAD))
				var pos := cluster_center + offset
				if pos.length() < CLEAR_RADIUS:
					continue
				var ok := true
				for p in placed:
					if pos.distance_to(p) < MIN_TREE_SPACING:
						ok = false
						break
				if not ok:
					continue
				placed.append(pos)
				var tree := Node2D.new()
				tree.set_script(TreeScript)
				tree.position = pos
				add_child(tree)
				break

func _random_world_pos() -> Vector2:
	for _attempt in 30:
		var p := Vector2(randf_range(-WORLD_HALF, WORLD_HALF), randf_range(-WORLD_HALF, WORLD_HALF))
		if p.length() > CLEAR_RADIUS:
			return p
	return Vector2(WORLD_HALF * 0.6, 0.0)
