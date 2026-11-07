extends AudioStreamPlayer
## 全局背景音乐：Smetana《我的祖国》第二首《伏尔塔瓦河》。
## Autoload 常驻，跨场景循环播放；暂停菜单打开时音乐不中断。

const TRACK := preload("res://music/vltava.ogg")
const VOLUME_DB := -7.0
const FADE_TIME := 2.5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	stream = TRACK
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	volume_db = -40.0
	play()
	var tw := create_tween()
	tw.tween_property(self, "volume_db", VOLUME_DB, FADE_TIME).set_trans(Tween.TRANS_SINE)


func _exit_tree() -> void:
	stop()
	stream = null
