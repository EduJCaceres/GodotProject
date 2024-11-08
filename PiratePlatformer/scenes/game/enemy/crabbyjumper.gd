extends CharacterBody2D

# Definición de los tipos de animación y dirección
@export_enum("idle", "jump") var animation: String
@export_enum("active") var moving_direction: String

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

# Parámetros de física y de control de salto
var _gravity = 10
var _jump_force = -250  # Fuerza de salto negativa (hacia arriba)
var _cooldown_time = 1  # Tiempo de espera entre saltos
var _is_jumping = false # Bandera para verificar si está en un salto
var _time_since_jump = 0.0  # Tiempo acumulado desde el último salto
var _body = Node2D

# Parámetros de ataque
var _is_persecuted = false
var _stop_detection = false
var _stop_attack = false
var _hit_to_die = 3
var _has_hits = 0
var die = false

# Inicialización del estado del enemigo al cargar la escena
func _ready():
	animation = "idle"  # Inicializa la animación como "idle"
	_init_state()  # Configura el estado inicial

# Lógica de física del enemigo (se ejecuta cada frame)
func _physics_process(delta):
	if die:
		return
	
	# Aplica gravedad si el enemigo está en el aire
	if _is_jumping:
		velocity.y += _gravity
		move_and_slide()

	# Controla el salto y la detección del jugador
	_handle_jump(delta)

	# Detecta al jugador y realiza ataques si es necesario
	if moving_direction == "active" and not _stop_detection:
		_detection()

# Control del salto
func _handle_jump(delta):
	if not _is_jumping and _raycast_terrain.is_colliding():
		_time_since_jump += delta
		# Espera un segundo en el suelo antes de saltar de nuevo
		if _time_since_jump >= _cooldown_time:
			_start_jump()
	else:
		# Marca al enemigo como en salto si no está en el suelo
		_is_jumping = true

# Inicia el salto
func _start_jump():
	velocity.y = _jump_force  # Aplica la fuerza de salto
	_is_jumping = true  # Marca al enemigo como en salto
	_time_since_jump = 0  # Reinicia el tiempo de espera
	_animation.play("jump")  # Cambia la animación a "jump"

# Define el movimiento de "idle" (sin movimiento horizontal)
func _move_idle():
	velocity.y += _gravity  # Aplica gravedad
	velocity.x = 0  # No hay movimiento horizontal
	move_and_slide()  # Actualiza la posición del enemigo

# Evento cuando el enemigo detecta un cuerpo en su área
func _on_area_2d_body_entered(body):
	if body.is_in_group("player"):
		_stop_detection = true  # Desactiva la detección de otros jugadores
		_attack()  # Inicia el ataque
		_body = body  # Guarda referencia del jugador detectado

# Evento cuando un cuerpo sale del área de detección
func _on_area_2d_body_exited(body):
	if not die:
		_init_state()  # Reinicia el estado del enemigo

# Inicia el ataque si el jugador está en el área
func _attack():	
	if _stop_attack:
		return

	if not _body:
		await get_tree().create_timer(0).timeout
		_attack()

	_animation.play("attack")  # Cambia la animación a "attack"

# Configura el estado inicial de animación y detección
func _init_state():
	if _stop_attack:
		return
	velocity.x = 0  # Detiene el movimiento horizontal
	_animation.play(animation)  # Reproduce la animación inicial
	_animation_effect.play("idle")
	_body = null  # Resetea la referencia del jugador
	_stop_detection = false

# Evento de cambio de frame en la animación del enemigo
func _on_enemy_animation_frame_changed():
	if _stop_attack:
		return
	if _animation.frame == 0 and _animation.get_animation() == "attack":
		_animation_effect.play("attack_effect")  # Efecto de ataque
		if HealthDashboard.life > 0:
			_audio_player.stream = _male_hurt_sound
			_audio_player.play()
		else:
			_animation.play("idle")
			_animation_effect.play("idle")
		if _body:
			var _move_script = _body.get_node("MainCharacterMovement")
			_move_script.hit(2)

# Detección del jugador en áreas específicas
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

# Función que inicia la persecución del jugador en una dirección
func _move(_direction):
	if _is_persecuted or _animation.get_animation() == "attack":
		return
	velocity.y += _gravity
	if not _direction:
		scale.x = -scale.x
	_is_persecuted = true
	_animation.play("run")

# Maneja el daño recibido
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

# Evento al finalizar una animación del enemigo
func _on_enemy_animation_animation_finished():
	if _animation.animation == "dead_ground":
		queue_free()  # Elimina el enemigo de la escena
	elif _animation.animation == "hit":
		if not _stop_attack: 
			_animation.play("idle")
			_animation_effect.play("idle")
			_attack()
