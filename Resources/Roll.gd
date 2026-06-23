@tool class_name Roll extends RichTextEffect
## Roll animations.
## Rotates the characters to make a rolling animation.

## [roll speed=20.0]
var bbcode := "roll"

func _process_custom_fx(c: CharFXTransform):
	var speed: float = c.env.get("speed", 20.0)
	c.transform *= Transform2D(c.elapsed_time*speed, Vector2(c.offset.x, c.offset.y-6))
	return true
