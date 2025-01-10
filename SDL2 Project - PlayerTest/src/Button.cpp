#include "Button.h"

Button::Button(SDL_Texture* tx,SDL_Texture* fontTex, std::string l, int x, int y)
{
	SDL_Log("Button::Button() - Constructor called.");
	texture = tx;
	label = l;
	bPos.w = 200 , bPos.h = 50;
	bPos.x = x, bPos.y = y;
	mouseOver = false;
	clips[0] = { 0, 0, bPos.w, bPos.h };
	clips[1] = { 0, bPos.h, bPos.w, bPos.h };
}

void Button::HandleEvent(SDL_Event& e)
{
	//SDL_Log("Button::HandleEvent()");

	switch (e.type)
	{
		case SDL_MOUSEMOTION:
		{
			CheckMouseOver();
			if (mouseOver)
				OnMouseOver();
		}
	}
}

void Button::CheckMouseOver()
{
	//SDL_Log("Button::CheckMouseOver()- BEGIN");
	int x, y;
	SDL_GetMouseState(&x, &y);

	
	//Check Bounds
	if ((x >= bPos.x && x <= bPos.x + bPos.w) && ((y >= bPos.y && y <= bPos.y + bPos.h)))
		mouseOver = true;
	else
		mouseOver = false;
	//SDL_Log("Button::CheckMouseOver() - END");
}

void Button::OnMouseOver()
{
	//printf("Button coords.\nx: %i\ny:%i\n", bPos.x, bPos.y);
}

void Button::DrawButtons()
{
	
}

SDL_Rect Button::GetClips()
{
	if (mouseOver)
		return clips[1];
	else
		return clips[0];
}
