package game
import hm "../handle_map"
import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

get_player :: proc() -> ^Entity {
	return hm.get(g.entities, g.player_handle)
}

//Resets the player to default values
resetPlayer :: proc() {
	//check that our handle exists, remove it from the handle_map if it does
	//otherwise recreate the player handle. 
	if p := hm.get(g.entities, g.player_handle); p != nil {
		hm.remove(&g.entities, g.player_handle)
	}
	// Recreate player and assign that entity to g.player_handle
	g.player_handle = hm.add(
		&g.entities,
		Entity {
			anim = animation_create(.Frog_Idle),
			pos = {0, 0},
			dir = .left,
			vel = {0, 0},
			size = {},
			is_on_ground = true,
			movement = .idle,
			orientation = .norm,
			flip_x = false,
			flip_y = false,
			feet_collider = Rect{},
			face_collider = Rect{},
			head_collider = Rect{},
			corner_collider = Rect{},
		},
	)
}

//returns center pos of player. 
player_center :: proc() -> Vec2 {
	p := get_player()
	dest := p.pos
	switch (p.orientation) 
	{
	case .norm:
		dest.y -= p.rect.height / 2
	case .rot_left:
		dest.x -= p.rect.width / 2
	case .rot_right:
		dest.x += p.rect.height / 2
	case .upside_down:
		dest.y += p.rect.height / 2
	}
	return dest
}

update_player :: proc(dt: f32) {
	p := get_player()

	//For keeping our input value so we continue to move outwards when jumping from the edge of a platform
	if !p.side_jump {p.input = {}} else {
		p.side_jump_timer += dt
		if p.side_jump_timer > 1 {
			p.side_jump = false
			p.side_jump_timer = 0
		}
	}

	if !p.wall_climbing {
		//fmt.printf("Adding gravity?\n")
		p.vel.y += GRAVITY * dt
	} else {
		p.vel.y += 0 * dt
	}

	//old_pos := p.pos
	if !p.is_on_ground {
		p.air_time += dt
		if p.air_time > .55 {
			if p.movement != .falling {
				p.movement = .falling
				p.anim = animation_create(.Frog_Fall)
			}
		}
	} else {p.air_time = 0}

	p.pos += (p.vel * dt)
	//Checking if player is able to run
	/*if p.can_run {
		p.pos += (p.vel * running_multiplier) * dt
	} else {

	}*/

	//Reset player position and states/actions
	if rl.IsKeyPressed(.R) {
		resetPlayer()
	}

	//Hold onto walls?
	if rl.IsKeyDown(.LEFT_SHIFT) {
		p.can_wall_climb = true
	} else {
		p.can_wall_climb = false
	}

	//Movement - depends on orientation
	if rl.IsKeyDown(.LEFT) || rl.IsKeyDown(.A) {
		switch (p.orientation) 
		{
		case .norm:
			if p.last_orientation == .rot_left {
				p.input.x += 1
				if p.dir != .right {p.dir = .right}
			} else {
				p.input.x -= 1
				if p.dir != .left {p.dir = .left}
			}
			if p.movement != .walking && p.is_on_ground {
				p.movement = .walking
				//fmt.printf("Setting animation : .Frog_Move\n")
				p.anim = animation_create(.Frog_Move)
			}
		//hanging onto right side of wall/platform
		case .rot_left:
			//fix direction change when going from upside down to rotated (left/right is reversed)
			if p.last_orientation == .upside_down {
				p.input.y -= 1
				if p.dir != .right {p.dir = .right}
			} else {
				p.input.y += 1
				if p.dir != .left {p.dir = .left}
			}
		case .rot_right:
			p.input.y -= 1
			if p.dir != .left {p.dir = .left}
		//left.right is reversed here
		case .upside_down:
			if p.last_orientation == .rot_left {
				p.input.x += 1
				if p.dir != .left {p.dir = .left}
			} else {
				p.input.x -= 1
				if p.dir != .right {p.dir = .right}
			}
		}
	}

	//fixes issue where player cannot move left after moving around a platform
	//from the left side to upside down. 
	if rl.IsKeyReleased(.LEFT) || rl.IsKeyReleased(.A) {
		p.last_orientation = p.orientation
	}

	//right
	if rl.IsKeyDown(.RIGHT) || rl.IsKeyDown(.D) {
		switch (p.orientation) 
		{
		case .norm:
			if p.last_orientation == .rot_right {
				p.input.x -= 1
				if p.dir != .left {p.dir = .left}
			} else {
				p.input.x += 1
				if p.dir != .right {p.dir = .right}
			}
			if p.is_on_ground && p.movement != .walking {
				p.movement = .walking
				p.anim = animation_create(.Frog_Move)
			}
		case .rot_left:
			p.input.y -= 1
			if p.dir != .right {p.dir = .right}
			if p.is_on_ground && p.movement != .climbing_side {
				p.movement = .climbing_side
				p.anim = animation_create(.Frog_Move)
			}
		case .rot_right:
			if p.last_orientation == .upside_down {
				p.input.y -= 1
				if p.dir != .left {p.dir = .left}
			} else {
				p.input.y += 1
				if p.dir != .right {p.dir = .right}
			}
			if p.is_on_ground && p.movement != .climbing_side {
				p.movement = .climbing_side
				p.anim = animation_create(.Frog_Climb)
			}
		case .upside_down:
			if p.last_orientation == .rot_right {p.input.x -= 1
				if p.dir != .right {p.dir = .right}
			} else {
				p.input.x += 1
				if p.dir != .left {p.dir = .left}
			}
		}
	}

	if rl.IsKeyReleased(.RIGHT) || rl.IsKeyReleased(.D) {
		p.last_orientation = p.orientation
	}

	//Jumping
	//We have a switch to determine the orientation so we can calculate the jump angle properly
	if rl.IsKeyPressed(.SPACE) || rl.IsKeyDown(.W) {
		switch p.orientation 
		{
		case .norm:
			if p.is_on_ground {
				p.input.y = -1
				p.vel.y = -150
				p.is_on_ground = false
				p.movement = .jumping
				p.anim = animation_create(.Frog_Jump)
				//rl.PlaySound(g.land_sound)
			}
		case .rot_left:
			if p.wall_climbing && p.is_on_ground {
				//p.orientation = .norm
				p.dir = .left
				p.orientation = .norm
				p.input.y = -.5
				p.input.x = -1
				p.vel.y = -150
				p.is_on_ground = false
				p.wall_climbing = false
				p.movement = .jumping
				p.anim = animation_create(.Frog_Jump)
				p.side_jump = true
			}
		case .rot_right:
			if p.wall_climbing && p.is_on_ground {
				//p.orientation = .norm
				p.dir = .right
				p.orientation = .norm
				p.input.y = -.5
				p.input.x = +1
				p.vel.y = -150
				p.is_on_ground = false
				p.wall_climbing = false
				p.movement = .jumping
				p.anim = animation_create(.Frog_Jump)
				p.side_jump = true
			}
		case .upside_down:
			if p.wall_climbing && p.is_on_ground {
				//p.orientation = .norm
				if p.dir == .left {
					p.input.x = +1
					p.dir = .right
				} else {
					p.input.x = -1
					p.dir = .left
				}
				p.orientation = .norm
				p.input.y += 0.5
				p.vel.y = +150
				p.is_on_ground = false
				p.wall_climbing = false
				p.movement = .jumping
				p.anim = animation_create(.Frog_Jump)
				p.side_jump = true
			}
		}


	}

	//Tongue attack?	
	if rl.IsMouseButtonPressed(.LEFT) {
		fmt.printf("Player Attac\n")
		/*if p.can_attack {
			pos := rl.GetScreenToWorld2D(rl.GetMousePosition(), game_camera())
			player_attack(pos)
			//if we click to our right, turn right
			if p.dir == .left && pos.x > p.pos.x {
				p.dir = .right
			} else if p.dir == .right && pos.x < p.pos.x {
				p.dir = .left
			}
		}*/
	}

	//idle check - dependent on rotation
	if p.orientation == .norm {
		if p.input.x == 0 && p.is_on_ground {
			//fmt.printf("Player is idle\n")
			if p.movement != .idle {
				p.movement = .idle
				p.anim = animation_create(.Frog_Idle)
			}
		}
	} else {
		//if rotated and not climbing
		if (p.orientation == .rot_left || p.orientation == .rot_right) && p.input.y == 0 {
			if p.movement != .climbing_side {
				p.movement = .climbing_side
				p.anim = animation_create(.Frog_Climb)
			}
		} else if p.orientation == .upside_down {
			if p.movement != .climbing_side {
				p.movement = .climbing_side
				p.anim = animation_create(.Frog_Climb)
			}
		}
	}

	// Update player pos by the input
	p.input = linalg.normalize0(p.input)
	p.pos += p.input * dt * 75

	//Check if player is grounded using colliders with platforms
	//collider update - based on orientation
	//rotate_player rotates all colliders etc.
	has_collided := false
	update_player_colliders()
	if p.orientation != .norm {
		rotate_player()
	} else {
		//facing left
		if p.dir == .left {
			if p.movement == .falling {
				p.head_collider = {p.pos.x - (p.rect.width / 2) + 2, p.rect.y, 4, 1}
				p.feet_collider = {p.pos.x, p.pos.y, p.rect.width / 2, 1}
				p.face_collider = {
					p.pos.x - (p.rect.width / 2),
					p.pos.y - (p.rect.height * .75),
					1,
					4,
				}
				p.corner_collider = {p.pos.x + 4, p.pos.y, 1, 1}
			} else {
				p.head_collider = {p.pos.x - (p.rect.width / 2) + 2, p.rect.y, 4, 1}
				p.feet_collider = {p.pos.x + 2, p.pos.y, p.rect.width / 2 - 2, 1}
				p.face_collider = {
					p.pos.x - (p.rect.width / 2),
					p.pos.y - (p.rect.height * .75),
					1,
					4,
				}
				p.corner_collider = {p.pos.x + 4, p.pos.y, 1, 1}
			}
			//facing right
		} else if p.dir == .right {
			if p.movement == .falling {
				p.head_collider = {p.pos.x, p.rect.y, 4, 1}
				p.feet_collider = {p.rect.x + 1, p.pos.y, p.rect.width / 2, 1}
				p.face_collider = {p.rect.x + p.rect.width, p.pos.y - p.rect.width / 2, 1, 4}
				p.corner_collider = {p.pos.x - 4, p.pos.y, 1, 1}
			} else {
				p.head_collider = {p.pos.x, p.rect.y, 4, 1}
				p.feet_collider = {p.rect.x, p.pos.y, p.rect.width / 2 - 1, 1}
				p.face_collider = {p.rect.x + p.rect.width, p.pos.y - (p.rect.height * .75), 1, 4}
				p.corner_collider = {p.pos.x - 4, p.pos.y, 1, 1}
			}

		}
	}

	//checking if we have collided with feet collider - if we aren't moving we are idle. 
	for platform in level.platforms {
		if platform.exists {
			//feet collider
			if p.action != .jumping {
				if !p.side_jump {
					// if we fall off the left side of a platform and we collide with our head, offset player by the platform pos - player.width
					if p.movement == .falling {
						if p.dir == .right {
							if rl.CheckCollisionRecs(p.head_collider, platform.faces[3]) {
								p.pos.x = platform.faces[3].x - p.rect.width + 1

							}
						}
					}
					if rl.CheckCollisionRecs(p.feet_collider, platform.pos_rect) {

						//if face collides with left side of platform then we do not set the player on top
						//set player to be offset by the platform edge
						if p.dir == .right && p.pos.y < platform.pos_rect.y - 1 {
							return
						}

						p.is_on_ground = true
						p.vel.y = 0
						p.pos.y = platform.pos_rect.y - p.size.y - 1

						if p.movement != .idle {
							if p.input.x == 0 {
								p.movement = .idle
								p.anim = animation_create(.Frog_Idle)
							}
						}
						has_collided = true
					}
				}
			}
		}
	}

	//if we have not collided with any platforms, we are not grounded
	if !has_collided && !p.wall_climbing {
		if p.movement != .jumping {
			p.is_on_ground = false
			//If player walked off a platform, we want to delay the falling animation
			if p.movement == .walking {
				p.movement = .fall_transition
			} else {
				if p.vel.y > 0 {
					if p.movement != .falling {
						p.orientation = .norm
						p.movement = .falling
						p.anim = animation_create(.Frog_Fall)
					}
				} else if p.vel.y < 0 {
					if p.movement != .jumping {
						//fmt.printf("Jumping\n")
						p.movement = .jumping
						p.anim = animation_create(.Frog_Jump)
					}
				}
			}
		}
	}

	//corner collision and wall walking/climbing detection
	for platform in level.platforms {
		if platform.exists {
			//check if player is colliding with the corner of a platform
			for c, c_idx in platform.corners {
				if rl.CheckCollisionRecs(c, p.corner_collider) && p.movement != .jumping {
					//fmt.printf("Player collided with corner: %i,%i\n", idx, c_idx)
					// Switch based on player orientation is easiest way to seperate logic
					switch (p.orientation) {
					//Player is oriented normally
					case .norm:
						//Player has leftshift down to enable wall climbing
						if p.can_wall_climb {
							//if player is facing left and collides with left corner of a platform
							if c_idx == 0 && p.dir == .left {
								p.last_orientation = .norm
								p.last_orientation = .norm
								p.orientation = .rot_left
								p.wall_climbing = true
								p.pos.x = c.x
								p.pos.y = c.y + c.height + 2
								//if player is facing right and collides with right corner of a platform
							} else if c_idx == 1 && p.dir == .right {
								p.last_orientation = .norm
								p.orientation = .rot_right
								p.wall_climbing = true
								p.pos.x = c.x + c.width / 2
								p.pos.y = c.y + c.height + 2
							}
						}
					case .rot_left:
						if c_idx == 0 && p.dir == .right {
							p.last_orientation = .rot_left
							p.orientation = .norm
							p.wall_climbing = false
							p.pos.x = c.x + c.width
							p.pos.y = c.y
						} else if c_idx == 2 && p.dir == .left {
							p.last_orientation = .rot_left
							p.orientation = .upside_down
							p.wall_climbing = true
							p.pos.x = c.x + 2
							p.pos.y = platform.pos.y + platform.pos_rect.height
						}
					case .rot_right:
						if c_idx == 1 && p.dir == .left {
							p.last_orientation = .rot_right
							p.orientation = .norm
							p.wall_climbing = false
							p.pos.x = c.x
							p.pos.y = c.y
						} else if c_idx == 3 && p.dir == .right {
							p.last_orientation = .rot_right
							p.orientation = .upside_down
							p.wall_climbing = true
							p.pos.x = c.x
							p.pos.y = platform.pos.y + platform.pos_rect.height
						}
					//dir is reversed!
					case .upside_down:
						if c_idx == 2 && p.dir == .right {
							p.last_orientation = .upside_down
							p.orientation = .rot_left
							p.pos.x = c.x
							p.pos.y = c.y
						} else if c_idx == 3 && p.dir == .left {
							p.last_orientation = .upside_down
							p.orientation = .rot_right
							p.pos.x = platform.pos.x + platform.pos_rect.width
							p.pos.y = c.y
						}
					}
				}
			}
		}
	}

	update_player_colliders()
	//JUMPING
	/*for p in level.platforms {
		if rl.CheckCollisionRecs(p.feet_collider, {p.pos.x, p.pos.y, p.size.x, p.size.y}) &&
		   (p.vel.y > 0) {
			p.vel.y = 0
			p.pos.y = p.pos.y
			p.state = .grounded
			p.action = .nil
		} else if rl.CheckCollisionRecs(
			   p.face_collider,
			   {p.pos.x, p.pos.y, p.size.x, p.size.y},
		   ) &&
		   (p.vel.x != 0) {
			if p.dir == .left {
				p.action = .sliding
				p.state = .not_grounded
				/*if level.player.current_anim.name != .sliding {
					level.player.current_anim = level.player.player_slide
				}*/
				if p.friction_face == .right {
					p.vel.y = sliding_speed * rl.GetFrameTime()
					p.state = .grounded

				}
				p.vel.x = 0
				p.pos.x = p.pos.x + p.size.x + 5
			} else if p.dir == .right {
				p.action = .sliding
				p.state = .not_grounded
				/*if level.player.current_anim.name != .sliding {
					level.player.current_anim = level.player.player_slide
				}*/
				if p.friction_face == .left {
					p.vel.y = sliding_speed * rl.GetFrameTime()
					p.state = .grounded
				}
				p.vel.x = 0
				p.pos.x = p.pos.x - 6
			}
		} else if rl.CheckCollisionRecs(
			   p.head_collider,
			   {p.pos.x, p.pos.y, p.size.x, p.size.y},
		   ) &&
		   (p.vel.y < 0) {
			//fmt.printf("HEAD COLLISION\n")
			p.vel.y = 0
		}
	}*/

	//fmt.printf("Updating player animation %v\n", p.anim.atlas_anim)
	animation_update(&p.anim, dt)

	if p.dir == .left {
		p.flip_x = true
	} else {
		p.flip_x = false
	}

	if p.orientation == .upside_down {
		p.flip_y = true
		if p.dir == .right {
			p.flip_x = true
		} else {
			p.flip_x = false
		}
	} else {
		p.flip_y = false
	}
}

//Ideally this will create a rect that is relative to player pos and current animation
//texture size (width and height)
update_player_colliders :: proc() {
	p := get_player()
	if p == nil {
		fmt.printf("Err - Player pointer nil!\n")
		return
	}
	r := animation_atlas_texture(p.anim).rect
	p_width, p_height: f32
	switch (p.orientation) 
	{
	case .norm:
		p_width = r.width
		p_height = r.height
		if p.movement == .falling {
			p.rect = {p.pos.x - p_width / 2, p.pos.y - p_height + 1.5, p_width, p_height}
		} else {
			p.rect = {p.pos.x - p_width / 2, p.pos.y - p_height + 1, p_width, p_height}
		}
	case .rot_left:
		p_width = r.height
		p_height = r.width
		p.rect = {p.pos.x - p_width + 1, p.pos.y - p_height / 2, p_width, p_height}
	case .rot_right:
		p_width = r.height
		p_height = r.width
		p.rect = {p.pos.x, p.pos.y - p_height / 2 + 1.5, p_width, p_height}
	case .upside_down:
		p_width = r.width
		p_height = r.height
		p.rect = {p.pos.x - p_width / 2, p.pos.y, p_width, p_height}
	}
}

//Rotates the player and it's colliders based on the rotation direction and facing
rotate_player :: proc() {
	p := get_player()
	#partial switch (p.orientation) 
	{
	case .rot_left:
		p.jumping_direction = .left
		if p.dir == .left {
			//Left == facing down
			p.corner_collider = {p.pos.x, p.pos.y - 3, 1, 1}
			p.feet_collider = {p.pos.x, p.pos.y - p.rect.height / 2, 1, 6}
			p.head_collider = {p.rect.x, p.rect.y + (p.rect.height * .5), 1, 4}
			p.face_collider = {p.pos.x - (p.rect.width * .75), p.pos.y + (p.rect.height / 2), 4, 1}
		} else if p.dir == .right {
			//Right = facing up 
			p.corner_collider = {p.pos.x, p.pos.y + 3, 1, 1}
			p.feet_collider = {p.rect.x + p.rect.width - 1, p.rect.y + p.rect.height / 2, 1, 6}
			p.head_collider = {p.rect.x, p.rect.y + (p.rect.height * .5), 1, 4}
			p.face_collider = {p.pos.x - (p.rect.width * .75), p.pos.y + (p.rect.height / 2), 4, 1}
		}

	//hanging on a wall on the left of player
	case .rot_right:
		p.jumping_direction = .right
		if p.dir == .right {
			//Right = facing down 
			p.corner_collider = {p.pos.x, p.pos.y - 3, 1, 1}
			//p.corner_collider = {p.pos.x + 4, p.pos.y - 2, 4, 4}
			p.feet_collider = {p.pos.x, p.pos.y - p.rect.height / 2, 1, 6}
		} else if p.dir == .left {
			//Left == facing up
			p.corner_collider = {p.pos.x, p.pos.y + 3, 1, 1}
			p.feet_collider = {p.pos.x, p.pos.y, 1, 6}
		}
	case .upside_down:
		p.jumping_direction = .down
		if p.dir == .left {
			//Right = facing down 
			p.corner_collider = {p.pos.x - 3, p.pos.y, 1, 1}
			//p.corner_collider = {p.pos.x + 4, p.pos.y - 2, 4, 4}
			p.feet_collider = {p.pos.x - p.rect.width / 2, p.pos.y, 6, 1}
		} else if p.dir == .right {
			//Left == facing up
			p.corner_collider = {p.pos.x + 3, p.pos.y, 1, 1}
			p.feet_collider = {p.pos.x, p.pos.y, 5, 1}
		}
	}
}

/*player_attack :: proc(mp: Vec2) {
	p := get_player()
	if (p == nil) {
		fmt.printf("ERR - player pointer is nil!\n")
		return
	}

	fmt.printf("PLAYER_ATTACK\n")
	//Center of player
	//length of tongue in pixels?
	attack_length := i32(10)

	dest := calc_point(mp, player_center(), attack_length)
	p.tongue.pos = dest
	fmt.printf("MP pos: %.2f, %.2f\n", mp.x, mp.y)
	fmt.printf("Tongue pos: %.2f, %.2f\n", dest.x, dest.y)
	p.tongue.fired = true
}*/

//always draws the player using the player_handle
draw_player :: proc(fade: f32) {
	p := get_player()
	// Fetch the texture for the current frame of the animation.
	anim_texture := animation_atlas_texture(p.anim)
	// The region inside atlas.png where this animation frame lives
	atlas_rect := anim_texture.rect
	// The texture has four offset fields: offset_top, right, bottom and left. The offsets records
	// the distance between the pixels in the atlas and the edge of the original document in the
	// image editing software. Since the atlas is tightly packed, any empty pixels are removed.
	// These offsets can be used to correct for that removal.
	//
	// This can be especially obvious in animations where different frames can have different
	// amounts of empty pixels around it. By adding the offsets everything will look OK.
	//
	// Note that when when flip_x is true we need to add the offset_right instead of the offset_left.
	offset := Vec2{anim_texture.offset_left, anim_texture.offset_top}

	// Flip player when walking to the left. This means both flipping the atlas_rect width, but also
	// using the right offset instead of the left one.
	if p.flip_x {
		atlas_rect.width = -atlas_rect.width
		offset.x = anim_texture.offset_right
	}
	if p.flip_y {
		atlas_rect.height = -atlas_rect.height
		offset.y = anim_texture.offset_bottom
	}
	// The dest rectangle tells us where on screen to draw the player.
	dest := Rect {
		p.pos.x + offset.x,
		p.pos.y + offset.y,
		anim_texture.rect.width,
		anim_texture.rect.height,
	}

	rotation: f32
	switch (p.orientation) 
	{
	case .norm:
		if p.movement == .falling {
			if p.dir == .right {
				dest.x -= 1
			} else {
				dest.x += 2
			}
		}
	case .rot_left:
		rotation = 270
		dest.x += (anim_texture.rect.width * .5) + 2
		dest.y -= (anim_texture.rect.width) + 2
	case .rot_right:
		rotation = 90
		dest.x -= (anim_texture.rect.width) + 2
		dest.y -= (anim_texture.rect.width * .5)
	case .upside_down:
		dest.y += (anim_texture.rect.height) * 2 + 3
		dest.x -= 1
	}

	// I want origin of player to be at the feet.
	// Use document_size for origin instead of anim_texture.rect.width (and height), because those
	// may vary from frame to frame due to being tightly packed in atlas.
	origin := Vec2 {
		anim_texture.document_size.x / 2,
		anim_texture.document_size.y - 1, // -1 because there's an outline in the player anim that takes an extra pixel
	}

	// Draw texture. Note how we are drawing using the atlas but choosing a specific region in it
	// using atlas_rect.
	/*if p.tongue.fired {
		rl.DrawLineEx(player_center(), g.player.tongue.pos, 1, rl.PINK)
		//rl.DrawRectangle(i32(g.player.tongue.pos.x), i32(g.player.tongue.pos.y), 1, 1, rl.RED)
	}*/

	rl.DrawTexturePro(atlas, atlas_rect, dest, origin, rotation, rl.Fade(rl.WHITE, fade))

	//DEBUG
	if DEBUG_DRAW {draw_player_debug()}
	if DEBUG_DRAW_COLLIDERS {draw_player_colliders()}
}

draw_player_debug :: proc() {
	p := get_player()
	font_size := f32(10)
	rl.DrawRectangleLines(
		i32(p.rect.x),
		i32(p.rect.y),
		i32(p.rect.width),
		i32(p.rect.height),
		rl.BLUE,
	)
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("%.2f, %.2f", p.pos.x, p.pos.y),
		{p.pos.x, p.pos.y + 5},
		4,
		2,
		rl.RED,
	)
	text_pos := rl.GetScreenToWorld2D({0, 0}, game_camera())
	col_2 :=
		rl.MeasureText(rl.TextFormat("Player Grounded?: %v", p.is_on_ground), i32(font_size)) + 10
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Player Grounded: %v", p.is_on_ground),
		{text_pos.x + 2, text_pos.y + 2},
		font_size,
		.5,
		rl.RED,
	)
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Player Pos: %.2f,%.2f", p.pos.x, p.pos.y),
		{text_pos.x + 2 + f32(col_2), text_pos.y + 2},
		font_size,
		.5,
		rl.RED,
	)
	pad := 1
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Player Movement: %s", p.movement),
		{text_pos.x + 2, text_pos.y + f32(pad) + f32(font_size)},
		font_size,
		.5,
		rl.RED,
	)
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Player Input: %v", p.input),
		{text_pos.x + 2 + f32(col_2), text_pos.y + f32(pad) + f32(font_size)},
		font_size,
		.5,
		rl.RED,
	)
	pad += 6
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Player Direction: %s", p.dir),
		{text_pos.x + 2, text_pos.y + f32(pad) + f32(font_size)},
		font_size,
		.5,
		rl.RED,
	)
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Player Flip_x: %v", p.flip_x),
		{text_pos.x + 2 + f32(col_2), text_pos.y + f32(pad) + f32(font_size)},
		font_size,
		.5,
		rl.RED,
	)
	pad += 6
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Player Orientation: %s", p.orientation),
		{text_pos.x + 2, text_pos.y + f32(pad) + f32(font_size)},
		font_size,
		.5,
		rl.RED,
	)
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Player Climbing: %v", p.wall_climbing),
		{text_pos.x + 2 + f32(col_2), text_pos.y + f32(pad) + f32(font_size)},
		font_size,
		.5,
		rl.RED,
	)
	pad += 6
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Player Animation: %v", p.anim.atlas_anim),
		{text_pos.x + 2, text_pos.y + f32(pad) + f32(font_size)},
		font_size,
		.5,
		rl.RED,
	)
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Atlas size: %v,%v", g.atlas.width, g.atlas.height),
		{text_pos.x + 2 + f32(col_2), text_pos.y + f32(pad) + f32(font_size)},
		font_size,
		.5,
		rl.RED,
	)
	pad += 6
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Player Animation Frame?: %v", p.anim.current_frame),
		{text_pos.x + 2, text_pos.y + f32(pad) + f32(font_size)},
		font_size,
		.5,
		rl.RED,
	)
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Fullscreen?: %v", rl.GetWindowHandle()),
		{text_pos.x + 2 + f32(col_2), text_pos.y + f32(pad) + f32(font_size)},
		font_size,
		.5,
		rl.RED,
	)
	pad += 6
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Side Jump: %v", p.side_jump),
		{text_pos.x + 2, text_pos.y + f32(pad) + f32(font_size)},
		font_size,
		.5,
		rl.RED,
	)


}

draw_player_colliders :: proc() {

	p := get_player()
	rl.DrawRectangleLines(
		i32(p.rect.x),
		i32(p.rect.y),
		i32(p.rect.width),
		i32(p.rect.height),
		rl.BLUE,
	)
	rl.DrawRectangleRec(p.feet_collider, rl.YELLOW)
	rl.DrawRectangleRec(p.face_collider, rl.ORANGE)
	rl.DrawRectangleRec(p.head_collider, rl.RED)
	rl.DrawRectangleLinesEx(p.corner_collider, .25, rl.PINK)
	rl.DrawPixelV(p.pos, rl.PURPLE)
}
