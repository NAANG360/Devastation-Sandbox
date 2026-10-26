extends Control

var progress = []
var scene_name = "res://main.tscn" 
var load_status = 0

@onready var progress_bar = $VBoxContainer/ProgressBar
@onready var percent_label = $VBoxContainer/PercentLabel
@onready var tips_label = $TipsLabel

var tips = [
	"TIP: Cars are highly explosive. Shoot them from a distance.",
	"TIP: The water is lethal. Do not fall off the map!",
	"TIP: Check out the Airport to travel to new regions.",
	"TIP: Explore the world to find hidden Tailed Beast Fragments.",
	"TIP: Committing crimes will attract the Police. Survive if you can."
]

func _ready():
	if GlobalData.get("target_scene") != null and GlobalData.target_scene != "":
		scene_name = GlobalData.target_scene
	if tips_label: tips_label.text = tips.pick_random()
	ResourceLoader.load_threaded_request(scene_name)

func _process(_delta):
	load_status = ResourceLoader.load_threaded_get_status(scene_name, progress)
	var actual_progress = progress[0] * 100.0
	
	if progress_bar: progress_bar.value = lerp(progress_bar.value, actual_progress, 0.1)
	if percent_label: percent_label.text = "LOADING... " + str(int(actual_progress)) + "%"
	
	if load_status == ResourceLoader.THREAD_LOAD_LOADED:
		set_process(false) 
		percent_label.text = "INITIALIZING WORLD..."
		await get_tree().process_frame
		
		var packed_scene = ResourceLoader.load_threaded_get(scene_name)
		var instanced_scene = packed_scene.instantiate()
		get_tree().root.add_child(instanced_scene)
		get_tree().current_scene = instanced_scene
		queue_free()
