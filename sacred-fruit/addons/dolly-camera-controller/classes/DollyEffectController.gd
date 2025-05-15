@tool
@icon("res://addons/dolly-camera-controller/assets/icons/DollyIcon.svg")
extends Node
class_name DollyEffectController
## A script used to make a DollyZoom effect.
## @experimental
## [br]
## Instanciate it and attach it to a camera.[br]
## The controller will adjust the camera FOV
## depending of the distance between the camera and the tacked
## subject or start distance.[br]
## [br]
## [b]Dolly Zoom Effect (Vertigo Effect)[/b]
## [br]
## The [b]Dolly Zoom[/b] is a camera technique where the
## camera moves closer or farther from a subject while
## zooming in or out to keep the subject the same size.
## This creates a disorienting effect where the background
## appears to expand or contract.
## [br]
## [b]How It Works:[/b] [br]
## - Moving [b]forward[/b] (dolly in) → Zoom [b]out[/b]. [br]
## - Moving [b]backward[/b] (dolly out) → Zoom [b]in[/b]. [br]
## [br]
## [b]Famous Examples:[/b] [br]
## - [i]Vertigo[/i] (1958) – First use of the effect. [br]
## - [i]Jaws[/i] (1975) – Iconic shark attack realization scene. [br]
## - [i]Goodfellas[/i] (1990) – Used to show paranoia. [br]
## [br]
## This effect is widely used in filmmaking to create tension and unease. [br]
## [br]
## Wikipedia article : [url]https://en.wikipedia.org/wiki/Dolly_zoom[/url] [br]



#region Exported Parameters
## Is the effect active
@export
var enabled: bool = true

## How much is the dolly effect applied
@export_range(0.0, 1.0)
var amount: float = 1.0

@export_category("Camera")

## The camera instance where the dolly effect is applied
@export
var camera: Camera3D

## The base FOV used before dolly
@export_range(1.0, 179.0)
var camera_fov: float = 75.0

## The Camera distance for near culling
@export_range(0.0, 10.0)
var camera_near: float = 0.05

## Does the dolly effect move the near culling plane
@export
var move_near_culling: bool = true

## The width of the camera optic
@export
var camera_width: float = 1.0 : set=set_cameraera_width

@export_category("Subject")

@export_subgroup("Distance")

## The start distance to the where the dolly zoom start
@export
var start_distance: float = 1.0 : set=set_start_distance

## The distance to the subject
@export
var distance: float = 1.0 : set=set_distance

@export_subgroup("Subject Instance")

## Do we use a 3d instance to calcutlate distance s(0.0 : no, 1.0 : use instance)
@export_range(0.0, 1.0)
var use_subject: float = 0.0

## The subject instance used to calculate distance between camera and subject
@export
var subject: Node3D = null

## Offest between subject origin and the focused point
@export
var subject_offset: Vector3 = Vector3.ZERO

## An action used to set the start distance
## of the effect from the instance of a subject
@export_tool_button("Set start distance")
var action_set_distance = set_distance_from_subject
#endregion


#region Constants
## The minimum distance between camera and subject that we consider to apply a dolly zoom effect
const MINIMUM_DISTANCE: float = 0.00000001

## The lowest focal that can be used by the camera
const MINIMUM_FOCAL: float = 0.00000001

## The lowest FOV value used by a camera node.[br](Used to avoid warning)
const MINIMUM_CAMERA_INSTANCE_FOV: float = 1.0

## The max FOV value used by a camera node.[br](Used to avoid warning)
const MAXIMUM_CAMERA_INSTANCE_FOV: float = 179.0

const CLASS_NAME: String = "DollyEffectController"
#endregion


#region Local Variables
# ...
#endregion



#region Static Functions
## A static function used to convert a FOV (deg) to focal (mm) [br]
## [br]
## [param fov] The FOV to convert [br]
## [param camera_width] The width of the camera optic [br]
## [br]
## return the focal value
static func fov_to_focal(fov: float, camera_width: float = 1.0) -> float:
	var f: float = deg_to_rad(fov)
	return (camera_width / 2.0) / tan(f / 2.0)


## A static function used to convert a focal (mm) to a FOV (deg) [br]
## [br]
## [param focal] The focal to convert [br]
## [param camera_width] The width of the camera optic [br]
## [br]
## return the FOV value
static func focal_to_fov(focal: float, camera_width: float = 1.0) -> float:
	return rad_to_deg(2.0 * atan((camera_width / 2.0) / max(focal, MINIMUM_FOCAL)))


## A function that calculate the FOV to make a dolly zoom effect [br]
## [br]
## [param start_fov] The FOV to that the effect started with [br]
## [param start_distance] The distance where the effect started [br]
## [param current_distance] How far the camera currently is [br]
## [param camera_width] The width of the camera optic [br]
## [br]
## return the FOV to apply to the camera
static func dollyzoom(start_fov: float, start_distance: float, current_distance: float, camera_width: float = 1.0) -> float:
	var start_focal: float = fov_to_focal(start_fov, camera_width)
	var start_size: float = start_focal / max(start_distance, MINIMUM_DISTANCE) # avoid 0 div
	var current_focal = start_size * current_distance
	return focal_to_fov(current_focal)
#endregion



#region Functions
func _ready() -> void:
	if not camera:
		push_warning(
			"[{0}] \"{1}\" : no camera instance given."
			.format(["DollyEffectController", name]))


func  _process(delta: float) -> void:
	_process_dolly()


## Apply the dolly effect to the camera instance [br]
func _process_dolly() -> void:
	# Do we apply the effect 
	if not enabled: return
	
	# if no camera instance to use abort
	if not camera: return
	
	# The distance that will be used to calculate dolly effect
	var dist: float = distance
	
	# Calculate the distance that we consider for the effect
	if subject and use_subject > 0.0:
		var real_distance = camera.global_position.distance_to(subject.global_position + subject_offset)
		dist += (real_distance - distance) * use_subject
	
	# Move culling near plane
	if move_near_culling:
		camera.near = max(camera_near + (dist - start_distance) * amount, camera_near)
	else:
		camera.near = camera_near
	
	# Do dolly logic here
	var new_fov = dollyzoom(camera_fov, start_distance, dist)
	new_fov = min(MAXIMUM_CAMERA_INSTANCE_FOV, max(MINIMUM_CAMERA_INSTANCE_FOV, new_fov))
	camera.fov = camera_fov + (new_fov - camera_fov) * amount
#endregion



#region Getter & Setters
func set_distance_from_subject() -> void:
	if subject and camera:
		var d: float = camera.global_position.distance_to(subject.global_position)
		set_start_distance(d)


func set_distance(value: float) -> void:
	if value < 0.0:
		distance = 0.0
	else:
		distance = value


func set_start_distance(value: float) -> void:
	if value < 0.0:
		start_distance = 0.0
	else:
		start_distance = value


func set_cameraera_width(value: float) -> void:
	if value < 0.0:
		camera_width = 0.0
	else:
		camera_width = value


func set_use_subject(value: float) -> void:
	use_subject = min(max(0.0, value), 1.0)
	if not subject and use_subject > 0.0:
			push_warning(
				"[{0}] \"{1}\" : no subject instance given to calculate distance."
				.format(["DollyEffectController", name]))
#endregion



#region overrides
func _to_string() -> String:
	var res: String = "[DollyEffectController]\n"
	res += "\t - enabled : " + str(enabled) + "\n"
	res += "\t - amount : " + str(amount) + "\n"
	res += "--- Camera ---\n"
	res += "\t - Camera : " + str(camera) + "\n"
	res += "\t - camera_fov : " + str(camera_fov) + "\n"
	res += "\t - camera_near : " + str(camera_near) + "\n"
	res += "\t - move_near_culling : " + str(move_near_culling) + "\n"
	res += "\t - camera_width : " + str(camera_width) + "\n"
	res += "\t - start_distance : " + str(start_distance) + "\n"
	res += "--- Subject ---\n"
	res += "\t - distance : " + str(distance) + "\n"
	res += "\t - use_subject : " + str(use_subject) + "\n"
	res += "\t - subject : " + str(subject) + "\n"
	res += "\t - subject_offset : " + str(subject_offset) + "\n"
	return res
#endregion
