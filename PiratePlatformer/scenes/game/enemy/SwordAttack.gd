extends CharacterBody2D

@export var speed = 150  # Velocidad del ataque de espada
@export var lifetime = 1.0  # Duración del ataque en segundos
var direction = 1  # Dirección de movimiento (1 para derecha, -1 para izquierda)

# Lógica de inicialización
func _ready():
	set_physics_process(true)  # Activa el procesamiento físico
	await(get_tree().create_timer(lifetime))
	queue_free()  # Elimina el ataque después del tiempo de vida

# Movimiento del ataque
func _physics_process(delta):
	velocity.x = direction * speed  # Aplica la velocidad en la dirección del ataque
	move_and_slide()  # Mueve el ataque en la dirección indicada
