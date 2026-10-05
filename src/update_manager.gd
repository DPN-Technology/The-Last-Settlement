class_name UpdateManager
extends Node

signal state_changed
signal update_available(version:String)
signal installer_ready(path:String)

enum UpdateState {
	IDLE,
	CHECKING,
	UP_TO_DATE,
	AVAILABLE,
	DOWNLOADING,
	READY,
	ERROR
}

const MANIFEST_SCHEMA_VERSION := 1
const PRODUCT_NAME := "The Last Settlement"
const PLATFORM_NAME := "windows-x86_64"
const DEFAULT_MANIFEST_URL := "https://github.com/DPN-Technology/The-Last-Settlement/releases/latest/download/windows-release.json"
const RELEASE_ASSET_PREFIX := "https://github.com/DPN-Technology/The-Last-Settlement/releases/download/"
const INSTALLER_PATH := "user://updates/TheLastSettlement-Setup-x64.msi"
const MAX_MANIFEST_BYTES := 262144

var state: UpdateState = UpdateState.IDLE
var message := "UPDATE CHANNEL IDLE"
var current_version := "0.0.0"
var current_save_schema := 0
var available_version := ""
var manifest: Dictionary = {}
var expected_sha256 := ""
var installer_url := ""
var downloaded_bytes := 0
var total_bytes := 0
var request_mode := ""
var _request: HTTPRequest

func _ready() -> void:
	_request = HTTPRequest.new()
	_request.timeout = 30.0
	_request.use_threads = true
	_request.request_completed.connect(_on_request_completed)
	add_child(_request)
	set_process(true)

func configure(save_schema:int) -> void:
	current_version = str(ProjectSettings.get_setting("application/config/version","0.0.0"))
	current_save_schema = save_schema

func auto_check_if_enabled() -> void:
	if OS.get_name() != "Windows":
		return
	if not bool(ProjectSettings.get_setting("dpn_update/auto_check",true)):
		return
	check_for_updates()

func check_for_updates() -> void:
	if OS.get_name() != "Windows":
		_set_state(UpdateState.UP_TO_DATE,"WINDOWS UPDATE CHANNEL NOT REQUIRED")
		return
	if state in [UpdateState.CHECKING,UpdateState.DOWNLOADING]:
		return
	_reset_request()
	request_mode = "manifest"
	_set_state(UpdateState.CHECKING,"CHECKING DPN RELEASE CHANNEL")
	var manifest_url := str(ProjectSettings.get_setting("dpn_update/manifest_url",DEFAULT_MANIFEST_URL))
	if manifest_url != DEFAULT_MANIFEST_URL:
		_set_error("UPDATE MANIFEST URL IS NOT AUTHORIZED")
		return
	var error := _request.request(manifest_url,["Accept: application/json","User-Agent: TheLastSettlement-Updater"])
	if error != OK:
		_set_error("UPDATE CHECK COULD NOT START // %s" % error_string(error))

func download_update() -> void:
	if state != UpdateState.AVAILABLE:
		return
	if installer_url.is_empty() or expected_sha256.is_empty():
		_set_error("VERIFIED INSTALLER METADATA IS MISSING")
		return
	if not installer_url.begins_with(RELEASE_ASSET_PREFIX):
		_set_error("INSTALLER URL FAILED RELEASE-ORIGIN POLICY")
		return
	var absolute_dir := ProjectSettings.globalize_path("user://updates")
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		_set_error("UPDATE STAGING DIRECTORY COULD NOT BE CREATED")
		return
	if FileAccess.file_exists(INSTALLER_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(INSTALLER_PATH))
	_reset_request()
	request_mode = "installer"
	_request.download_file = INSTALLER_PATH
	_set_state(UpdateState.DOWNLOADING,"DOWNLOADING VERIFIED WINDOWS INSTALLER")
	var error := _request.request(installer_url,["Accept: application/octet-stream","User-Agent: TheLastSettlement-Updater"])
	if error != OK:
		_request.download_file = ""
		_set_error("UPDATE DOWNLOAD COULD NOT START // %s" % error_string(error))

func handoff_installer() -> bool:
	if state != UpdateState.READY:
		return false
	if not FileAccess.file_exists(INSTALLER_PATH):
		_set_error("VERIFIED INSTALLER IS NO LONGER PRESENT")
		return false
	var actual := _sha256_file(INSTALLER_PATH)
	if actual.is_empty() or actual.to_lower() != expected_sha256.to_lower():
		_set_error("INSTALLER HASH CHANGED AFTER VERIFICATION")
		return false
	var absolute_path := ProjectSettings.globalize_path(INSTALLER_PATH)
	var result := OS.shell_open(absolute_path)
	if result != OK:
		_set_error("WINDOWS INSTALLER HANDOFF FAILED // %s" % error_string(result))
		return false
	message = "VERIFIED INSTALLER OPENED // COMPLETE INSTALL IN WINDOWS"
	state_changed.emit()
	return true

func get_state_label() -> String:
	match state:
		UpdateState.IDLE:
			return "IDLE"
		UpdateState.CHECKING:
			return "CHECKING"
		UpdateState.UP_TO_DATE:
			return "CURRENT"
		UpdateState.AVAILABLE:
			return "AVAILABLE"
		UpdateState.DOWNLOADING:
			return "DOWNLOADING"
		UpdateState.READY:
			return "VERIFIED"
		UpdateState.ERROR:
			return "ERROR"
	return "UNKNOWN"

func get_download_percent() -> float:
	if total_bytes <= 0:
		return 0.0
	return clampf(100.0*float(downloaded_bytes)/float(total_bytes),0.0,100.0)

func get_installer_path() -> String:
	return INSTALLER_PATH

func _process(_delta:float) -> void:
	if state != UpdateState.DOWNLOADING or _request == null:
		return
	var new_downloaded := _request.get_downloaded_bytes()
	var new_total := _request.get_body_size()
	if new_downloaded != downloaded_bytes or new_total != total_bytes:
		downloaded_bytes = new_downloaded
		total_bytes = max(total_bytes,new_total)
		state_changed.emit()

func _on_request_completed(result:int,response_code:int,_headers:PackedStringArray,body:PackedByteArray) -> void:
	var completed_mode := request_mode
	request_mode = ""
	if completed_mode == "manifest":
		_handle_manifest_response(result,response_code,body)
	elif completed_mode == "installer":
		_request.download_file = ""
		_handle_installer_response(result,response_code)

func _handle_manifest_response(result:int,response_code:int,body:PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_set_error("RELEASE CHANNEL NETWORK ERROR // %d" % result)
		return
	if response_code == 404:
		_set_state(UpdateState.UP_TO_DATE,"NO STABLE RELEASE PUBLISHED YET")
		return
	if response_code != 200:
		_set_error("RELEASE CHANNEL HTTP %d" % response_code)
		return
	if body.size() <= 0 or body.size() > MAX_MANIFEST_BYTES:
		_set_error("RELEASE MANIFEST SIZE POLICY FAILED")
		return
	var text := body.get_string_from_utf8()
	var parsed:Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		_set_error("RELEASE MANIFEST JSON IS INVALID")
		return
	var candidate:Dictionary = parsed
	var validation_error := _validate_manifest(candidate)
	if not validation_error.is_empty():
		_set_error(validation_error)
		return
	manifest = candidate
	available_version = str(manifest["version"])
	var installer:Dictionary = manifest["assets"]["installer"]
	expected_sha256 = str(installer["sha256"]).to_lower()
	installer_url = str(installer["url"])
	if _compare_versions(available_version,current_version) <= 0:
		_set_state(UpdateState.UP_TO_DATE,"CURRENT BUILD %s // RELEASE %s" % [current_version,available_version])
		return
	_set_state(UpdateState.AVAILABLE,"UPDATE %s AVAILABLE // SAVE SCHEMA %d" % [available_version,int(manifest["save_schema"])])
	update_available.emit(available_version)

func _handle_installer_response(result:int,response_code:int) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		if FileAccess.file_exists(INSTALLER_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(INSTALLER_PATH))
		_set_error("INSTALLER DOWNLOAD FAILED // HTTP %d // RESULT %d" % [response_code,result])
		return
	if not FileAccess.file_exists(INSTALLER_PATH):
		_set_error("INSTALLER DOWNLOAD COMPLETED WITHOUT A FILE")
		return
	var actual := _sha256_file(INSTALLER_PATH)
	if actual.is_empty():
		_set_error("INSTALLER HASH COULD NOT BE CALCULATED")
		return
	if actual.to_lower() != expected_sha256.to_lower():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(INSTALLER_PATH))
		_set_error("INSTALLER SHA-256 VERIFICATION FAILED")
		return
	_set_state(UpdateState.READY,"UPDATE %s VERIFIED // READY FOR WINDOWS INSTALLER" % available_version)
	installer_ready.emit(INSTALLER_PATH)

func _validate_manifest(candidate:Dictionary) -> String:
	if int(candidate.get("schema_version",0)) != MANIFEST_SCHEMA_VERSION:
		return "UNSUPPORTED RELEASE MANIFEST SCHEMA"
	if str(candidate.get("product","")) != PRODUCT_NAME:
		return "RELEASE MANIFEST PRODUCT MISMATCH"
	if str(candidate.get("platform","")) != PLATFORM_NAME:
		return "RELEASE MANIFEST PLATFORM MISMATCH"
	var version := str(candidate.get("version",""))
	if not _is_valid_version(version):
		return "RELEASE VERSION IS INVALID"
	var target_save_schema := int(candidate.get("save_schema",0))
	if target_save_schema < current_save_schema:
		return "UPDATE SAVE SCHEMA WOULD DOWNGRADE CURRENT SAVES"
	var assets:Variant = candidate.get("assets",{})
	if not assets is Dictionary:
		return "RELEASE ASSET TABLE IS INVALID"
	var installer_variant:Variant = assets.get("installer",{})
	if not installer_variant is Dictionary:
		return "INSTALLER RELEASE ASSET IS MISSING"
	var installer:Dictionary = installer_variant
	var url := str(installer.get("url",""))
	var hash := str(installer.get("sha256","")).to_lower()
	if url.is_empty() or not url.begins_with(RELEASE_ASSET_PREFIX):
		return "INSTALLER RELEASE URL FAILED ORIGIN POLICY"
	if not _is_sha256(hash):
		return "INSTALLER SHA-256 IS INVALID"
	if int(installer.get("size_bytes",0)) <= 0:
		return "INSTALLER SIZE METADATA IS INVALID"
	return ""

func _is_sha256(value:String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		if not character.to_lower() in "0123456789abcdef":
			return false
	return true

func _is_valid_version(value:String) -> bool:
	var clean := value.trim_prefix("v")
	if clean.is_empty():
		return false
	var base := clean.split("-",false,1)[0]
	var parts := base.split(".")
	if parts.size() < 3:
		return false
	for i in range(3):
		if not str(parts[i]).is_valid_int():
			return false
	return true

func _compare_versions(a:String,b:String) -> int:
	var left := _version_tuple(a)
	var right := _version_tuple(b)
	for i in range(4):
		if left[i] > right[i]:
			return 1
		if left[i] < right[i]:
			return -1
	return 0

func _version_tuple(value:String) -> Array[int]:
	var clean := value.trim_prefix("v")
	var prerelease := 0 if clean.contains("-") else 1
	var base := clean.split("-",false,1)[0]
	var parts := base.split(".")
	var values:Array[int] = [0,0,0,prerelease]
	for i in range(mini(3,parts.size())):
		values[i] = int(parts[i])
	return values

func _sha256_file(path:String) -> String:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	var start_error := context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		file.close()
		return ""
	while file.get_position() < file.get_length():
		var remaining := file.get_length()-file.get_position()
		var chunk_size := mini(1048576,int(remaining))
		var chunk := file.get_buffer(chunk_size)
		if chunk.is_empty() and remaining > 0:
			file.close()
			return ""
		context.update(chunk)
	file.close()
	return context.finish().hex_encode()

func _reset_request() -> void:
	if _request == null:
		return
	_request.cancel_request()
	_request.download_file = ""
	downloaded_bytes = 0
	total_bytes = 0

func _set_state(next_state:UpdateState,next_message:String) -> void:
	state = next_state
	message = next_message
	state_changed.emit()

func _set_error(error_message:String) -> void:
	state = UpdateState.ERROR
	message = error_message
	request_mode = ""
	if _request != null:
		_request.download_file = ""
	state_changed.emit()
