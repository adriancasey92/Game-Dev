#include "Game.h"
#include "State.h"
#include "IntroState.h"
#include "MenuState.h"
#include "PlayState.h"
#include "PauseState.h"
#include "Graphics.h"
#include "Object.h"
#include "Player.h"

Game::Game()
{
	SDL_Log("Game::Game()");
	running = true;
	isPaused = false;
	graphics = NULL;
	pauseState = NULL;
	resources = NULL;
	debug = false;
	fps = 0;
	font = NULL;
}

Game::~Game()
{
	//Cleanup if needed
	SDL_Log("Game::~Game()");
}

//Init the different components of the game
bool Game::Init()
{
	SDL_Log("Game::Init()");
	isPaused = false;
	
	//Create Graphics and init.
	graphics = new Graphics();
	if (graphics->Init() == false)
		return false;
	
	//Create Resource Manager and init.
	resources = new ResourceManager(graphics->getRenderer());
	if(resources->Init() == false)
		return false;

	//Create PauseState and init.
	pauseState = new PauseState(this, graphics, resources);
	if (!pauseState->Init())
		return false;
	
	return true;
}

void Game::Pause()
{
	isPaused = true;
	SDL_Log("Game::Pause()");
	graphics->Pause();
	PushState(pauseState);		
}

void Game::Resume()
{
	SDL_Log("Game::Resume()");
	PopState();
	isPaused = false;
}

void Game::Quit()
{
	SDL_Log("Game::Quit()");
	running = false;
	//Call the statemanager to clean states
	
}

void Game::Run()
{
	SDL_Log("Game::Run()");

	unsigned int a = SDL_GetTicks();
	unsigned int b = SDL_GetTicks();
	double delta = 0;

	//Game loop
	while (running)	
	{
		a = SDL_GetTicks();
		delta = a - b;
		if (delta > static_cast<double>(1000) / 60)
		{
			b = a;
			HandleEvents();
			Update();
			Draw();
		}
		//Do things in game, then update window surface
	}

	//Cleanup
	Cleanup();
}

void Game::Cleanup()
{
	SDL_Log("Game::Cleanup()");

	//While states vector has states inside
	//Cleanup state
	//Remove state
	/*while (!states.empty())
	{
		states.back()->Cleanup();
		states.pop_back();
	}*/
	states.clear();

	delete pauseState;
	delete graphics;
	delete resources;
	
}

void Game::PushState(State* state)
{
	SDL_Log("Game::PushState()");
	// pause current state
	if (!states.empty()) {
		states.back()->Pause();
	}

	// store and init the new state
	states.push_back(state);
	
	states.back()->Init();
}

void Game::ChangeState(State* state)
{
	SDL_Log("Game::ChangeState()");
	// cleanup the current state
	if (!states.empty()) {
		states.back()->Cleanup();
		states.pop_back();
	}

	// store and init the new state
	states.push_back(state);
	states.back()->Init();
}

void Game::PopState()
{
	SDL_Log("Game::PopState()");
	// cleanup the current state
	if (!states.empty()) {
		if(states.back()!=pauseState)
			states.back()->Cleanup();
		states.pop_back();
	}

	// resume previous state
	if (!states.empty()) {
		states.back()->Resume();
	}
}

void Game::StartIntro()
{
	SDL_Log("Game::StartIntro() - Creating  IntroState State");
	IntroState* s = new IntroState(this, graphics, resources);
	ChangeState(s);
}

void Game::MainMenu()
{
	SDL_Log("Game::MainMenu() - Creating MainMenu State");
	MenuState* s = new MenuState(this, graphics, resources);
	ChangeState(s);
}

void Game::StartGame()
{
	SDL_Log("Game::StartIntro() - Creating PlayState State");
	PlayState *s = new PlayState(this, graphics, resources);
	ChangeState(s);
}

void Game::QuitToMenu()
{
	//Currently in pauseState.
	PopState();
	MainMenu();
}

void Game::HandleEvents()
{
	SDL_Event e;
	if(!states.empty())
		while (SDL_PollEvent(&e) != 0)
			if (e.type == SDL_WINDOWEVENT)
			{
				graphics->HandleEvents(e);
				states.back()->HandleEvents(e);
			}
			else
				states.back()->HandleEvents(e);
			
}

bool Game::getPaused() const
{
	return isPaused;
}

void Game::Update()
{
	if (!states.empty())
		states.back()->Update();
}

void Game::Draw()
{
	if (!states.empty())
	{
		//Only clear if game isn't paused. This allows the pause state to be drawn over the game state.
		if(!isPaused){
			graphics->Clear();
		}
		states.back()->Draw();
		graphics->Display();
	}
}