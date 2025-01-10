#include "PlayState.h"
#include "Game.h"
#include "Player.h"
const std::string resourcePath = "resource/";

bool PlayState::Init()
{
	SDL_Log("PlayState::Init() - Initializing");
	//this->graphics = graphics;
	LoadMedia();
	LoadObjects();
	return true;
}

void PlayState::Cleanup() 
{ 
	SDL_Log("PlayState::Cleanup()"); 
	SDL_Log("Saving game information");
	// do save things
}

void PlayState::Pause() { SDL_Log("PlayState::Pause()"); }

void PlayState::Resume() { SDL_Log("PlayState::Resume()"); }

void PlayState::LoadMedia()
{
	SDL_Log("PlayState::LoadMedia() - Loading files");

	textures["game"] = resource->LoadTexture("game.png");
	textures["player"] = resource->LoadTexture("player.png");

	if (textures["player"] == NULL || textures["player"] == nullptr)
		SDL_Log("textures[\"player\"] is NULL");
	//textures["grass1"] = resource->LoadTexture("spritesheet.png", 0, 0);
}

void PlayState::LoadObjects()
{
	SDL_Log("PlayState::LoadObjects() - Loading Objects");
	Player* p = new Player(game, graphics, textures["player"]);
	p->Init();
	objects["player"] = p;
}

void PlayState::HandleEvents(SDL_Event e)
{
	if (e.type == SDL_QUIT)
		game->Quit();
	if (e.type == SDL_KEYDOWN)
		if (e.key.keysym.sym == SDLK_ESCAPE)
			game->Pause();

	if (!objects.empty())
	{
		objects["player"]->HandleEvent(e);
	}
}


void PlayState::KeyPress(SDL_KeyboardEvent& k)
{
	
}

void PlayState::MousePress(SDL_MouseButtonEvent& e)
{
	switch (e.button)
	{
		case 1:
			break;
		case 2:
			break;
		case 3:
			break;
		case 4:
			break;
		case 5:
			break;
		default:
			break;
	}
}

void PlayState::ChangeState()
{
	SDL_Log("PlayState::ChangeState()");
	game->StartGame();
}

void PlayState::Update()
{
	//if not paused
	if ((game->getPaused()))
	{
		//SDL_Log("IntroState::Update() - Paused Update");
	}
	else
	{
		for (auto &a : objects)
		{
			a.second->Update();
		}
		//SDL_Log("IntroState::Update() - Not Paused Update");
	}

	//SDL_Log("IntroState::Cleanup()");

}

void PlayState::Draw()
{
	/*int resolutionw = graphics->GetResolutionWidth();
	int resolutionh = graphics->GetResolutionHeight();
	*/

	graphics->Draw(textures["game"]);
	for (auto& a : objects)
	{
		graphics->Draw(a.second);
	}
}

