#pragma once
#include "Common.h"
#include "Graphics.h"
#include "ResourceManager.h"

class State;
class IntroState;
class PauseState;
class Object;
class Player;

class Game {
	public:
		Game();
		~Game();

		void Run();

		bool Init();
		void Cleanup();
		void Pause();
		void Resume();
		void Quit();
		void PopState();
		void PushState(State* s);
		void ChangeState(State* s);

		//States
		void StartIntro();
		void MainMenu();
		void StartGame();
		void QuitToMenu();
		
		void HandleEvents();
		void Update();
		void Draw();
		bool getPaused() const;


	private:
		std::vector<State*> states;
		Graphics* graphics;	
		ResourceManager* resources;;
		PauseState* pauseState;

		int fps;
		TTF_Font* font;
		
		bool debug;
		bool isPaused;
		bool running;
		std::stringstream timeText;
};