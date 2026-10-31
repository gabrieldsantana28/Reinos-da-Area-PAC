## AudioManager.gd
## Autoload global para tocar efeitos sonoros e músicas sem interrupções.

extends Node

# Dicionário centralizando os caminhos. Apontando para os seus arquivos .mp3!
var _sounds := {
	# Músicas
	"bg_music": "res://assets/audios/background.mp3",
	"phase_win": "res://assets/audios/resumo_vitoria.mp3",
	"phase_lose": "res://assets/audios/resumo_derrota.mp3",
	
	# Interface
	"ui_hover": "res://assets/audios/hover.mp3",
	"ui_click": "res://assets/audios/click.mp3",
	
	# Ações da Rodada
	"map_unroll": "res://assets/audios/inicio_da_rodada.mp3",
	"action_attack": "res://assets/audios/atacar.mp3",
	"action_defend": "res://assets/audios/defender.mp3",
	"action_retreat": "res://assets/audios/recuar.mp3",
	"timer_tick": "res://assets/audios/tempo_esgotando.mp3",
	
	# Resultados
	"result_win": "res://assets/audios/brilho_da_vitoria.mp3",
	"result_lose": "res://assets/audios/derrota.mp3",
	"result_draw": "res://assets/audios/vento.mp3"
}

# Cache para armazenar os AudioStreams já carregados
var _loaded_streams := {}

# Players
var bgm_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
const POOL_SIZE = 8 # Quantidade de sons simultâneos permitidos

func _ready() -> void:
	# Pre-carrega todos os áudios silenciosamente para não dar travadinhas no jogo
	for key in _sounds.keys():
		var path = _sounds[key]
		if ResourceLoader.exists(path):
			_loaded_streams[key] = load(path)
		else:
			push_warning("AudioManager: Áudio não encontrado no caminho: " + path)

	# Cria o player de música de fundo
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	bgm_player.volume_db = -15.0
	add_child(bgm_player)
	
	# Cria a pool de players de efeitos sonoros
	for i in POOL_SIZE:
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_pool.append(p)

# Toca um Efeito Sonoro na primeira "fenda" livre da Pool
func play_sfx(sound_name: String, pitch_randomness: float = 0.0) -> void:
	if not _loaded_streams.has(sound_name): return
	
	for p in sfx_pool:
		if not p.playing:
			p.stream = _loaded_streams[sound_name]
			if pitch_randomness > 0.0:
				p.pitch_scale = randf_range(1.0 - pitch_randomness, 1.0 + pitch_randomness)
			else:
				p.pitch_scale = 1.0
			p.play()
			return

# Toca uma Música de Fundo (interrompendo a anterior)
func play_music(sound_name: String) -> void:
	if not _loaded_streams.has(sound_name): return
	if bgm_player.stream == _loaded_streams[sound_name] and bgm_player.playing: return
	
	bgm_player.stream = _loaded_streams[sound_name]
	bgm_player.play()

# Para a música de fundo
func stop_music() -> void:
	bgm_player.stop()

func set_bgm_volume(volume_db: float) -> void:
	if bgm_player:
		bgm_player.volume_db = volume_db
