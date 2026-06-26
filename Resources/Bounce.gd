@tool class_name Bounce extends RichTextEffect
## Bounces the characters.


var animated := true
var bbcode := "bounce"


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


func _process_custom_fx(c: CharFXTransform) -> bool:
	if animated == true:
		var bounce := pow((fmod(8.0 * c.elapsed_time + c.range.x / 4.0, 4.0) - 2.0), 2.0) / 4.0
		c.offset.y = 12.0 * bounce - 8.0
		return true
	return false
