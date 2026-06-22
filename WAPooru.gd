@tool class_name WAPooruClient extends HTTPRequest

#region Variables
enum Get {
	TREE,
	LANG,
	IMG
}

var query: int = 0
var trees: Array = []				# List of langs trees (i.e. main dir)
var i_url: Array = []				# List of langs' images (blob urls)
var blobs: Array = []				# List of img blobs to use as texture
var waifu: PackedStringArray = []	# List of waifu image cache paths

var files_path: String = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)+"/WAPooru"
var waifu_path: String = files_path+"/Waifus"				## The download directory
var cache_path: String = OS.get_user_data_dir()+"/cache"	## Caches to %AppData%/Roaming/WAPooru
var saves_path: String = cache_path+"/ImgList"				## Save file path

@export var git_url := "https://api.github.com/repos/cat-milk/Anime-Girls-Holding-Programming-Books/git"
@export var headers := ["Accept: image/avif,image/webp,image/png,image/svg+xml,image/*;q=0.8,*/*;q=0.5"]

@export_category("Terminal")
@export var print_data := true			## Show or hide the requested data.
@export var print_image_files := true	## Prints the loaded image files.

@onready var languages: VBoxContainer = $%Languages
@onready var waifus: HFlowContainer = $%Waifus
#endregion

func _ready() -> void:
	if not Engine.is_editor_hint():
		_init_directory(cache_path)

		get_repo_tree()
		await request_completed
		set_langs_buttons(trees)

		var endpoint: String = trees[randi_range(0, trees.size()-1)]["url"].trim_prefix(git_url)
		get_language(endpoint)
		await request_completed

		set_waifu_thumbnails(i_url)


## The main function that requests various endpoints.
## [param url] is the main url that hosts the API.
## [param endpoint] is the request endpoint, e.g. /trees/master.
## [param method] is the method which uses this function for specific requests.
func WAPooruClient(url: String, endpoint: String, method: String) -> void:
	print("Request endpoint: %s" % url + endpoint + "\n")

	if not url == "" or not endpoint == "":
		var error: int = 0
		error = request(url + endpoint, headers, HTTPClient.METHOD_GET)
		if error == OK: print("✓ %s() run successfully." % method)
		else: print("❌ %s() failed." % method)
	else:
		print("❌ WAPooru() failed. The url or endpoint cannot be empty.")


## Returns a Dictionary of trees, i.e. directories in a repo branch.
## [param endpoint] is the request endpoint.
func get_repo_tree(endpoint: String = "/trees/master") -> void:
	query = Get.TREE
	WAPooruClient(git_url, endpoint, "get_repo_tree")


## Returns a Dictionary of waifus w/ coding books.
## [param endpoint] is the request endpoint.
func get_language(endpoint: String) -> void:
	query = Get.LANG
	WAPooruClient(git_url, endpoint, "get_language")


## Returns a blob content of waifus w/ coding books.
## [param endpoint] is the request endpoint.
func get_waifu_blob(endpoint: String) -> void:
	query = Get.IMG
	WAPooruClient(git_url, endpoint, "get_waifu_blob")


## Creates the languages buttons, then sets as children of Languages node.
## [param list] is an array of objects that contains the path and url of a language.
func set_langs_buttons(list: Array) -> void:
	if not list.is_empty():
		for item in list:
			var button := Button.new()
			button.name = item["path"]
			button.text = item["path"]
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			button.set_meta("url", item["url"])
			button.pressed.connect(_on_langs_btn_pressed.bind(button.get_meta("url")))
			languages.add_child(button, true)


## Loads image from buffer and sets a new ImageTexture based from its supported Image format.
## [param buffer] is the buffer to load image data from.
func load_image_from_buffer(buffer: PackedByteArray) -> ImageTexture:
	if buffer.is_empty():
		return null

	var image := Image.new()
	var error := ERR_INVALID_DATA

	var signatures: Dictionary[StringName, PackedByteArray] = {
		"png": [137, 80, 78, 71, 13, 10, 26, 10],
		"jpg": [255, 216, 255],
		"webp": [82, 73, 70, 70],
		"bmp": [66, 77],
		"gif": [71, 73, 70]
	}

	if buffer.size() >= 8 and buffer.slice(0, 8) == signatures["png"]:
		error = image.load_png_from_buffer(buffer)
	elif buffer.size() >= 3 and buffer.slice(0, 3) == signatures["jpg"]:
		error = image.load_jpg_from_buffer(buffer)
	elif buffer.size() >= 4 and buffer.slice(0, 4) == signatures["webp"]:
		error = image.load_webp_from_buffer(buffer)
	elif buffer.size() >= 2 and buffer.slice(0, 2) == signatures["bmp"]:
		error = image.load_bmp_from_buffer(buffer)
	elif buffer.size() >= 3 and buffer.slice(0, 3) == signatures["gif"]:
		print("GIF format detected, but unsupported by Image load buffers.")
		return null
	else:
		error = image.load_tga_from_buffer(buffer) # fallback

	if error == OK:
		return ImageTexture.create_from_image(image)
	else:
		print("Failed to parse image from buffer. Error code: ", error)

	return null


## Loop thru i_url[] and make request each url.
## [param list] is the array which contains the blobs to request from.'
## list = i_url[{ "path": item["path"], "url": item["url"] }]
func set_waifu_thumbnails(list: Array) -> void:
	if not list.is_empty():
		for item in list:
			var endpoint: String = item["url"].trim_prefix(git_url)
			get_waifu_blob(endpoint)
			await request_completed


## Creates a texture after each image blob request.
## [param index] is the current index in the array of blobs.
func set_thumbnail_texture(index: int) -> void:
	var buffer = Marshalls.base64_to_raw(blobs[index]["content"])
	if not buffer == null:
		var imagetexture = load_image_from_buffer(buffer)
		if not imagetexture == null:
			var texture = imagetexture
			var thumbnail := TextureButton.new()

			# Save images as resource to load by valid resource paths
			var image_name: String = i_url[i_url.find(blobs[index]["url"])]["path"]
			var texture_res_path: String = "user://%s.res" % image_name
			ResourceSaver.save(texture, texture_res_path)

			# Bind _on_thumbnail_pressed & its args to TextureButton.pressed signal
			#thumbnail.pressed.connect(_on_thumbnail_pressed.bind(texture_res_path, cache_path+"/"+img_file))
			thumbnail.mouse_entered.connect(_on_thumbnail_hovered.bind(thumbnail))
			thumbnail.mouse_exited.connect(_on_thumbnail_unhover.bind(thumbnail))

			thumbnail.texture_normal = texture
			#thumbnail.name = img_file
			thumbnail.ignore_texture_size = true
			thumbnail.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
			thumbnail.custom_minimum_size = Vector2((waifus.size.x/3)-10, (waifus.size.y/3)-10)
			thumbnail.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			waifus.add_child(thumbnail, true)


#region
## Gets a list of langs trees (i.e. main dir). Use to save to trees[].
## [param data] is the object to get and check items from.
func get_trees(data: Dictionary) -> Array:
	var list: Array = []
	for item in data["tree"]:
		if item["type"] == "tree":
			list.append(item)
	return list


## Gets a list of langs' images (blob urls). Use to save to i_url[].
## [param data] is the object to get and check items from.
func get_langs(data: Dictionary) -> Array:
	var list: Array = []
	for item in data["tree"]:
		if item["type"] == "blob":
			var obj := { "path": item["path"], "url": item["url"] }
			list.append(obj)
	return list


## Gets a waifu image blob content (base64 String).
## [param data] is the object to get and check items from.
func get_waifu(data: Dictionary) -> Dictionary:
	return { "url": data.get("url"), "content": data.get("content") }
#endregion


func _on_request_completed(_result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var data = parse_JSON(body)
	if not data == null:
		match query:
			Get.TREE:
				trees = get_trees(data)
			Get.LANG:
				i_url = get_langs(data)
			Get.IMG:
				blobs.append(get_waifu(data))
				set_thumbnail_texture(blobs.size()-1)


## Signal when a language button is pressed. get_language() then sends a request to get available images from the language.
func _on_langs_btn_pressed(url: String) -> void:
	var endpoint := url.trim_prefix(git_url)
	get_language(endpoint)


@warning_ignore("unused_parameter")
func _on_thumbnail_pressed(texture_path: String, file_path: String) -> void:
	@warning_ignore("unused_variable")
	var options: Dictionary = { "name": file_path.get_file(), "file": file_path }


@warning_ignore("unused_parameter")
func _on_thumbnail_hovered(button: TextureButton) -> void:
	#button.z_index = 1
	#var tween: Tween = create_tween()
	#tween.tween_property(button, "scale", Vector2(1.15, 1.15), 0.05)
	pass


@warning_ignore("unused_parameter")
func _on_thumbnail_unhover(button: TextureButton) -> void:
	#button.z_index = 0
	#var tween: Tween = create_tween()
	#tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.05)
	pass


## Initializes the directory for images.
## [param path] is the directory path to save and load images from.
func _init_directory(path: String = "") -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_absolute(path)


## Checks for a directory and the images it contains.
## [param path] is the directory path to check and load images from.
func check_images(path: String = "") -> void:
	if not waifus.get_children() == null:
		for node in waifus.get_children():
			node.queue_free()

	var directory := DirAccess.open(path)
	if not directory == null:
		waifu = directory.get_files()
		if FileAccess.open(saves_path, FileAccess.READ) == null:
			save_images(waifu)
		else:
			if not waifu == load_images(saves_path):
				save_images(waifu)
				waifu = load_images(saves_path)
			else:
				if OS.is_debug_build() and print_image_files == true:
					print_rich("Loading cached images at [url underline=hover tooltip='Open directory at %s' href=%s.]%s[/url][wave]...[/wave]" % [cache_path, cache_path, cache_path])

				for img_file in load_images(saves_path):
					if print_image_files == true:
						print_rich("[b][color=green]✓[/color][/b] [url underline=hover tooltip='Open %s cache file.' href=%s]%s[/url]" % [img_file, cache_path+"/"+img_file, img_file])

					var image = Image.load_from_file(cache_path+"/"+img_file)
					var texture = ImageTexture.create_from_image(image)
					var thumbnail := TextureButton.new()

					# Save images as resource to load by valid resource paths
					var texture_res_path: String = "user://%s.res" % img_file
					ResourceSaver.save(texture, texture_res_path)

					# Bind _on_thumbnail_pressed & its args to TextureButton.pressed signal
					thumbnail.pressed.connect(_on_thumbnail_pressed.bind(texture_res_path, cache_path+"/"+img_file))
					thumbnail.mouse_entered.connect(_on_thumbnail_hovered.bind(thumbnail))
					thumbnail.mouse_exited.connect(_on_thumbnail_unhover.bind(thumbnail))

					thumbnail.texture_normal = texture
					thumbnail.name = img_file
					thumbnail.ignore_texture_size = true
					thumbnail.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
					thumbnail.custom_minimum_size = Vector2(350, 350)
					thumbnail.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					waifus.add_child(thumbnail, true)

				if OS.is_debug_build() and print_image_files == true:
					print_rich("[b][color=green][pulse]Loading images completed![/pulse][/color][/b]\n")


## Saves an array of images into a file.
## [param image_array] is an array of image paths.
func save_images(image_array: PackedStringArray) -> void:
	var file := FileAccess.open(saves_path, FileAccess.WRITE)
	file.store_var(image_array, true)
	file.close()


## Loads a save file of images array.
## [param save_file] is the path of the file to load the image array from.
func load_images(save_file: String) -> PackedStringArray:
	var file := FileAccess.open(save_file, FileAccess.READ)
	var loaded_array = file.get_var(true)
	return loaded_array


## Parses JSON and returns as Array, Dictionary, or String.
## [param body] is the received object from a completed request.
func parse_JSON(body: PackedByteArray) -> Variant:
	var json := JSON.new()
	var string: String = body.get_string_from_utf8()
	var error: int = json.parse(string)

	if error == OK:
		var data_got: Variant = json.data
		if typeof(data_got) == TYPE_ARRAY or typeof(data_got) == TYPE_DICTIONARY:
			if print_data == true:
				if not query == Get.IMG:
					print(JSON.stringify(data_got, "\t")+"\n")
			return data_got
		elif typeof(data_got) == TYPE_STRING:
			if print_data == true:
				print("Received blob content.")
			return data_got
		else:
			if print_data == true:
				print("❌ parse_JSON() failed. Unexpected data.")
			return {}
	else:
		if print_data == true:
			print("❌ parse_JSON() error: ", json.get_error_message(), " in ", string, " at line ", json.get_error_line(), ".")
		return {}
