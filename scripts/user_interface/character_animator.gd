## Tracks & animates NPC sprites present in the dialogue scene
##
## At most 3 NPC's can be present in the same scene simultaneously, more will not be shown! An error will be logged if more than 3 are added
class_name CharacterAnimator
extends Node3D

enum SlotIndex { PRIMARY, IDLE_1, IDLE_2 }

## The three exported sprites are the sprite objects we will animate
## The position of each sprite is the position of the slot it is named after (but note that the actual sprites will not remain the ones used for primary/idle1/idle2 since they will be shuffled around)
@export_group("Sprite Slots")
@export var primary_sprite: Sprite3D
@export var idle_sprite_1: Sprite3D
@export var idle_sprite_2: Sprite3D

@export_group("Sprite Animations")
@export var enter_duration: float = 0.75
@export var swap_duration: float = 0.33 # position change on a speaker change
@export var brightness_duration: float = 0.25
@export var idle_brightness: float = 0.45
@export var exit_duration: float = 0.75
@export var exit_stagger_duration: float = 0.5 # gap between the exits when dialogue ends with multiple npcs still in the interaction


# NPC presentation state
var _slots: Array[Slot] = [] # indexed on SlotIndex
var _is_narration := false # lines without a speaker are considered narration. All NPC's will be in the idle state

# Animation queue
var _queue: Array[Callable] = [] # each Callable in the queue represents one animation, the animations in the queue play sequentially (not in parallel)
var _running_tween: Tween = null


func _ready() -> void:
	for sprite in [primary_sprite, idle_sprite_1, idle_sprite_2]:
		_slots.append(Slot.new(sprite))
		_hide_sprite(sprite)

## Sanity check: does the given character have a default sprite to display?
func has_sprite_for(character: CharacterDefinition) -> bool:
	return character != null and character.default_sprite != null


## The given character becomes the speaker and swaps slots with the previous speaker.
## A character that is not present will first play the enter animation for themselves.
func set_speaker(character: CharacterDefinition, expression_tag: String = "") -> void:
	_queue_animation(_set_speaker_animation.bind(character, expression_tag))


## Narration active: every present character becomes idle, sprite positions do not change.
func set_narration() -> void:
	_queue_animation(_set_narration_animation)


## The given characters exit the scene at the same time
func exit_characters(characters: Array[CharacterDefinition]) -> void:
	_queue_animation(_exit_characters_animation.bind(characters))


## Everyone leaves with a staggered exit: idle_2 first, then idle_1, then the speaker.
func exit_all() -> void:
	_queue_animation(_exit_all_animation)


## Completes the running animation and every queued one simultaneously, skipping to the animation end state
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
		_hide_sprite(slot.sprite)
	_is_narration = false


#region Queue

func _queue_animation(animation: Callable) -> void:
	_queue.append(animation)
	if _running_tween == null:
		_run_next_animation()


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


func _create_animation() -> Tween:
	return create_tween().set_parallel(true)

#endregion


#region Animations

## Animation for a character that is not present in the scene entering the scene
## Given character will become the speaker
func _enter_animation(character: CharacterDefinition, expression_tag: String) -> Tween:
	if not has_sprite_for(character):
		return null
	if _slot_of(character) != null:
		return _set_speaker_animation(character, expression_tag)

	var primary := _slots[SlotIndex.PRIMARY]
	if not primary.is_empty():
		var free_idle_slot := _first_empty_idle_slot()
		if free_idle_slot == null:
			Utils.debug_error("CharacterAnimator: All %d slots are taken. '%s' is not shown." % [SlotIndex.size(), character.display_name])
			return null
		primary.swap_occupant_with(free_idle_slot)

	primary.character = character
	var sprite := primary.sprite
	_is_narration = false

	_apply_expression(primary, expression_tag)
	sprite.position = primary.position
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	sprite.visible = true

	var tween := _create_animation()
	tween.tween_property(sprite, "modulate:a", 1.0, enter_duration)
	_tween_occupied_slots(tween)
	return tween


## Animation for a character present in the scene becoming the speaker: it swaps slots with the previous speaker
## A character that is not present plays the enter animation instead
func _set_speaker_animation(character: CharacterDefinition, expression_tag: String) -> Tween:
	var slot := _slot_of(character)
	if slot == null:
		return _enter_animation(character, expression_tag)

	var primary := _slots[SlotIndex.PRIMARY]
	if slot != primary:
		primary.swap_occupant_with(slot) # when primary was empty this empties the idle slot
		_compact_idle_slots()
	_is_narration = false
	_apply_expression(primary, expression_tag)

	var tween := _create_animation()
	_tween_occupied_slots(tween)
	return tween


func _set_narration_animation() -> Tween:
	if _occupied_slots().is_empty():
		return null
	_is_narration = true

	var tween := _create_animation()
	_tween_occupied_slots(tween)
	return tween


func _exit_characters_animation(characters: Array[CharacterDefinition]) -> Tween:
	var leaving_sprites: Array[Sprite3D] = []
	for character in characters:
		var slot := _slot_of(character)
		if slot != null:
			leaving_sprites.append(slot.sprite)
			slot.character = null
	if leaving_sprites.is_empty():
		return null
	_compact_idle_slots()

	var tween := _create_animation()
	for sprite in leaving_sprites:
		tween.tween_property(sprite, "modulate:a", 0.0, exit_duration)
		tween.tween_callback(_hide_sprite.bind(sprite)).set_delay(exit_duration)
	_tween_occupied_slots(tween)
	return tween


func _exit_all_animation() -> Tween:
	var exit_order := _occupied_slots()
	if exit_order.is_empty():
		return null
	exit_order.reverse() # idle_2, idle_1, speaker

	var tween := _create_animation()
	for index in exit_order.size():
		var sprite := exit_order[index].sprite
		var delay := index * exit_stagger_duration
		tween.tween_property(sprite, "modulate:a", 0.0, exit_duration).set_delay(delay)
		tween.tween_callback(_hide_sprite.bind(sprite)).set_delay(delay + exit_duration)
		exit_order[index].character = null

	_is_narration = false
	return tween

#endregion


#region Helpers

func _slot_of(character: CharacterDefinition) -> Slot:
	for slot in _slots:
		if slot.character == character:
			return slot
	return null


## Occupied slots in slot order: primary, idle_1, idle_2
func _occupied_slots() -> Array[Slot]:
	return _slots.filter(func(slot: Slot) -> bool: return not slot.is_empty())


func _first_empty_idle_slot() -> Slot:
	for slot_index in [SlotIndex.IDLE_1, SlotIndex.IDLE_2]:
		if _slots[slot_index].is_empty():
			return _slots[slot_index]
	return null


## If idle_1 is empty, slides the character at idle_2 into it & empties idle_2
func _compact_idle_slots() -> void:
	if _slots[SlotIndex.IDLE_1].is_empty() and not _slots[SlotIndex.IDLE_2].is_empty():
		_slots[SlotIndex.IDLE_1].swap_occupant_with(_slots[SlotIndex.IDLE_2])


## Animates the sprites in all slots such that they match the location & position of the slots they are in
func _tween_occupied_slots(tween: Tween) -> void:
	for slot_index in SlotIndex.size():
		var slot := _slots[slot_index]
		if slot.is_empty():
			continue
		var is_speaking := slot_index == SlotIndex.PRIMARY and not _is_narration
		var brightness := 1.0 if is_speaking else idle_brightness
		tween.tween_property(slot.sprite, "position", slot.position, swap_duration)
		tween.tween_property(slot.sprite, "modulate:r", brightness, brightness_duration)
		tween.tween_property(slot.sprite, "modulate:g", brightness, brightness_duration)
		tween.tween_property(slot.sprite, "modulate:b", brightness, brightness_duration)

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


func _hide_sprite(sprite: Sprite3D) -> void:
	sprite.visible = false
	sprite.texture = null
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)

#endregion


## Slots are our ground truth for where the characters should be placed and how they should look like
## Slots are stationary (the position never changes), characters are placed into and swapped between slots
class Slot:
	var position: Vector3
	var character: CharacterDefinition = null # null = empty slot
	var sprite: Sprite3D

	func _init(slot_sprite: Sprite3D) -> void:
		position = slot_sprite.position
		sprite = slot_sprite

	func is_empty() -> bool:
		return character == null

	func swap_occupant_with(other: Slot) -> void:
		var other_character := other.character
		var other_sprite := other.sprite
		other.character = character
		other.sprite = sprite
		character = other_character
		sprite = other_sprite
