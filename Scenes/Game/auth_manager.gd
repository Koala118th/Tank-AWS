# AuthManager.gd (autoload)
extends Node

const REGION = "ap-southeast-2"
const CLIENT_ID = "3c646r4dq60bdumgdtc0bpvke5"
const POOL_ID = "ap-southeast-2_HpQIhV5JV"
const COGNITO_URL = "https://cognito-idp.ap-southeast-2.amazonaws.com/"

signal login_success(username: String)
signal login_failed(message: String)
signal signup_success
signal signup_failed(message: String)

var access_token: String = ""
var username: String = ""
var is_logged_in: bool = false

var _http: HTTPRequest
var _pending_action: String = ""
var _pending_username: String = ""

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


func login(p_username: String, p_password: String) -> void:
	_pending_action = "login"
	_pending_username = p_username
	username = p_username  # add this line
	var body = JSON.stringify({
		"AuthFlow": "USER_PASSWORD_AUTH",
		"ClientId": CLIENT_ID,
		"AuthParameters": {
			"USERNAME": p_username,
			"PASSWORD": p_password
		}
	})
	_send_request("AWSCognitoIdentityProviderService.InitiateAuth", body)


func signup(p_username: String, p_password: String) -> void:
	_pending_action = "signup"
	_pending_username = p_username
	username = p_username
	var fake_email = p_username.to_lower() + "@tankaz.game"
	var body = JSON.stringify({
		"ClientId": CLIENT_ID,
		"Username": p_username,
		"Password": p_password,
		"UserAttributes": [
			{
				"Name": "email",
				"Value": fake_email
			}
		]
	})
	_send_request("AWSCognitoIdentityProviderService.SignUp", body)


func _send_request(target: String, body: String) -> void:
	var headers = [
		"Content-Type: application/x-amz-json-1.1",
		"X-Amz-Target: " + target
	]
	var err = _http.request(COGNITO_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_emit_failure("Failed to send request")


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var raw = body.get_string_from_utf8()

	if result != HTTPRequest.RESULT_SUCCESS:
		print("[Auth] Network error, result code: ", result)
		_emit_failure("Network error — could not reach server")
		return

	var json = JSON.new()
	var err = json.parse(raw)
	if err != OK:
		print("[Auth] JSON parse error")
		_emit_failure("Invalid response from server")
		return

	var data = json.get_data()

	if response_code != 200:
		var msg = data.get("message", data.get("Message", "Unknown error"))
		print("[Auth] Error from Cognito: ", msg)
		_emit_failure(msg)
		return

	if _pending_action == "login":
		var auth = data.get("AuthenticationResult", {})
		access_token = auth.get("AccessToken", "")
		username = _pending_username
		is_logged_in = true
		_pending_action = ""
		login_success.emit(username)

	elif _pending_action == "signup":
		print("[Auth] Signup success")
		_pending_action = ""
		signup_success.emit()


func _decode_username_from_token(id_token: String) -> String:
	var parts = id_token.split(".")
	if parts.size() < 2:
		return ""
	var payload = parts[1]
	payload = payload.replace("-", "+").replace("_", "/")
	while payload.length() % 4 != 0:
		payload += "="
	var decoded = Marshalls.base64_to_raw(payload).get_string_from_utf8()
	var json = JSON.new()
	if json.parse(decoded) != OK:
		return ""
	var claims = json.get_data()
	# Fall back to cognito:username if preferred_username not set
	return claims.get("preferred_username", claims.get("cognito:username", ""))


func _emit_failure(message: String) -> void:
	print("[Auth] Emitting failure: ", message)
	if _pending_action == "login":
		login_failed.emit(message)
	elif _pending_action == "signup":
		signup_failed.emit(message)
	_pending_action = ""
