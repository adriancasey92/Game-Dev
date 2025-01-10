#include "Player.h"

void Player::Init()
{
	SDL_Log("Player::Init()");
	SDL_QueryTexture(texture, NULL, NULL, &w, &h);
	printf("Size:\nW: %i\nH: %i", w, h);
}

void Player::Update()
{
	Move();
}

void Player::HandleEvent(SDL_Event& e)
{
	//SDL_Log("Player::HandleEvent()");
	if (e.type == SDL_KEYDOWN && e.key.repeat == 0)
	{
		
		//Print();
		switch (e.key.keysym.sym)
		{
			case SDLK_UP: vy -= VEL; break;
			case SDLK_DOWN: vy += VEL; break;
			case SDLK_LEFT: vx -= VEL; break;
			case SDLK_RIGHT: vx += VEL; break;
			case SDLK_w: break;//graphics->Print();
		}
	}
	else if (e.type == SDL_KEYUP && e.key.repeat == 0)
	{
		//Adjust the velocity
		switch (e.key.keysym.sym)
		{
			case SDLK_UP: vy += VEL; break;
			case SDLK_DOWN: vy-= VEL; break;
			case SDLK_LEFT: vx+= VEL; break;
			case SDLK_RIGHT: vx-= VEL; break;
		}
	}
}

void Player::Move()
{
	//SDL_Log("Player::Move() - Moving player");
	x += vx;

	//If the dot went too far to the left or right
	if (x < (0))
		x = 0 ;

	if ((x + w) > graphics->GetWidth())
		x = graphics->GetWidth() - (w);
	

	y += vy;


	if (y <(0))
		y = 0;
	//If the dot went too far up or down
	if ((y + h) > graphics->GetHeight())
		y = graphics->GetHeight() - (h);
}

void Player::Print() const
{
	SDL_Log("Player::Print()");
	printf("X: %i\nY: %i\nvX: %i\nvY: %i\n", x, y, vx, vy);

}


