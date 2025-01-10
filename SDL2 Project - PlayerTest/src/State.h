#pragma once
#include "Graphics.h"
#include "ResourceManager.h"

class Game;
class Button;

class State {
    public:
        
        State() { game = nullptr; 
        graphics = nullptr; 
        resource = nullptr;
        };

        State(Game* g
            , Graphics* gfx
            , ResourceManager* r)
            : game(g)
            , graphics(gfx)
            , resource(r)
        {};

        virtual ~State() {}

        virtual bool Init() = 0;
        virtual void Cleanup() = 0;                                 // Frees all loaded media
        virtual void Pause() = 0;                                   // Pauses current state
        virtual void Resume() = 0;                                  // Resumes current state

        //Load in media/assets. 
        virtual void LoadMedia() = 0;                               // Media loading        
        virtual void HandleEvents(SDL_Event e) = 0;                            // Handle input
        virtual void ChangeState() = 0;                     // Change to a new state
        virtual void Update() = 0;                                  // Update the state logic
        virtual void Draw() = 0;                  // Render the current state

    private:
    // Handle logic specific to the state

        Game* game;
        Graphics* graphics;
	    ResourceManager* resource;

        std::unordered_map<std::string, SDL_Texture*> textures;
       
};


