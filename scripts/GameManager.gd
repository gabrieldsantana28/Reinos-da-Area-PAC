## GameManager.gd
## Controlador principal do jogo Reinos da Área
## Gerencia estado do jogo, progressão de dificuldade e pontuação

extends Node
class_name GameManager

# ─────────────────────────────────────────────
#  SINAIS
# ─────────────────────────────────────────────
signal phase_changed(new_phase: String)
signal round_result(result: String, player_area: float, enemy_area: float)
signal score_updated(score: int, streak: int)
signal timer_tick(seconds_left: float)
signal new_round_started(round_number: int, difficulty: float)

# ─────────────────────────────────────────────
#  ENUMS
# ─────────────────────────────────────────────
enum Phase { ANALYSIS, DECISION, RESULT, RESTART }
enum Action { ATTACK, DEFEND, RETREAT }
enum Result { WIN, LOSE, DRAW }

# ─────────────────────────────────────────────
#  CONSTANTES
# ─────────────────────────────────────────────
const BASE_ROUND_TIME   := 60.0   # segundos por rodada no nível 1
const MIN_ROUND_TIME    := 20.0    # mínimo de tempo mesmo em dificuldades altas
const BASE_DIFF_RANGE   := 0.08   # diferença máxima inicial entre áreas (8%)
const MIN_DIFF_RANGE    := 0.02   # diferença mínima (2% - máxima dificuldade)
const SCORE_WIN_BASE    := 100
const SCORE_STREAK_MULT := 50     # bônus por sequência
const SCORE_SPEED_BONUS := 200    # bônus máximo por velocidade

# ─────────────────────────────────────────────
#  ESTADO
# ─────────────────────────────────────────────
var current_phase    : Phase  = Phase.ANALYSIS
var current_round    : int    = 0
var player_score     : int    = 0
var win_streak       : int    = 0
var difficulty_level : float  = 1.0   # sobe gradualmente
var round_time_left  : float  = BASE_ROUND_TIME
var round_start_time : float  = 0.0
var timer_active     : bool   = false

var player_area : float = 0.0
var enemy_area  : float = 0.0
var last_result : Result

# ─────────────────────────────────────────────
#  TIMER
# ─────────────────────────────────────────────
var _countdown_timer : Timer

func _ready() -> void:
	_countdown_timer = Timer.new()
	_countdown_timer.wait_time = 0.1
	_countdown_timer.autostart = false
	_countdown_timer.timeout.connect(_on_timer_tick)
	add_child(_countdown_timer)

func _on_timer_tick() -> void:
	if not timer_active:
		return
	round_time_left -= 0.1
	emit_signal("timer_tick", round_time_left)
	if round_time_left <= 0.0:
		timer_active = false
		_countdown_timer.stop()
		# Tempo esgotado = penalidade; trata como recuo forçado
		resolve_action(Action.RETREAT, true)

# ─────────────────────────────────────────────
#  FLUXO PRINCIPAL
# ─────────────────────────────────────────────
func start_new_round(p_area: float, e_area: float) -> void:
	current_round   += 1
	player_area      = p_area
	enemy_area       = e_area
	current_phase    = Phase.ANALYSIS
	round_time_left  = _get_round_time()
	round_start_time = Time.get_ticks_msec() / 1000.0
	timer_active     = true
	_countdown_timer.start()
	emit_signal("phase_changed", "ANALYSIS")
	emit_signal("new_round_started", current_round, difficulty_level)

func enter_decision_phase() -> void:
	current_phase = Phase.DECISION
	emit_signal("phase_changed", "DECISION")

## Resolve a ação escolhida pelo jogador.
## forced_timeout: true quando o timer esgota (trata como RETREAT sem bônus)
func resolve_action(action: Action, forced_timeout: bool = false) -> void:
	timer_active  = false
	_countdown_timer.stop()
	current_phase = Phase.RESULT

	var result := _calculate_result(action)
	last_result   = result

	var time_taken := (Time.get_ticks_msec() / 1000.0) - round_start_time
	_update_score(result, time_taken, forced_timeout)

	emit_signal("round_result", Result.keys()[result], player_area, enemy_area)
	emit_signal("phase_changed", "RESULT")

	# Aumenta dificuldade a cada 3 rodadas
	if current_round % 3 == 0:
		difficulty_level = minf(difficulty_level + 0.15, 5.0)

## Reinicia para nova rodada (chamado após animação de resultado)
func request_restart() -> void:
	current_phase = Phase.RESTART
	emit_signal("phase_changed", "RESTART")

# ─────────────────────────────────────────────
#  LÓGICA DE RESULTADO
# ─────────────────────────────────────────────
func _calculate_result(action: Action) -> Result:
	match action:
		Action.ATTACK:
			return Result.WIN if player_area > enemy_area else Result.LOSE
		Action.DEFEND:
			# Defender: correto quando o inimigo é maior (recuaria atacar)
			return Result.WIN if enemy_area > player_area else Result.LOSE
		Action.RETREAT:
			return Result.DRAW
	return Result.DRAW

func _update_score(result: Result, time_taken: float, timeout: bool) -> void:
	match result:
		Result.WIN:
			win_streak += 1
			var speed_bonus := 0
			if not timeout:
				var max_time := _get_round_time()
				var ratio    := clampf(1.0 - (time_taken / max_time), 0.0, 1.0)
				speed_bonus   = int(ratio * SCORE_SPEED_BONUS)
			var streak_bonus := (win_streak - 1) * SCORE_STREAK_MULT
			player_score    += SCORE_WIN_BASE + streak_bonus + speed_bonus
		Result.LOSE:
			win_streak    = 0
			player_score  = maxi(0, player_score - 50)
		Result.DRAW:
			win_streak = 0
	emit_signal("score_updated", player_score, win_streak)

# ─────────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────────
func _get_round_time() -> float:
	return maxf(MIN_ROUND_TIME, BASE_ROUND_TIME - (difficulty_level - 1.0) * 3.0)

## Retorna o range de diferença de área para a dificuldade atual.
## Dificuldade alta → diferença menor → mais difícil de perceber.
func get_difficulty_range() -> float:
	return maxf(MIN_DIFF_RANGE, BASE_DIFF_RANGE - (difficulty_level - 1.0) * 0.012)

func get_difficulty_label() -> String:
	if difficulty_level < 1.5: return "Aprendiz"
	if difficulty_level < 2.5: return "Estrategista"
	if difficulty_level < 3.5: return "Arquiteto"
	if difficulty_level < 4.5: return "Mestre"
	return "Lendário"

func reset_campaign() -> void:
	current_round = 0
	player_score = 0
	win_streak = 0
	difficulty_level = 1.0
