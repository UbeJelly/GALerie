@tool class_name Roll extends RichTextEffect
## Roll animations.
## Rotates the characters to make a rolling animation.


var animated := true
## [roll speed=20.0]
var bbcode := "roll"


func _set(property: StringName, value: Variant) -> bool:
	if property == "animated":
		animated = value
		return true
	return false


func _get(property: StringName) -> Variant:
	if property == "animated":
		return animated
	return null


func _get_property_list() -> Array[Dictionary]:
	return [{ "name": "animated", "type": TYPE_BOOL }]


func _process_custom_fx(c: CharFXTransform):
	if animated == true:
		var speed: float = c.env.get("speed", 20.0)
		c.transform *= Transform2D(c.elapsed_time*speed, Vector2(c.offset.x, c.offset.y-6))
		return true
	return false
