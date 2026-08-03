extends Control
class_name Main_menu

@onready var name_line_edit    = $MenuScreen/VBoxContainer/LineEdit
@onready var password_edit     = $MenuScreen/VBoxContainer/PasswordEdit
@onready var divider_label     = $MenuScreen/VBoxContainer/DividerLabel
@onready var play_button       = $MenuScreen/VBoxContainer/PlayButton
@onready var auth_row          = $MenuScreen/VBoxContainer/AuthRow
@onready var login_button      = $MenuScreen/VBoxContainer/AuthRow/LoginButton
@onready var signup_button     = $MenuScreen/VBoxContainer/AuthRow/SignUpButton
@onready var menu_screen       = $MenuScreen
@onready var connecting_screen = $ConnectingScreen
@onready var status_label      = $ConnectingScreen/VBoxContainer/TextBlock/StatusLabel
@onready var spinner           = $ConnectingScreen/VBoxContainer/SpinnerWrapper/SpinnerRect
@onready var spinner_inner     = $ConnectingScreen/VBoxContainer/SpinnerWrapper/SpinnerInner

@onready var menu_screen_node = $MenuScreen
@onready var connecting_screen_node = $ConnectingScreen

@onready var socketNode: Node  = $SocketNode

const DOTS = "·    ·    ·    ·    ·    ·    ·    ·    ·    ·    ·    ·    ·"

enum MenuState { LOGGED_OUT, LOADING, LOGGED_IN }
var _state: MenuState = MenuState.LOGGED_OUT


func _ready() -> void:
	_connect_button_sounds($MenuScreen/VBoxContainer/AuthRow/LoginButton)
	_connect_button_sounds($MenuScreen/VBoxContainer/AuthRow/SignUpButton)
	_connect_button_sounds($MenuScreen/VBoxContainer/PlayButton)
	_connect_button_sounds($MenuScreen/VBoxContainer/SettingsButton)
	_connect_button_sounds($MenuScreen/VBoxContainer/QuitButton)

	AuthManager.login_success.connect(_on_login_success)
	AuthManager.login_failed.connect(_on_auth_failed)
	AuthManager.signup_success.connect(_on_signup_success)
	AuthManager.signup_failed.connect(_on_auth_failed)

	await get_tree().process_frame
	spinner.pivot_offset       = spinner.size / 2
	spinner_inner.pivot_offset = spinner_inner.size / 2

	if GameServer.is_server_mode():
		GameLiftBridge.InitGameLift(GameServer.get_port_from_args())
	
	if GameServer.pending_error_message != "":
		_show_error(GameServer.pending_error_message)
		GameServer.pending_error_message = ""

	# If already logged in from earlier in the session, skip straight to LOGGED_IN
	if AuthManager.is_logged_in:
		_apply_state(MenuState.LOGGED_IN)
	else:
		_apply_state(MenuState.LOGGED_OUT)


func _process(delta: float) -> void:
	if connecting_screen.visible:
		spinner.rotation_degrees       += 180.0 * delta
		spinner_inner.rotation_degrees -= 260.0 * delta


# ─── Auth state machine ───────────────────────────────────────────────────────

func _apply_state(new_state: MenuState) -> void:
	_state = new_state
	match _state:
		MenuState.LOGGED_OUT:
			name_line_edit.visible  = true
			name_line_edit.editable = true
			password_edit.visible   = true
			password_edit.editable  = true
			auth_row.visible        = true
			login_button.visible    = true
			login_button.disabled   = false
			signup_button.visible   = true
			signup_button.disabled  = false
			play_button.visible     = false
			_reset_divider()

		MenuState.LOADING:
			name_line_edit.editable = false
			password_edit.editable  = false
			login_button.disabled   = true
			signup_button.disabled  = true
			divider_label.text      = "Please wait..."
			divider_label.add_theme_color_override(
				"font_color", Color(0.227, 0.478, 0.227))

		MenuState.LOGGED_IN:
			name_line_edit.visible = false
			password_edit.visible  = false
			auth_row.visible       = false
			login_button.visible   = false
			signup_button.visible  = false
			play_button.visible    = true
			divider_label.text     = "Welcome,  " + AuthManager.username
			divider_label.add_theme_color_override(
				"font_color", Color(0.298, 0.686, 0.314))


func _validate() -> bool:
	var uname = name_line_edit.text.strip_edges()
	var pword = password_edit.text

	if uname.length() < 3:
		_show_error("Username must be at least 3 characters")
		return false
	if uname.length() > 20:
		_show_error("Username must be 20 characters or less")
		return false
	if pword.length() < 6:
		_show_error("Password must be at least 6 characters")
		return false
	if pword.length() > 64:
		_show_error("Password too long")
		return false

	# Block characters that could be used for injection
	var forbidden = ["<", ">", "\"", "'", ";", "{", "}", "\\", "/"]
	for ch in forbidden:
		if ch in uname:
			_show_error("Username contains invalid characters")
			return false
		if ch in pword:
			_show_error("Password contains invalid characters")
			return false

	return true


func _show_error(msg: String) -> void:
	divider_label.text = "⚠  " + msg
	divider_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))


func _reset_divider() -> void:
	divider_label.text = DOTS
	divider_label.add_theme_color_override("font_color", Color(0.227, 0.353, 0.227))


# ─── Auth button handlers ─────────────────────────────────────────────────────

func _on_login_button_pressed() -> void:
	if not _validate():
		return
	_apply_state(MenuState.LOADING)
	AuthManager.login(name_line_edit.text.strip_edges(), password_edit.text)


func _on_sign_up_button_pressed() -> void:
	if not _validate():
		return
	_apply_state(MenuState.LOADING)
	AuthManager.signup(name_line_edit.text.strip_edges(), password_edit.text)


func _on_login_success(_uname: String) -> void:
	_apply_state(MenuState.LOGGED_IN)


func _on_signup_success() -> void:
	# Username already stored in AuthManager from signup call
	AuthManager.login(AuthManager.username, password_edit.text)


func _on_auth_failed(message: String) -> void:
	_apply_state(MenuState.LOGGED_OUT)
	_show_error(_friendly_error(message))


func _friendly_error(raw: String) -> String:
	if "Incorrect username or password" in raw:
		return "Incorrect username or password"
	if "User does not exist" in raw:
		return "No account with that username"
	if "UserNotConfirmedException" in raw:
		return "Account not confirmed — contact support"
	if "UsernameExistsException" in raw or "already exists" in raw:
		return "Username already taken"
	if "password" in raw.to_lower():
		return "Password must be at least 8 characters"
	if "Network" in raw:
		return "Could not reach server"
	return raw


# ─── Existing handlers (unchanged) ───────────────────────────────────────────

func _on_start_button_pressed() -> void:
	if name_line_edit.text.strip_edges() == "":
		divider_label.text = "ENTER A USERNAME"
		divider_label.add_theme_color_override("font_color", Color.RED)
	else:
		toggle_menu_screen(false)
		socketNode.open_client(AuthManager.username) 

func _on_settings_button_pressed() -> void:
	var scene := preload("res://Interfaces/Settings/settings_menu.tscn")
	add_child(scene.instantiate())
func _on_game_start() -> void:
	print("game start")
	socketNode.close_client()
	get_tree().change_scene_to_file("res://Scenes/game.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()

# ─────────────────────────────────────────
#  HELPER FUNCTIONS
# ─────────────────────────────────────────
func _on_line_edit_text_changed(_new_text: String) -> void:
	if _state == MenuState.LOGGED_OUT:
		_reset_divider()


func show_connecting(status: String = "Reaching server...") -> void:
	menu_screen.hide()
	connecting_screen.show()
	status_label.text = status


func show_menu() -> void:
	connecting_screen.hide()
	menu_screen.show()


func set_status(status: String) -> void:
	status_label.text = status

func _on_cancel_button_pressed():
	socketNode.close_client()
	toggle_menu_screen(true)
	show_menu()

func toggle_menu_screen(is_menu: bool) ->void:
	menu_screen_node.visible = is_menu
	connecting_screen_node.visible = !is_menu


func _connect_button_sounds(button: Button) -> void:
	button.mouse_entered.connect(func(): AudioManager.play_ui(AudioManager.sfx_button_hover))
	button.pressed.connect(func(): AudioManager.play_ui(AudioManager.sfx_button_click))
	
