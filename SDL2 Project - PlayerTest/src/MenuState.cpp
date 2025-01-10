#include "MenuState.h"
#include "Game.h"
#include "Button.h"


const std::string resourcePath = "resource/";

bool MenuState::Init()
{
	SDL_Log("MenuState::Init() - Initializing");
	LoadMedia();

	int x, y = 0;
	int pad = 60;

	x = graphics->GetWidth() / 2 - (200 / 2);
	y = graphics->GetHeight() / 2 - (graphics->GetHeight() / 3);

	//Create a menu object. 
	buttons.push_back(new Button(textures["button"], graphics->GetTextFromString("Start"), "Start", x, y));
	y += pad;
	buttons.push_back(new Button(textures["button"], graphics->GetTextFromString("Options"), "Options", x, y));
	y += pad;	
	buttons.push_back(new Button(textures["button"], graphics->GetTextFromString("Quit"), "Quit", x, y));
	return true;
}

void MenuState::Cleanup() { SDL_Log("MenuState::Cleanup()"); }

void MenuState::Pause() { SDL_Log("MenuState::Pause()"); }

void MenuState::Resume() { SDL_Log("MenuState::Resume()"); }

void MenuState::LoadMedia() 
{ 
	SDL_Log("MenuState::LoadMedia()"); 
	textures["menu"] = resource->LoadTexture("menu.png");
	textures["button"] = resource->LoadTexture("button.png");
}

void MenuState::HandleEvents(SDL_Event e)
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

void MenuState::KeyPress(SDL_KeyboardEvent& k)
{
	//SDL_Log("IntroState::HandleEvents() - KEYDOWN");
	switch (k.keysym.sym)
	{
		case SDLK_UP:
		{
			SDL_Log("MenuState::HandleEvents() - Key Up");
			break;
		}
		case SDLK_DOWN:
		{
			SDL_Log("MenuState::HandleEvents() - Key Down");
			break;
		}
		case SDLK_LEFT:
		{
			SDL_Log("MenuState::HandleEvents() - Key Left");
			break;
		}
		case SDLK_RIGHT:
		{
			SDL_Log("MenuState::HandleEvents() - Key Right");
			break;
		}
		case SDLK_ESCAPE:
		{
			SDL_Log("MenuState::HandleEvents() - Escape pressed.");
			//game->Pause();
			break;
		}
		case SDLK_RETURN:
		{
			SDL_Log("MenuState::HandleEvents() - Enter pressed");
			game->StartGame();
			break;
		}
		default:
		{
			SDL_Log("MenuState::HandleEvents() - DEFAULT");
			break;
		}
	}
}

void MenuState::AdjustElements()
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

void MenuState::MousePress(SDL_MouseButtonEvent& e)
{
	switch (e.button)
	{
		case 1:
		{
			for (auto& it : buttons)
			{
				if(it->GetMouseOver())
				{
					if (it->GetLabel() == "Start")
					{
						game->StartGame();
					}
					if (it->GetLabel() == "Options")
					{
						SDL_Log("Display Options (State?) ");
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

void MenuState::ChangeState()
{

}

void MenuState::Update()
{

}

void MenuState::Draw()
{
	graphics->Draw(textures["menu"]);
	for (auto& it : buttons)
	{
		graphics->Draw(it);
	}
}

