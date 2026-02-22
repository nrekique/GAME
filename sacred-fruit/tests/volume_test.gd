extends Node

# Simple smoke tests for Volume subclasses.

var _enter_called := false

func _ready():
	# damage volume should call apply_damage
	var dmg := preload("res://entities/logic/damage_volume.gd").new()
	dmg.amount = 42
	var actor := Node.new()
	actor.health = 100
	actor.apply_damage = func(a): actor.health -= a

	# signal test
	dmg.connect("body_entered", callable(self, "_on_dmg_enter"))

	dmg._on_body_entered(actor)
	assert(actor.health == 58)
	assert(_enter_called)
	print("[TEST] DamageVolume applied damage and raised signal")


	# checkpoint volume should call GAME.handle_player_death if singleton present
	var stub_game := Node.new()
	stub_game.handle_player_death = func(b,d): stub_game.called = true
	Engine.set_singleton("GAME", stub_game)
	var chk := preload("res://entities/logic/checkpoint_volume.gd").new()
	chk._on_body_entered(actor)
	assert(stub_game.called == true)
	print("[TEST] CheckpointVolume invoked GAME.handle_player_death")

	# spawn blocker should flag a point inside its area
	var sb := preload("res://entities/logic/spawn_blocker_volume.gd").new()
	sb.position = Vector3(1,0,0)
	# assume default collision shape covers origin; we just test helper directly
	assert(sb.blocks_point(Vector3(1,0,0)))
	# GameManager helper should respect the group
	var gm := preload("res://game_manager.gd").new()
	Engine.set_singleton("GAME", gm)
	add_child(sb)  # ensures group membership works
	assert(GAME.is_spawn_blocked(Vector3(1,0,0)))
	print("[TEST] SpawnBlockerVolume and GAME.is_spawn_blocked working")

func _on_dmg_enter(b):
	_enter_called = true

	get_tree().quit()
