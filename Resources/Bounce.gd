@tool class_name Bounce extends RichTextEffect
## Bounces the characters.

var bbcode := "bounce"

func _process_custom_fx(c: CharFXTransform):
	var bounce := pow((fmod(8.0 * c.elapsed_time + c.range.x / 4.0, 4.0) - 2.0), 2.0) / 4.0
	c.offset.y = 12.0 * bounce - 8.0
	return true
