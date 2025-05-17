#+feature dynamic-literals
package main

import "core:fmt"
import "core:math"
import "core:slice"
import "core:sort"
import "core:strings"
import rl "vendor:raylib"

//Declare types
Vec3 :: rl.Vector3
Vec2 :: rl.Vector2


//Window Constants
WIDTH :: 1280
HEIGHT :: 600
WINDOW_NAME :: "Space Invaders"
CENTER :: Vec2{WIDTH / 2, HEIGHT / 2}
BACKGROUND_COL: rl.Color
PAUSE: bool
gameOver: bool
//Cameras
camera2D: rl.Camera2D
camera3D: rl.Camera3D
playerWidth :: 25
playerHeight :: 40
playerSpeed :: 150

//Sprint 
playerSprint: bool
sprintCharging: bool
sprintTime: f32
sprintMult :: 1.8
totalSprintTime :: 2.5

//Player bullet
playerCanFire: bool
playerFireDelayTimer: f32
playerFireDelay :: .7
playerLife: i32

bullet: Entity
bulletSize :: 10
bulletSpeed :: 350
bulletSpeedMult :: 1.2

Direction :: enum {
	UP,
	DOWN,
	LEFT,
	RIGHT,
}

totalEnemyMoves: i32
enemyMoveTimer: f32
enemyMoveDelay: f32
enemyMovesHoriz: i32
enemyMovedDown: bool
enemyMovesVert: i32
enemyDirection: Direction
enemyNextHorizontal: Direction
enemyLastVertical: Direction

//Spacing stuff
enemiesPerRow :: 6
enemiesPerCol :: 4
enemyWidth :: 50
enemyHeight :: 20

enemySpacingWide :: WIDTH / enemiesPerRow
enemySpacingHigh :: (HEIGHT / 2) / enemiesPerCol

Player: Entity
Bullets: [dynamic]Entity
Enemies: [dynamic]Entity

//Dummy struct
Entity :: struct {
	pos:     Vec2,
	size:    Vec2,
	vel:     Vec2,
	type:    string,
	visible: bool,
}

//Random function
random_uniform :: proc(min, max: f32) -> f32 {
	return min + (max - min) * f32(rl.GetRandomValue(0, 10000)) / 10000.0
}

//Random range function
randrange :: proc(max: i32) -> i32 {
	return rl.GetRandomValue(0, max - 1)
}

//Init camera functions
init_camera2D :: proc() {
	camera2D = {{0, 0}, {0.0, 0.0}, 0, 0}
	//rl.DisableCursor()
}
init_camera3D :: proc(cam: rl.Camera) {
	//camera3D = {{15, 15, -Z_DIST}, {0.0, 0.0, 0.0}, {0.0, 1.0, 0.0}, 60.0, .PERSPECTIVE}
	//rl.DisableCursor()
}

init_program :: proc() {
	fmt.printf("Init program:\n")
	//Default backgroundcolor
	BACKGROUND_COL = rl.BLACK
	sprintCharging = false
	playerCanFire = true
	playerLife = 3
	enemyMovesHoriz = 0
	enemyMovesVert = 0
	enemyDirection = .LEFT
	enemyMoveDelay = 0.5
	enemyMoveTimer = 0

	Player = Entity {
		{CENTER.x, HEIGHT - playerHeight * 3},
		{playerWidth, playerHeight},
		{0, 0},
		"player",
		true,
	}
	bullet = Entity{CENTER, {bulletSize, bulletSize}, {0, 0}, "bullet", false}
	append(&Bullets, bullet)
	create_enemies()
}

end_game :: proc() {
	clear(&Bullets)
	clear(&Enemies)
}

move_player :: proc() {
	if playerSprint {
		Player.pos += Player.vel * (playerSpeed * sprintMult) * rl.GetFrameTime()
	} else {
		Player.pos += Player.vel * playerSpeed * rl.GetFrameTime()
	}
}

create_enemies :: proc() {
	xoffset := (enemySpacingWide / 2) - enemyWidth / 2
	yoffset := 25

	for y := 0; y < enemiesPerCol; y += 1 {
		for x := 0; x < enemiesPerRow; x += 1 {
			append(
				&Enemies,
				Entity {
					pos = {
						f32(x * enemySpacingWide) + f32(xoffset),
						f32(y * enemySpacingHigh) + f32(yoffset),
					},
					size = {enemyWidth, enemyHeight},
					type = "enemy",
					vel = {},
					visible = true,
				},
			)
		}
	}
}

fire_missile :: proc(e: Entity) {
	//fmt.printf("FIRING MUH LAZOR\n")
	fmt.printf("fire_missile : e.type: %s\n", e.type)
	switch (e.type) 
	{
	case "player":
		fmt.printf("PLAYER BULLET")
		b := Bullets[0]
		b.pos = e.pos
		b.pos.y += 10
		b.vel = {0, -1}
		b.type = "player_bullet"
		b.visible = true

		//add bullet
		append(&Bullets, b)

	case "enemy":
		b := Bullets[0]
		b.pos = e.pos
		b.pos.y -= enemyHeight
		b.vel = {0, 1}
		b.type = "enemy_bullet"
		b.visible = true
		append(&Bullets, b)
	}
}

destroy_missiles :: proc(index: [dynamic]int) {
	for i in index {
		ordered_remove(&Bullets, i)
	}
}

move_missiles :: proc() {
	//update bullets
	for &b, idx in Bullets {
		if b.type == "player_bullet" {
			//fmt.printf("Updating player_missile %i\n", idx)
			if b.visible {
				b.pos += b.vel * (bulletSpeedMult * bulletSpeed) * rl.GetFrameTime()
			}
		} else if b.type == "enemy_bullet" {
			if b.visible {
				b.pos += b.vel * bulletSpeed * rl.GetFrameTime()
			}
		}
	}
}

destroy_enemy :: proc(index: [dynamic]int) {
	for i in index {
		ordered_remove(&Enemies, i)
	}
}

move_enemy :: proc() {
	//update enemy movement
	enemyMoveTimer += rl.GetFrameTime()
	fmt.printf("EnemyDir: %s\n", enemyDirection)
	if enemyMoveTimer >= enemyMoveDelay {
		for &e, idx in Enemies {
			//Move based on enemyDirection
			#partial switch (enemyDirection) 
			{
			case .DOWN:
				e.pos.y = e.pos.y + e.size.y * 1.2
			case .RIGHT:
				e.pos.x = e.pos.x + e.size.x / 3
			case .LEFT:
				e.pos.x = e.pos.x - e.size.x / 3
			}
		}
		if enemyDirection == .DOWN {
			enemyMovedDown = true
		}
		for &e, idx in Enemies {
			// if an enemy touches the right wall
			if enemyDirection == .RIGHT && (e.pos.x + (enemyWidth * 2) >= WIDTH) {
				enemyDirection = .DOWN
				enemyNextHorizontal = .LEFT
				break
			}

			if enemyDirection == .LEFT && (e.pos.x - enemyWidth <= 0) {
				fmt.printf("BOUND DETECTED LEFT\n")
				enemyDirection = .DOWN
				enemyNextHorizontal = .RIGHT
				break
			}
		}
		if enemyMovedDown {
			enemyDirection = enemyNextHorizontal
			enemyMovedDown = false
		}
		enemyMoveTimer = 0
		totalEnemyMoves += 1

		if totalEnemyMoves % 10 == 0 {
			if totalEnemyMoves <= 50 {
				enemyMoveDelay = enemyMoveDelay * .95
			}
		}

	}
}

enemy_fire :: proc() {
	for e in Enemies {
		chance := randrange(750)
		if chance == 10 {
			fire_missile(e)
		}
	}
}

main :: proc() {
	defer delete(Bullets)
	defer delete(Enemies)

	//Set to square
	rl.InitWindow(WIDTH, HEIGHT, WINDOW_NAME)
	if !rl.IsWindowReady() {
		fmt.printf("ERR: Window not ready?\n")
		return
	}
	//Set FPS
	rl.SetTargetFPS(60)
	//Init camera 2D/3D
	init_camera2D()
	//init_camera3D()

	//init program
	init_program()

	//Program loop
	for !rl.WindowShouldClose() {
		update()
		draw()
		free_all(context.temp_allocator)
	}
}

update :: proc() {

	if playerLife == 0 {
		gameOver = true
	}


	Player.vel.x = 0

	if !PAUSE {

		if gameOver == false {
			handle_input()
			move_player()
			move_enemy()
			enemy_fire()
			move_missiles()
			checkCollisions()
		} else {
			handle_input()
		}


	}


	//Make sure we can pause/unpause
	if rl.IsKeyPressed(.P) {
		PAUSE = !PAUSE
	}
}

handle_input :: proc() {
	//Reset player velocity
	if gameOver == false {
		if rl.IsKeyPressed(.W) {

		}

		if rl.IsKeyPressed(.S) {
			fmt.printf("Num bullets: %i\n", len(Bullets))
		}

		if rl.IsKeyDown(.A) {
			Player.vel = {-1, 0}
		}

		if rl.IsKeyDown(.D) {
			Player.vel = {1, 0}
		}

		//Recharge sprint
		if sprintCharging {
			sprintTime -= rl.GetFrameTime()
			if sprintTime <= 0 {
				sprintCharging = !sprintCharging
			}
		}

		//Delay fire by about 1.5 seconds
		if !playerCanFire {
			playerFireDelayTimer += rl.GetFrameTime()
			if playerFireDelayTimer == playerFireDelay {
				playerFireDelayTimer = 0
				playerCanFire = true
			}
		}

		if rl.IsKeyDown(.LEFT_SHIFT) {
			//3 seconds of sprint time
			//if we hit our allotted time of sprinting, make player wait 3 seconds before sprinting again
			if !sprintCharging {
				sprintTime += rl.GetFrameTime()
				if sprintTime < totalSprintTime {
					playerSprint = true
				} else {
					sprintCharging = true
					playerSprint = false
				}
			}
		} else {
			playerSprint = false
		}

		if rl.IsKeyDown(.SPACE) {
			//fmt.printf("Fire Delay timer: %f\n", playerFireDelayTimer)
			if !playerCanFire {
				if playerFireDelayTimer >= playerFireDelay {
					playerCanFire = true
					playerFireDelayTimer = 0
				}
			}

			//if they can fire, then fire. Set playercanfire to false
			if playerCanFire {
				fmt.printf("Firing player missile")
				fire_missile(Player)
				playerCanFire = false
			}
		}
		if rl.IsKeyReleased(.LEFT_SHIFT) {

		}
		if rl.IsMouseButtonPressed(.LEFT) {

		}
		if rl.IsMouseButtonPressed(.RIGHT) {

		}
	} else {
		if rl.IsKeyPressed(.SPACE) {
			end_game()
			init_program()
			gameOver = false
		}
	}
}


checkCollisions :: proc() {
	//Make sure to remove bullets that go off screen
	bIndex: [dynamic]int
	eIndex: [dynamic]int
	defer delete(eIndex)
	defer delete(bIndex)

	//Loop over every bullet and check collisions
	for &b, idx1 in Bullets {
		if b.type == "player_bullet" {
			fmt.printf("Player bullet collsion check\n")
			if b.pos.y <= 0 {
				append(&bIndex, idx1)
			}
			for &e, idx2 in Enemies {
				//see if a bullet collides?
				if rl.CheckCollisionRecs(
					{b.pos.x, b.pos.y, b.size.x, b.size.y},
					{e.pos.x, e.pos.y, e.size.x, e.size.y},
				) {
					append(&eIndex, idx2)
					append(&bIndex, idx1)
				}
			}
		} else if b.type == "enemy_bullet" {
			fmt.printf("Enemy bullet collsion check\n")
			if b.pos.y > HEIGHT {
				append(&bIndex, idx1)
			}

			if rl.CheckCollisionRecs(
				{b.pos.x, b.pos.y, b.size.x, b.size.y},
				{Player.pos.x, Player.pos.y, Player.size.x, Player.size.y},
			) {
				append(&bIndex, idx1)
				playerLife -= 1
			}
		}
	}

	// if enemy collides with player
	for &e, idx3 in Enemies {
		if rl.CheckCollisionRecs(
			{Player.pos.x, Player.pos.y, Player.size.x, Player.size.y},
			{e.pos.x, e.pos.y, e.size.x, e.size.y},
		) {
			append(&eIndex, idx3)
			playerLife -= 1
		}
	}

	if len(bIndex) > 0 {
		destroy_missiles(bIndex)
	}

	if len(eIndex) > 0 {
		destroy_enemy(eIndex)
	}
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(BACKGROUND_COL)

	//Draw player life
	for i := 0; i < int(playerLife); i += 1 {
		rl.DrawRectangle(i32(i * 40) + 25, HEIGHT - 50, 25, 25, rl.RED)
	}
	//Draw Player
	rl.DrawRectangleV(Player.pos, Player.size, rl.WHITE)
	//Sprint bar
	if sprintCharging {
		rl.DrawRectangle(
			i32(Player.pos.x),
			i32(Player.pos.y + Player.size.y + 2),
			i32(Player.size.x - (sprintTime / totalSprintTime) * Player.size.x),
			5,
			rl.RED,
		)
	} else {
		rl.DrawRectangle(
			i32(Player.pos.x),
			i32(Player.pos.y + Player.size.y + 2),
			i32(Player.size.x),
			5,
			rl.GREEN,
		)
	}

	//Draw enemies
	for e in Enemies {
		rl.DrawRectangleV(e.pos, e.size, rl.ORANGE)
		rl.DrawRectangleLines(i32(e.pos.x), i32(e.pos.y), i32(e.size.x), i32(e.size.y), rl.BLUE)
		/*switch (e.type) 
		{
		case "enemy":

		}*/
	}

	for b in Bullets {
		switch (b.type) 
		{
		case "player_bullet":
			rl.DrawRectangleV(b.pos, b.size, rl.ORANGE)
			rl.DrawRectangleLines(
				i32(b.pos.x),
				i32(b.pos.y),
				i32(b.size.x),
				i32(b.size.y),
				rl.BLUE,
			)
		case "enemy_bullet":
			rl.DrawRectangleV(b.pos, b.size, rl.ORANGE)
			rl.DrawRectangleLines(
				i32(b.pos.x),
				i32(b.pos.y),
				i32(b.size.x),
				i32(b.size.y),
				rl.BLUE,
			)
		}
	}
	//rl.EndMode2D()
	rl.EndDrawing()
}
