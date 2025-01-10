#include "PauseState.h"
#include "Game.h"
#include "Button.h"

bool PauseState::Init()
{

	if(game->getPaused() == false)
	{
		SDL_Log("PauseState::Init() - Initializing");
		LoadMedia();
		int x, y = 0;
		int pad = 60;

		x = graphics->GetWidth() / 2 - (200 / 2);
		y = graphics->GetHeight() / 2 - (graphics->GetHeight() / 3);

		//Create a menu object. 
		buttons.push_back(new Button(textures["button"], graphics->GetTextFromString("Resume"), "Resume", x, y));
		y += pad;
		buttons.push_back(new Button(textures["button"], graphics->GetTextFromString("Options"), "Options",x,y));
		y += pad;
		buttons.push_back(new Button(textures["button"], graphics->GetTextFromString("Main Menu"), "Main Menu",x,y));
		y += pad;
		buttons.push_back(new Button(textures["button"], graphics->GetTextFromString("Quit"), "Quit",x,y));
		
	}
	else
	{
		AdjustElements();
	}
	return true;
}

void PauseState::Cleanup() { SDL_Log("PauseState::Cleanup()"); }

void PauseState::Pause() { SDL_Log("PauseState::Pause()"); }

void PauseState::Resume() {	SDL_Log("PlayState::Resume()"); }

void PauseState::LoadMedia()
{
	SDL_Log("PauseState::LoadMedia()");
	textures["pause"] = resource->LoadTexture("pause.png");
	textures["button"] = resource->LoadTexture("button.png");
}

void PauseState::HandleEvents(SDL_Event e)
{
	switch (e.type)
	{
		case SDL_MOUSEMOTION:
		{
			for (auto& it : buttons)
			{
				it->HandleEvent(e);
			}
			break;
		}
		case SDL_QUIT:
		{
			game->Quit();
			break;
		}
		//Handle Keyboard inputs during intro screen
		case SDL_KEYDOWN:
		{
			KeyPress(e.key);
			break;
		}
		//Handle Mouse button inputs during intro screen
		case SDL_MOUSEBUTTONDOWN:
		{
			MousePress(e.button);
			break;
		}
		case SDL_WINDOWEVENT:
		{	
			switch (e.window.event)
			{
				case SDL_WINDOWEVENT_RESIZED:
				{
					SDL_Log("ADJUSTING ELEMENTS");
					AdjustElements();
				}
			}
		}
	}
}

void PauseState::KeyPress(SDL_KeyboardEvent k)
{
	//SDL_Log("PauseState::KeyPress");
	switch (k.type)
	{
		case SDL_KEYDOWN:
		{
			//Make sure you can unpause :)
			if (k.keysym.sym == SDLK_ESCAPE)
			{
				game->Resume();
			}
			break;
		}
		case SDL_KEYUP:
		{
			break;
		}

	}
}

void PauseState::AdjustElements()
{
	SDL_Log("AdjustElements()");
	int x, y = 0;
	int pad = 60;
	x = graphics->GetWidth() / 2 - (200 / 2);
	y = graphics->GetHeight() / 2 - (graphics->GetHeight() / 3);

	printf("Graphics -> getWidth(): %i\n", graphics->GetWidth());
	printf("Graphics -> getHeight(): %i\n", graphics->GetHeight());
	for (auto& it : buttons)
	{
		it->SetPos(x, y);
		y += 60;
	}
	Draw();
}

void PauseState::MousePress(SDL_MouseButtonEvent& e)
{
	switch (e.button)
	{
		case 1:
		{
			for (auto& it : buttons)
			{
				if (it->GetMouseOver())
				{
					if (it->GetLabel() == "Resume")
					{
						game->Resume();
					}
					if (it->GetLabel() == "Options")
					{
						SDL_Log("Display Options (State?) ");
					}
					if (it->GetLabel() == "Main Menu")
					{
						game->QuitToMenu();
					}
					if (it->GetLabel() == "Quit")
					{
						game->Quit();
					}
				}
			}
			break;
		}
		default:
		{
			//SDL_Log("MenuState::HandleEvents() - MOUSE BUTTON DOWN - DEFAULT");
			break;
		}
	}
}

void PauseState::ChangeState()
{
	
}

void PauseState::Update()
{

}

void PauseState::Draw()
{
	graphics->Clear();
	//SDL_Rect r;
	for (auto& it : buttons)
	{
		//r = it->GetPos();
		graphics->Draw(it);
	}
}

