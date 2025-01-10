#include "IntroState.h"
#include "Game.h"
const std::string resourcePath = "resource/";

bool IntroState::Init()
{
	SDL_Log("IntroState::Init() - Initializing");
	//this->graphics = graphics;
	LoadMedia();
	return true;
}

void IntroState::Cleanup()
{
	SDL_Log("IntroState::Cleanup()");
	for (auto& t : textures)
	{
		SDL_DestroyTexture(t.second);	
	}
}

void IntroState::Pause() { SDL_Log("IntroState::Pause()"); game->Pause(); }

void IntroState::Resume() { SDL_Log("IntroState::Resume()"); game->Resume(); }

void IntroState::LoadMedia()
{
	SDL_Log("IntroState::LoadMedia() - Loading Textures into storage.");
	textures["Intro"] = resource->LoadTexture("INTRO.bmp");	
}

void IntroState::HandleEvents(SDL_Event e)
{
	switch (e.type)
	{	
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

	}
}

void IntroState::KeyPress(SDL_KeyboardEvent& k)
{
	//SDL_Log("IntroState::HandleEvents() - KEYDOWN");
	switch (k.keysym.sym)
	{
	case SDLK_UP:
	{
		SDL_Log("IntroState::HandleEvents() - Key Up");
		break;
	}
	case SDLK_DOWN:
	{
		SDL_Log("IntroState::HandleEvents() - Key Down");
		break;
	}
	case SDLK_LEFT:
	{
		SDL_Log("IntroState::HandleEvents() - Key Left");
		break;
	}
	case SDLK_RIGHT:
	{
		SDL_Log("IntroState::HandleEvents() - Key Right");
		break;
	}
	case SDLK_ESCAPE:
	{
		SDL_Log("IntroState::HandleEvents() - Escape pressed");
		game->Quit();
		break;
	}
	case SDLK_RETURN:
	{
		SDL_Log("IntroState::HandleEvents() - Enter pressed");
		game->MainMenu();
		break;
	}
	default:
	{
		SDL_Log("IntroState::HandleEvents() - DEFAULT");
		break;
	}
	}
}

void IntroState::MousePress(SDL_MouseButtonEvent& e)
{
	switch (e.button)
	{
		case 1:
		{
			break;
		}
		default:
		{
			SDL_Log("IntroState::HandleEvents() - MOUSE BUTTON DOWN - DEFAULT");
			break;
		}
	}
}

void IntroState::ChangeState()
{
	SDL_Log("IntroState::ChangeState()");
	game->StartGame();
}

void IntroState::Update()
{
	//if not paused
	if ((game->getPaused()))
	{
		//SDL_Log("IntroState::Update() - Paused Update");
	}
	else
	{
		//SDL_Log("IntroState::Update() - Not Paused Update");
	}
}

void IntroState::Draw()
{
	graphics->Draw(textures["Intro"]);
}

