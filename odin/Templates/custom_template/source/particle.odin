package game

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

MAX_PARTICLES :: 400

Particle :: struct {
	position: Vec2,
	velocity: Vec2,
	life:     f32,
	max_life: f32,
	color:    rl.Color,
	size:     f32,
	active:   bool,
	type:     Particle_Type,
}

Particle_Type :: enum {
	jump, // Jump dust
	land, // Landing burst
	attack, // Attack impact
	trail, // Trail effect 
}

Particle_System :: struct {
	particles:    [MAX_PARTICLES]Particle,
	active_count: int,
}

// Initialize the particle system
init_particle_system :: proc() -> Particle_System {
	ps: Particle_System
	ps.active_count = 0

	// Initialize all particles as inactive
	for i in 0 ..< MAX_PARTICLES {
		ps.particles[i].active = false
	}

	return ps
}

// Find an inactive particle to reuse
find_inactive_particle :: proc(ps: ^Particle_System) -> int {
	for i in 0 ..< MAX_PARTICLES {
		if !ps.particles[i].active {
			return i
		}
	}
	return -1 // No inactive particle found
}

// Create jump particles (dust going downward)
create_jump_effect :: proc(ps: ^Particle_System, player_pos: rl.Vector2) {
	for i := 0; i < 8; i += 1 {
		index := find_inactive_particle(ps)
		if index == -1 do continue

		p := &ps.particles[index]
		p.active = true
		p.position = {
			player_pos.x + f32(rand.int31() % 20 - 10), // Random spread around player
			player_pos.y, // At player's feet
		}
		p.velocity = {
			f32(rand.int31() % 40 - 20) * 0.1, // Small horizontal spread
			f32(rand.int31() % 20 + 10) * 0.5, // Downward velocity
		}
		p.life = 0.6 + f32(rand.int31() % 20) * 0.01 // 0.6-0.8 seconds
		p.max_life = p.life
		p.color = rl.GRAY // Brown dust color
		p.size = 2.0 + f32(rand.int31() % 3)
		ps.active_count += 1
	}
}

// Create landing particles (burst outward)
create_landing_effect :: proc(ps: ^Particle_System, player_pos: rl.Vector2) {
	for i := 1; i < 12; i += 1 {
		index := find_inactive_particle(ps)
		if index == -1 do continue

		p := &ps.particles[index]
		p.active = true
		p.position = {player_pos.x + f32(rand.int31() % 16 - 8), player_pos.y}

		// Create outward burst pattern
		angle := f32(rand.int31() % 360) * math.RAD_PER_DEG
		speed := 30.0 + f32(rand.int31() % 40)
		p.velocity = {
			math.cos(angle) * speed,
			math.sin(angle) * speed - 20.0, // Slightly upward bias
		}

		p.life = 0.8 + f32(rand.int31() % 30) * 0.01
		p.max_life = p.life
		p.color = rl.GRAY // Sandy brown
		p.size = 3.0 + f32(rand.int31() % 3)
		ps.active_count += 1
	}
}

// Create attack particles (directional burst)
create_attack_effect :: proc(ps: ^Particle_System, attack_pos: rl.Vector2, dir: Entity_Direction) {
	for i := 0; i < 6; i += 1 {
		index := find_inactive_particle(ps)
		if index == -1 do continue

		p := &ps.particles[index]
		p.active = true
		p.position = attack_pos
		direction := Vec2{0, 0}
		// Determine direction based on attack direction
		if dir == .left {
			direction = Vec2{-1, 0} // Left
		} else {
			direction = Vec2{1, 0} // Right
		}
		// Create particles in attack direction with some spread
		base_angle := math.atan2(direction.y, direction.x)
		spread := f32(rand.int31() % 60 - 30) * math.RAD_PER_DEG // ±30 degree spread
		angle := base_angle + spread
		speed := 50.0 + f32(rand.int31() % 30)

		p.velocity = {math.cos(angle) * speed, math.sin(angle) * speed}

		p.life = 0.4 + f32(rand.int31() % 20) * 0.01
		p.max_life = p.life
		p.color = rl.GOLD // Golden color for impact
		p.size = 2.0 + f32(rand.int31() % 2)
		ps.active_count += 1
	}
}

create_trail_effect :: proc(ps: ^Particle_System, player_pos: rl.Vector2, player_vel: Vec2) {
	// Create a trail effect behind the player
	index := find_inactive_particle(ps)
	if index == -1 do return

	p := &ps.particles[index]
	p.active = true
	p.position = player_pos
	//p.velocity = {player_vel.x * 0.5, player_vel.y * 0.5} // Half the player's velocity
	p.life = 0.5 + f32(rand.int31() % 20) * 0.01 // 0.5-0.7 seconds
	p.max_life = p.life
	p.color = get_random_colour() // Light gray for trail
	p.size = 1.5 + f32(rand.int31() % 2)
	ps.active_count += 1
}

// Update all particles
update_particle_system :: proc(ps: ^Particle_System, delta_time: f32) {
	for i in 0 ..< MAX_PARTICLES {
		if !ps.particles[i].active do continue

		p := &ps.particles[i]

		// Update position
		p.position.x += p.velocity.x * delta_time
		p.position.y += p.velocity.y * delta_time

		// Apply gravity
		p.velocity.y += 200.0 * delta_time

		// Apply air resistance
		p.velocity.x *= 0.98
		p.velocity.y *= 0.99

		// Update life
		p.life -= delta_time

		// Fade out color based on remaining life
		life_factor := p.life / p.max_life
		p.color.a = u8(255 * life_factor)

		// Shrink particle over time
		p.size = (2.0 + f32(rand.int31() % 3)) * life_factor

		// Deactivate if life is over
		if p.life <= 0 {
			p.active = false
			ps.active_count -= 1
		}
	}
}

// Draw all active particles
draw_particle_system :: proc(ps: ^Particle_System, fade: f32) {
	for i in 0 ..< MAX_PARTICLES {
		if !ps.particles[i].active do continue

		p := &ps.particles[i]
		rl.DrawCircleV(p.position, p.size, p.color)
	}
}
