#include "Game.h"
#include "IntroState.h"
//#include "State.h"

int main(int argc, char *args[])
{
	SDL_Log("Main()");
	Game g;
	if (g.Init() == false) {
		SDL_Log("ERR: Game could not init!.");
			return 0;
	}
	
	g.StartIntro();
	//g.
	g.Run();

	SDL_Log("Main::end()");
	return 0;
}