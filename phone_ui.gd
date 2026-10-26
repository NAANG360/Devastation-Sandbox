extends CanvasLayer

@onready var phone_container = find_child("PhoneContainer", true, false)
@onready var home_screen = find_child("HomeScreen", true, false)
@onready var dialer_screen = find_child("DialerScreen", true, false)
@onready var color_screen = find_child("ColorScreen", true, false)
@onready var color_grid = find_child("ColorGrid", true, false)
@onready var keypad_grid = find_child("KeypadGrid", true, false)

var number_display: Node = null 
var on_screen_y: float
var off_screen_y: float
var is_open: bool = false
var phone_tween: Tween 
var close_bg: Button 

var available_car_colors = [Color.RED, Color.BLUE, Color.GREEN, Color.BLACK, Color.WHITE, Color.YELLOW, Color.CYAN, Color.MAGENTA, Color.ORANGE]

func _ready():
	close_bg = Button.new()
	close_bg.set_anchors_preset(Control.PRESET_FULL_RECT) 
	close_bg.modulate.a = 0.0 
	close_bg.focus_mode = Control.FOCUS_NONE
	close_bg.pressed.connect(toggle_phone)
	add_child(close_bg)
	move_child(close_bg, 0) 
	close_bg.hide()
	
	await get_tree().process_frame
	
	number_display = find_child("NumberDisplay", true, false)
	if not number_display and dialer_screen: number_display = _find_label_fallback(dialer_screen)
	
	if number_display:
		if number_display is Label or number_display is LineEdit: number_display.add_theme_color_override("font_color", Color.BLACK)
		elif number_display is RichTextLabel: number_display.add_theme_color_override("default_color", Color.BLACK)
	
	if phone_container:
		on_screen_y = phone_container.position.y
		off_screen_y = on_screen_y + 1500.0 
		phone_container.position.y = off_screen_y
		phone_container.hide()
	
	_go_to_home()
	
	var d_btn = find_child("DialerAppBtn", true, false)
	if d_btn: d_btn.pressed.connect(_open_dialer)
	var c_btn = find_child("ColorAppBtn", true, false)
	if c_btn: c_btn.pressed.connect(_open_color_app)
	if phone_container:
		for h_btn in phone_container.find_children("HomeBtn", "Button", true, false): h_btn.pressed.connect(_go_to_home)
	
	_setup_color_buttons()
	_setup_dialer_buttons()

func _find_label_fallback(node: Node) -> Node:
	if node == null: return null
	if node is Label or node is LineEdit or node is RichTextLabel or node is TextEdit: return node
	for child in node.get_children():
		if child.name == "KeypadGrid" or child is GridContainer or child is Button: continue
		var found = _find_label_fallback(child)
		if found: return found
	return null

func _input(event):
	if event.is_action_pressed("ui_up"): toggle_phone()

func _on_numpad_pressed(digit: String):
	if number_display:
		if "Ad" in number_display.text or "!" in number_display.text or "No" in number_display.text or "Maxed" in number_display.text or "Delivered" in number_display.text or "Err" in number_display.text:
			number_display.text = ""
		number_display.text += digit

func _on_clear_pressed():
	if number_display: number_display.text = ""

func _create_round_style(bg_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 100
	style.corner_radius_top_right = 100
	style.corner_radius_bottom_left = 100
	style.corner_radius_bottom_right = 100
	if bg_color == Color.BLACK:
		style.border_width_bottom = 2
		style.border_width_top = 2
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_color = Color.GRAY
	return style

func _setup_dialer_buttons():
	if not keypad_grid: return
	for child in keypad_grid.get_children():
		keypad_grid.remove_child(child)
		child.queue_free()
	var keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "CLR", "0", "CALL"]
	for key in keys:
		var btn = Button.new()
		btn.text = key
		btn.custom_minimum_size = Vector2(60, 60)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER | Control.SIZE_EXPAND
		btn.focus_mode = Control.FOCUS_NONE 
		var base_col = Color(0.15, 0.15, 0.15) 
		if key == "CALL": base_col = Color(0.1, 0.6, 0.1)
		elif key == "CLR": base_col = Color(0.8, 0.1, 0.1)
		btn.add_theme_stylebox_override("normal", _create_round_style(base_col))
		btn.add_theme_stylebox_override("hover", _create_round_style(base_col.lightened(0.2))) 
		btn.add_theme_stylebox_override("pressed", _create_round_style(base_col.darkened(0.2)))
		btn.add_theme_stylebox_override("focus", _create_round_style(base_col)) 
		if key == "CALL": btn.pressed.connect(_on_call_pressed)
		elif key == "CLR": btn.pressed.connect(_on_clear_pressed)
		else: btn.pressed.connect(_on_numpad_pressed.bind(key))
		keypad_grid.add_child(btn)

func _setup_color_buttons():
	if not color_grid: return
	for child in color_grid.get_children():
		color_grid.remove_child(child)
		child.queue_free()
	color_grid.columns = 3 
	for paint_color in available_car_colors:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(50, 50) 
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_stylebox_override("normal", _create_round_style(paint_color))
		btn.add_theme_stylebox_override("hover", _create_round_style(paint_color.lightened(0.2)))
		btn.add_theme_stylebox_override("pressed", _create_round_style(paint_color.darkened(0.2)))
		btn.add_theme_stylebox_override("focus", _create_round_style(paint_color))
		btn.pressed.connect(_paint_car.bind(paint_color))
		color_grid.add_child(btn)

func _on_call_pressed():
	if not number_display: return
	var code = number_display.text.strip_edges()
	
	if code in ["9999", "7771", "7772", "7773", "7774"]:
		number_display.text = "Loading Ad..."
		toggle_phone() 
		
		if get_node_or_null("/root/GlobalData"):
			GlobalData.play_ad_for_code(code)
	else:
		number_display.text = "Invalid Code!"

func _get_local_player() -> Node:
	var uid = str(multiplayer.get_unique_id())
	var p = get_tree().root.find_child(uid, true, false)
	if p: return p
	
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty(): players = get_tree().get_nodes_in_group("players")
		
	for pl in players:
		if pl.is_multiplayer_authority(): return pl
	if not players.is_empty(): return players[0]
		
	p = get_tree().root.find_child("Player", true, false)
	return p

func _paint_car(new_color: Color):
	var local_player = _get_local_player()
	if local_player != null and local_player.get("active_car_instance") != null:
		var car = local_player.active_car_instance
		if is_instance_valid(car) and car.has_method("set_car_color"):
			car.rpc("set_car_color", new_color)

func toggle_phone():
	if not phone_container: return
	is_open = !is_open
	if phone_tween and phone_tween.is_valid(): phone_tween.kill()
	phone_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_open:
		close_bg.show() 
		phone_container.show() 
		phone_tween.tween_property(phone_container, "position:y", on_screen_y, 0.4)
	else:
		close_bg.hide() 
		phone_tween.tween_property(phone_container, "position:y", off_screen_y, 0.4)
		phone_tween.tween_callback(phone_container.hide) 
		_go_to_home()

func _go_to_home():
	if home_screen: home_screen.show()
	if dialer_screen: dialer_screen.hide()
	if color_screen: color_screen.hide()
	if number_display: number_display.text = ""

func _open_dialer():
	if home_screen: home_screen.hide()
	if dialer_screen: dialer_screen.show()

func _open_color_app():
	if home_screen: home_screen.hide()
	if color_screen: color_screen.show()
