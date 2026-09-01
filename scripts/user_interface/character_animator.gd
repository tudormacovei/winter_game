## Tracks & animates NPC sprites present in the dialogue scene
##
## At most 3 NPC's can be present in the same scene simultaneously, more will not be shown! An error will be logged if more than 3 are added
class_name CharacterAnimator
extends Node3D

enum LookState { ABSENT, IDLE, SPEAKING }

# TODO: might be worth changing this to a list?
@export_group("Sprite Slots")
@export var slot_sprite_1: Sprite3D
@export var slot_sprite_2: Sprite3D
@export var slot_sprite_3: Sprite3D

@export_group("Sprite Animations")
@export var idle_enter_duration: float = 0.5 # absent -> idle
@export var idle_exit_duration: float = 0.5 # idle -> absent
@export var speaking_enter_duration: float = 0.25 # idle -> speaking
@export var speaking_exit_duration: float = 0.25 # speaking -> idle
@export var compaction_slide_duration: float = 0.33 # duration of sprite slot change after character(s) leave


# The speaker steps forward on z to draw in front of the other characters
# For some reason render priority is not working????) TODO: change to render prio or some other type of sprite ordering
const _SPEAKING_POSITION_OFFSET := Vector3(0.0, 0.0, 0.005) # in front when speaking
const _IDLE_POSITION_OFFSET := Vector3(0.0, -0.2, 0.0) # lower when idle

# Share of its own push that the speaker steps aside by
# TODO: this sprite movement system is still hacky, worth improving at one point
const _SPEAKER_PUSH_FRACTION := 0.75

# Store the look of the sprites in these material properties, because the crosshatch is drawn by the shader
const _TEXTURE_ALBEDO_PROPERTY := "shader_parameter/texture_albedo"
const _REVEAL_BOTTOM_PERCENTAGE_PROPERTY := "shader_parameter/reveal_bottom_percentage"
const _REVEAL_TOP_PERCENTAGE_PROPERTY := "shader_parameter/reveal_top_percentage"
const _SPRITE_VISIBILITY_PROPERTY := "shader_parameter/sprite_visibility"

const _LOOK_VALUES := {
	LookState.ABSENT: {
		_REVEAL_BOTTOM_PERCENTAGE_PROPERTY: 0.0,
		_REVEAL_TOP_PERCENTAGE_PROPERTY: 0.0,
		_SPRITE_VISIBILITY_PROPERTY: 0.0,
	},
	LookState.IDLE: {
		_REVEAL_BOTTOM_PERCENTAGE_PROPERTY: 0.0,
		_REVEAL_TOP_PERCENTAGE_PROPERTY: 100.0,
		_SPRITE_VISIBILITY_PROPERTY: 0.0,
	},
	LookState.SPEAKING: {
		_REVEAL_BOTTOM_PERCENTAGE_PROPERTY: 100.0,
		_REVEAL_TOP_PERCENTAGE_PROPERTY: 100.0,
		_SPRITE_VISIBILITY_PROPERTY: 1.0,
	},
}

var _slots: Array[Slot] = []

# Animation queue
var _queue: Array[Callable] = [] # each Callable in the queue represents one animation, the animations in the queue play sequentially (not in parallel)
var _running_tween: Tween = null


func _ready() -> void:
	for sprite in [slot_sprite_1, slot_sprite_2, slot_sprite_3]:
		# Each sprite gets its own copy of the material so that shader params like texture and crosshatch fill percentage can differ per sprite
		if sprite.material_override != null:
			sprite.material_override = sprite.material_override.duplicate()
		_slots.append(Slot.new(sprite))
		_hide_sprite(sprite)

func has_sprite_for(character: CharacterDefinition) -> bool:
	return character != null and character.default_sprite != null


## The given character becomes the speaker and the previous speaker becomes idle.
## A character that is not present will first play the enter animation for themselves.
func set_speaker(character: CharacterDefinition, expression_tag: String = "") -> void:
	_queue_animation(_set_speaker_animation.bind(character, expression_tag))


## Narration active: the speaker becomes idle in place. The other characters are idle already.
func set_narration() -> void:
	_queue_animation(_set_narration_animation)


## The given characters exit the scene at the same time
func exit_characters(characters: Array[CharacterDefinition]) -> void:
	_queue_animation(_exit_characters_animation.bind(characters))


## Every NPC leaves the scene at the same time
func exit_all() -> void:
	_queue_animation(_exit_all_animation)


## Fast-forwards the running animation and every queued one to its end state
func skip_animations() -> void:
	var guard := 0 # guard against some tween not properly exiting so we don't infinite loop
	while _running_tween != null and guard < 100:
		guard += 1
		_running_tween.custom_step(1e2) # skip ahead 100 seconds, guaranteed to finish the tween


## Cancels every running animation and clears the scene of sprites
func clear() -> void:
	if _running_tween != null:
		_running_tween.kill()
		_running_tween = null
	_queue.clear()
	for slot in _slots:
		slot.character = null
		slot.look_state = LookState.ABSENT
		_hide_sprite(slot.sprite)


#region Queue

func _queue_animation(animation: Callable) -> void:
	_queue.append(animation)
	if _running_tween == null or not _running_tween.is_valid():
		_run_next_animation() # a tween that was killed or dropped never emits finished


func _run_next_animation() -> void:
	while not _queue.is_empty():
		var animation: Callable = _queue.pop_front()
		var tween: Tween = animation.call()
		if tween == null:
			continue # nothing to animate, go straight to the next animation
		_running_tween = tween
		tween.finished.connect(_on_running_tween_finished, CONNECT_ONE_SHOT)
		return


func _on_running_tween_finished() -> void:
	_running_tween = null
	_run_next_animation()


#endregion


#region Animations

## Animation for a character entering the scene as the speaker
## Precondition: the character is absent
func _enter_animation(character: CharacterDefinition, expression_tag: String) -> Tween:
	if not has_sprite_for(character):
		return null

	var slot := _first_empty_slot()
	if slot == null:
		Utils.debug_error("CharacterAnimator: All %d slots are taken. '%s' is not shown." % [_slots.size(), character.display_name])
		return null

	slot.character = character
	_apply_expression(slot, expression_tag)
	slot.sprite.position = _target_position(slot)
	_set_sprite_look(slot.sprite, LookState.ABSENT)
	slot.sprite.visible = true

	var tween := create_tween().set_parallel(true)
	_tween_speaker_change(tween, slot)
	return tween


## Animation for a character (present or not) in the scene becoming the speaker
func _set_speaker_animation(character: CharacterDefinition, expression_tag: String) -> Tween:
	var slot := _slot_of(character)
	if slot == null:
		return _enter_animation(character, expression_tag)

	_apply_expression(slot, expression_tag)
	if slot.look_state == LookState.SPEAKING: # the same character speaks again, only the expression changed
		return null

	var tween := create_tween().set_parallel(true)
	_tween_speaker_change(tween, slot)
	return tween

# TODO: might change this in the future, not sure if a separate look for narration is needed
func _set_narration_animation() -> Tween:
	var speaking_slot := _speaking_slot()
	if speaking_slot == null:
		return null

	var tween := create_tween().set_parallel(true)
	_tween_slot_look(tween, speaking_slot, LookState.IDLE, 0.0)
	_tween_positions(tween, 0.0)
	return tween


func _exit_characters_animation(characters: Array[CharacterDefinition]) -> Tween:
	var leaving_slots: Array[Slot] = []
	for character in characters:
		var slot := _slot_of(character)
		if slot != null:
			leaving_slots.append(slot)
	if leaving_slots.is_empty():
		return null

	var tween := create_tween().set_parallel(true)
	var last_exit_end := 0.0
	for slot in leaving_slots:
		var exit_duration := _tween_slot_look(tween, slot, LookState.ABSENT, 0.0)
		_tween_position(tween, slot, speaking_exit_duration, 0.0) # a leaving speaker drops as it dissolves
		tween.tween_callback(_hide_sprite.bind(slot.sprite)).set_delay(exit_duration)
		slot.character = null
		last_exit_end = maxf(last_exit_end, exit_duration)
	_compact_slots(tween, last_exit_end)
	return tween


func _exit_all_animation() -> Tween:
	var present_characters: Array[CharacterDefinition] = []
	for slot in _occupied_slots():
		present_characters.append(slot.character)
	return _exit_characters_animation(present_characters)

#endregion


#region Transitions

# Note: as a rule the tweens for any given animation run in paralel, we control ordering between them via start delays

## The given slot becomes the speaker while the previous speaker becomes idle.
## The positions follow both look walks, so every push is measured against the new speaker
func _tween_speaker_change(tween: Tween, new_speaker: Slot) -> void:
	var previous_speaker := _speaking_slot()
	var speaker_is_arriving := new_speaker.look_state == LookState.ABSENT
	if previous_speaker != null:
		_tween_slot_look(tween, previous_speaker, LookState.IDLE, 0.0)
	_tween_slot_look(tween, new_speaker, LookState.SPEAKING, 0.0)
	# An arriving speaker holds its place while its crosshatch forms, then rises
	_tween_positions(tween, idle_enter_duration if speaker_is_arriving else 0.0)


## Tweens the sprite of a slot to the look of the target state, passing through the IDLE state if necessary!
func _tween_slot_look(tween: Tween, slot: Slot, target_state: LookState, start_delay: float) -> float:
	var total_duration := 0.0
	if absi(target_state - slot.look_state) == 2: # we have to pass through the intermediate idle state
		total_duration += _tween_one_look_step(tween, slot, LookState.IDLE, start_delay)
	if slot.look_state != target_state:
		total_duration += _tween_one_look_step(tween, slot, target_state, start_delay + total_duration)
	return total_duration


func _tween_one_look_step(tween: Tween, slot: Slot, next_state: LookState, delay: float) -> float:
	var duration: float
	if slot.look_state == LookState.ABSENT:
		duration = idle_enter_duration
	elif next_state == LookState.ABSENT:
		duration = idle_exit_duration
	elif next_state == LookState.SPEAKING:
		duration = speaking_enter_duration
	else:
		duration = speaking_exit_duration
	var look_values: Dictionary = _LOOK_VALUES[next_state]
	for property in look_values:
		var material := slot.sprite.material_override as ShaderMaterial
		if material != null:
			tween.tween_property(material, property, look_values[property], duration).set_delay(delay)
	slot.look_state = next_state
	return duration


## Shifts the present characters toward slot 1, then slides every NPC sprite to its slot
func _compact_slots(tween: Tween, delay: float) -> void:
	var target_index := 0
	for slot_index in _slots.size():
		if _slots[slot_index].is_empty():
			continue
		if slot_index != target_index:
			_slots[target_index].swap_occupant_with(_slots[slot_index])
		target_index += 1
	for slot in _occupied_slots():
		_tween_position(tween, slot, compaction_slide_duration, delay)


## Every present character slides to the position of their current look state
func _tween_positions(tween: Tween, speaker_delay: float) -> void:
	for slot in _occupied_slots():
		if slot.look_state == LookState.SPEAKING:
			_tween_position(tween, slot, speaking_enter_duration, speaker_delay)
		else:
			_tween_position(tween, slot, speaking_exit_duration, 0.0)


func _tween_position(tween: Tween, slot: Slot, duration: float, delay: float) -> void:
	var position_tweener := tween.tween_property(slot.sprite, "position", _target_position(slot), duration)
	position_tweener.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


## Where the character of a slot stands. The speaker gets extra space on the x-axis
func _target_position(slot: Slot) -> Vector3:
	var speaker := _speaking_slot()
	if speaker == null:
		return slot.idle_position
	var push_distance: float = speaker.character.speaking_push_distance
	if slot == speaker:
		return slot.speaking_position + Vector3(_speaker_push_direction(speaker) * push_distance * _SPEAKER_PUSH_FRACTION, 0.0, 0.0)
	var push_direction := signf(slot.idle_position.x - speaker.idle_position.x)
	return slot.idle_position + Vector3(push_direction * push_distance, 0.0, 0.0)


## The direction the speaker steps aside in, opposite to the one it pushes the others in
func _speaker_push_direction(speaker: Slot) -> float:
	var speaker_is_leftmost := true
	var speaker_is_rightmost := true
	for slot in _occupied_slots():
		if slot == speaker:
			continue
		if slot.idle_position.x < speaker.idle_position.x:
			speaker_is_leftmost = false
		else:
			speaker_is_rightmost = false
	if speaker_is_leftmost == speaker_is_rightmost: # alone, or others on both sides
		return 0.0
	return -1.0 if speaker_is_leftmost else 1.0

#endregion


#region Slots

func _slot_of(character: CharacterDefinition) -> Slot:
	for slot in _slots:
		if slot.character == character:
			return slot
	return null


## At most one slot is speaking. Null during narration (for now, narration behavior TBD)
func _speaking_slot() -> Slot:
	for slot in _slots:
		if slot.look_state == LookState.SPEAKING:
			return slot
	return null


func _occupied_slots() -> Array[Slot]:
	return _slots.filter(func(slot: Slot) -> bool: return not slot.is_empty())


func _first_empty_slot() -> Slot:
	for slot in _slots:
		if slot.is_empty():
			return slot
	return null

#endregion


#region Sprites

func _apply_expression(slot: Slot, expression_tag: String) -> void:
	var texture: Texture2D = slot.character.default_sprite
	if not expression_tag.is_empty():
		if slot.character.alt_sprites.has(expression_tag):
			texture = slot.character.alt_sprites[expression_tag]
		else:
			push_warning("CharacterAnimator: '%s' has no sprite for expression '%s'. Default sprite is used." % [slot.character.display_name, expression_tag])
	slot.sprite.texture = texture
	_set_look_property(slot.sprite, _TEXTURE_ALBEDO_PROPERTY, texture)


func _hide_sprite(sprite: Sprite3D) -> void:
	sprite.visible = false
	sprite.texture = null
	_set_look_property(sprite, _TEXTURE_ALBEDO_PROPERTY, null)
	_set_sprite_look(sprite, LookState.ABSENT)


func _set_sprite_look(sprite: Sprite3D, state: LookState) -> void:
	var look_values: Dictionary = _LOOK_VALUES[state]
	for property in look_values:
		_set_look_property(sprite, property, look_values[property])


## The texture is a look property too: an override material does not receive the sprite
## texture on its own. A sprite without the crosshatch material stays a plain, always
## visible sprite, so both helpers do nothing
func _set_look_property(sprite: Sprite3D, property: String, value: Variant) -> void:
	var material := sprite.material_override as ShaderMaterial
	if material == null:
		return
	material.set(property, value)


#endregion


## Slots are our ground truth for where the characters should be placed
## Slots are stationary (the positions never change, to prevent drift). Characters are swapped between slots when the slots compact.
class Slot:
	var idle_position: Vector3
	var speaking_position: Vector3
	var character: CharacterDefinition = null # null = empty slot
	var sprite: Sprite3D
	var look_state := CharacterAnimator.LookState.ABSENT

	func _init(slot_sprite: Sprite3D) -> void:
		idle_position = slot_sprite.position + CharacterAnimator._IDLE_POSITION_OFFSET
		speaking_position = slot_sprite.position + CharacterAnimator._SPEAKING_POSITION_OFFSET
		sprite = slot_sprite

	func is_empty() -> bool:
		return character == null

	func swap_occupant_with(other: Slot) -> void:
		var other_character := other.character
		var other_sprite := other.sprite
		var other_look_state := other.look_state
		other.character = character
		other.sprite = sprite
		other.look_state = look_state
		character = other_character
		sprite = other_sprite
		look_state = other_look_state
