package game

import hm "../handle_map"

MAX_ENTITIES :: 1024

Entity_Handle :: distinct hm.Handle

Entity :: struct {
	handle:            Entity_Handle,
	kind:              EntityKind,

	// could pack these into flags if you feel like it (not really needed though)
	/*has_physics:         bool,
	damagable_by_player: bool,
	is_mob:              bool,
	blocks_mobs:         bool,*/

	// just put whatever state you need in here to make the game...
	pos:               Vec2,
	size:              Vec2,
	dir:               Entity_Direction,
	ent_rect:          EntityRect,
	side_jump:         bool,
	side_jump_timer:   f32,
	jumping_direction: Entity_Direction,
	can_run:           bool,
	vel:               Vec2,
	rect:              Rect,
	input:             Vec2,
	is_on_ground:      bool,
	action:            Entity_Action,
	movement:          Entity_Movement,
	orientation:       Entity_Orientation,
	last_orientation:  Entity_Orientation,
	wall_climbing:     bool,
	can_wall_climb:    bool,
	air_time:          f32,

	/*
	hit_cooldown_end_time: f64,
	health:                int,
	next_attack_time:      f64,*/
	anim:              Animation,
	flip_x:            bool,
	flip_y:            bool,
	corner_collider:   Rect,
	feet_collider:     Rect,
	face_collider:     Rect,
	head_collider:     Rect,

	// ...

	// Constant Entity Data
	//
	// this is constant based on the kind of the entity
	// you could put this somewhere else if you want, I like having it inside the entity for easy access though.
	// the 'using' is Odin/Jai specific and just makes it so you can:
	// 'entity.max_health' instead of 'entity.const_data.max_health'
	//
	//using const_data: Const_Entity_Data,
}

//EntityRect
EntityRect :: struct {
	min, max: Vec2,
	pos:      Vec2,
}

Entity_Orientation :: enum {
	norm,
	rot_left,
	rot_right,
	upside_down,
}
Entity_Direction :: enum {
	nil,
	left,
	right,
	up,
	down,
}

Entity_Movement :: enum {
	idle,
	walking,
	climbing_side,
	climbing_upside_down,
	jumping,
	fall_transition,
	falling,
	running,
	swinging,
	sliding,
}

Entity_Action :: enum {
	nil,
	jumping,
	falling,
	climbing,
	sliding,
}

Const_Entity_Data :: struct {
	update:     proc(_: ^Entity),
	draw:       proc(_: ^Entity),
	icon_image: Texture_Name,
}

EntityKind :: enum {
	nil,
	player,
	goblin,
	ogre,
	big_boss_goblin,
	wood_spikes,
	defense_wall,
}
