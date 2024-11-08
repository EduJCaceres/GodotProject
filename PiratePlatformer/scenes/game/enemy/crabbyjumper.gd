extends CharacterBody2D

@export_enum(
	"idle",
	"jump",
) var animation: String

# Dirección de movimiento del Enemigo
@export_enum(
	"active",
) var moving_direction: String

# Variables para control de animación y colisiones
@onready var _animation := $EnemyAnimation
@onready var _animation_effect := $EnemyEffect
@onready var _raycast_terrain := $Area2D/RayCastTerrain
@onready var _raycast_vision_left := $Area2D/RayCastVisionLeft
@onready var _raycast_vision_right := $Area2D/RayCastVisionRight
@onready var _audio_player = $AudioStreamPlayer2D

# Sonidos
var _punch_sound = preload("res://assets/sounds/punch.mp3")
var _male_hurt_sound = preload("res://assets/sounds/male_hurt.mp3")

# Definición de parámetros de física
var _gravity = 10
var _jump_force = -250  # Fuerza de salto negativa (hacia arriba)
var _cooldown_time = 1  # Tiempo de espera entre saltos
var _is_jumping = false # Bandera para verificar si está en un salto
var _time_since_jump = 0.0  # Tiempo acumulado desde el último salto

# Parámetros de ataque
var _is_persecuted = false
var _stop_detection = false
var _stop_attack = false
var _hit_to_die = 3
var _has_hits = 0
var die = false

func _ready():
	# Seteamos animación inicial
	animation = "idle"
	_init_state()


func _physics_process(delta):
	if die:
		return
	
	# Si está en el aire, aplicamos gravedad
	if _is_jumping:
		velocity.y += _gravity
		move_and_slide()

	# Controlamos el momento del salto
	_handle_jump(delta)

	# Detectamos al jugador para ataques
	if moving_direction == "active" and not _stop_detection:
		_detection()

# Control del salto
func _handle_jump(delta):
	# Si está en el suelo y no está saltando
	if not _is_jumping and _raycast_terrain.is_colliding():
		_time_since_jump += delta
		# Esperamos un segundo antes del próximo salto
		if _time_since_jump >= _cooldown_time:
			_start_jump()
	else:
		# Si no está en el suelo, marcamos como en salto
		_is_jumping = true

func _start_jump():
	# Inicia el salto
	velocity.y = _jump_force
	_is_jumping = true
	_time_since_jump = 0  # Reiniciamos el tiempo de espera
	_animation.play("jump")


func _move_idle():
	# Aplicamos la gravedad y detenemos movimiento horizontal
	velocity.y += _gravity
	velocity.x = 0
	move_and_slide()

func _on_area_2d_body_entered(body):
	if body.is_in_group("player"):
		_stop_detection = true
		_attack()
		_body = body

func _on_area_2d_body_exited(body):
	if not die:
		_init_state()

# Función de ataque
func _attack():	
	if _stop_attack:
		return

	if not _body:
		await get_tree().create_timer(0).timeout
		_attack()

	_animation.play("attack")


func _init_state():
	if _stop_attack:
		return
	velocity.x = 0
	_animation.play(animation)
	_animation_effect.play("idle")
	_body = null
	_stop_detection = false

func _on_enemy_animation_frame_changed():
	if _stop_attack:
		return
	if _animation.frame == 0 and _animation.get_animation() == "attack":
		_animation_effect.play("attack_effect")
		if HealthDashboard.life > 0:
			_audio_player.stream = _male_hurt_sound
			_audio_player.play()
		else:
			_animation.play("idle")
			_animation_effect.play("idle")
		if _body:
			var _move_script = _body.get_node("MainCharacterMovement")
			_move_script.hit(2)

# Función de detección para perseguir y atacar al jugador
func _detection():
	if not _raycast_terrain.is_colliding():
		_init_state()
		return
	var _object1 = _raycast_vision_left.get_collider()
	var _object2 = _raycast_vision_right.get_collider()
	if _object1 and _object1.is_in_group("player") and _raycast_vision_left.is_colliding():
		_move(true)
	else:
		_is_persecuted = false
	if _object2 and _object2.is_in_group("player") and _raycast_vision_right.is_colliding():
		_move(false)
	if not _object1 and not _object2 and _animation.get_animation() != "attack":
		_is_persecuted = false

func _move(_direction):
	if _is_persecuted or _animation.get_animation() == "attack":
		return
	velocity.y += _gravity
	if not _direction:
		scale.x = -scale.x
	_is_persecuted = true
	_animation.play("run")


func _on_area_2d_area_entered(area):
	if area.is_in_group("hit"):
		_damage()
	elif area.is_in_group("die"):
		die = true
		_damage()

func _damage():	
	_has_hits += 1
	_audio_player.stream = _punch_sound
	_audio_player.play()
	_animation.play("hit")
	_animation_effect.play("idle")
	if Global.number_attack > 0:
		die = true
		Global.number_attack -= 1
	if Global.number_attack == 0:
		Global.attack_effect = "normal"
	if die or _hit_to_die <= _has_hits:
		_stop_attack = true
		die = true
		velocity.x = 0
		if _animation.animation != "dead_ground":
			_animation.play("dead_ground")

func _on_enemy_animation_animation_finished():
	if _animation.animation == "dead_ground":
		queue_free()
	elif _animation.animation == "hit":
		if not _stop_attack: 
			_animation.play("idle")
			_animation_effect.play("idle")
			_attack()
