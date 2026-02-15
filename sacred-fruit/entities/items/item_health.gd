@tool
class_name ItemHealth
extends Area3D

@export var amount: int = 25
@export var allow_overheal: bool = false
@export var overheal_cap: int = 200
@export var auto_free: bool = true
@export var targetname: String = ""

func _func_godot_apply_properties(props: Dictionary) -> void:
	if props.has("amount"):
		amount = props["amount"] as int
	if props.has("allow_overheal"):
		allow_overheal = (str(props["allow_overheal"]) == "1") or (props["allow_overheal"] as bool)
	if props.has("overheal_cap"):
		overheal_cap = int(props["overheal_cap"])
	if props.has("targetname"):
		targetname = props["targetname"] as String

func _init() -> void:
	monitoring = true
	monitorable = false
	connect("body_entered", _on_body_entered)

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if targetname != "":
		GAME.set_targetname(self, targetname)

func _on_body_entered(body: Node) -> void:
	if Engine.is_editor_hint():
		return
	if body != null and body.is_in_group("PLAYER"):
		var applied := false
		if body.has_method("add_health"):
			body.call("add_health", amount, allow_overheal, overheal_cap)
			applied = true
		elif body.has_method("get") and body.has_method("set"):
			var current = body.get("health")
			var max_health = body.get("max_health")
			if typeof(current) in [TYPE_INT, TYPE_FLOAT] and typeof(max_health) in [TYPE_INT, TYPE_FLOAT]:
				var cap := max_health
				if allow_overheal:
					var max_over = body.get("max_overhealth")
					if typeof(max_over) in [TYPE_INT, TYPE_FLOAT]:
						cap = minf(float(max_over), float(overheal_cap))
				body.set("health", minf(float(current) + float(amount), float(cap)))
				applied = true
		if GAME and GAME.has_method("add_health"):
			GAME.call("add_health", amount, allow_overheal, overheal_cap)
			applied = true
		if applied and auto_free:
			queue_free()
