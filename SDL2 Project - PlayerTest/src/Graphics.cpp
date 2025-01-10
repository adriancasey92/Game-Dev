#include "Graphics.h"
#include "Common.h"
#include "Object.h"
#include "Button.h"
#include "Menu.h"

Graphics::Graphics() {
    // Initialize graphics system (e.g., window, OpenGL context)
    SDL_Log("Graphics::Graphics() - Constructor called");
    width = 640;
    height = 480;
    window = NULL;
	renderer = NULL;
    font = NULL;
    textSize = 30;
}

Graphics::~Graphics() {
    // Cleanup graphics resources
    SDL_Log("Graphics::~Graphics()");
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
}

bool Graphics::Init()
{
	//Initialize SDL
    window = SDL_CreateWindow("Test", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, width, height, SDL_WINDOW_RESIZABLE | SDL_WINDOW_SHOWN);
    if (SDL_Init(SDL_INIT_VIDEO) < 0)
    {
        printf("Graphics::Init() - SDL could not initialize! SDL_Erropr: %s\n", SDL_GetError());
        return false;
    }
	//Create renderer for window
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
	if (renderer == NULL)
	{
		printf("Graphics::Init() - Renderer could not be created! SDL Error: %s\n", SDL_GetError());
		return false;
	}
	//Set the color used for drawing operations
    SDL_SetRenderDrawColor(renderer, 0xFF, 0xFF, 0xFF, 0xFF);

	//Initialize PNG loading
	int imgFlags = IMG_INIT_PNG;
	if (!(IMG_Init(imgFlags) & imgFlags))
	{
		printf("Graphics::Init() - SDL_image could not initialize! SDL_image Error: %s\n", IMG_GetError());
		return false;
	}

    if (TTF_Init() == -1)
    {
        printf("SDL_ttf could not initialize! SDL_ttf Error: %s\n", TTF_GetError());
        return false;
    }

    font = TTF_OpenFont("resource/font/TrenchThin-aZ1J.ttf", textSize);
    if (font == NULL)
    {
        printf("Failed to load font! SDL_ttf Error: %s\n", TTF_GetError());
        return false;
    }

    return true;
}

void Graphics::HandleEvents(SDL_Event e)
{
    if (e.type == SDL_WINDOWEVENT)
    {
        switch (e.window.event)
        {
            case SDL_WINDOWEVENT_SIZE_CHANGED:
            {
                
                Resize(e);
                /*
                width = e.window.data1;
                height = e.window.data2;
                
                SDL_RenderPresent(renderer);
                */
                break;
            }
            //Repaint on exposure
            case SDL_WINDOWEVENT_EXPOSED:
            {
                SDL_RenderPresent(renderer);
                break;
            }
            //Mouse entered window
            case SDL_WINDOWEVENT_ENTER:
            {
                mouseFocus = true;
                //updateCaption = true;
                break;
            }
                //Mouse left window
            case SDL_WINDOWEVENT_LEAVE:
            {
                mouseFocus = false;
                //updateCaption = true;
                break;
            }
                //Window has keyboard focus
            case SDL_WINDOWEVENT_FOCUS_GAINED:
            {
                keyboardFocus = true;
                //updateCaption = true;
                break;
            }
                //Window lost keyboard focus
            case SDL_WINDOWEVENT_FOCUS_LOST:
            {
                keyboardFocus = false;
                //updateCaption = true;
                break;
            }
                //Window minimized
            case SDL_WINDOWEVENT_MINIMIZED:
            {
                minimized = true;
                break;
            }
                //Window maximized
            case SDL_WINDOWEVENT_MAXIMIZED:
            {
                minimized = false;
                break;
            }
                //Window restored
            case SDL_WINDOWEVENT_RESTORED:
            {
                minimized = false;
                break;
            }
        }
    }
}

void Graphics::Clear() 
{    
	SDL_RenderClear(renderer);
}

void Graphics::Display() 
{
	SDL_RenderPresent(renderer);
}

void Graphics::Draw(SDL_Texture* texture, SDL_Rect dst, SDL_Rect clip)
{
    SDL_RenderCopy(renderer, texture, &clip, &dst);
}

void Graphics::Draw(SDL_Texture* texture, SDL_Rect dst)
{
    SDL_RenderCopy(renderer, texture, nullptr, &dst);
}

void Graphics::Draw(SDL_Texture* texture, int x, int y, SDL_Rect clip)
{
    SDL_Rect dst = { 0,0,0,0 };
    dst.x = x;
    dst.y = y;

    if (&clip != nullptr) {
        dst.w = clip.w;
        dst.h = clip.h;
    }
    else {
        SDL_QueryTexture(texture, NULL, NULL, &dst.w, &dst.h);
    }
    Draw(texture, dst, clip);
}

void Graphics::Draw(SDL_Texture* texture, int x, int y)
{
    SDL_Rect dst = { 0,0,0,0 };
    dst.x = x;
    dst.y = y;

    
    SDL_QueryTexture(texture, NULL, NULL, &dst.w, &dst.h);
   
    Draw(texture, dst);
}

void Graphics::Draw(Object* object)
{ 
    Draw(object->GetTexture(), object->GetPosX(), object->GetPosY());
}

void Graphics::DrawText(std::string text, int x, int y, int padW, int padH)
{
    SDL_Rect dst = { 0,0,0,0 };
    SDL_Colour c = { 0,0,0,0 };
    SDL_Texture* tx;
    c.r = 0;
    c.g = 0;
    c.b = 0;
    SDL_Surface* textSurf = TTF_RenderText_Solid(font, text.c_str(), c);
    if (textSurf == NULL)
    {
        printf("Unable to render text surface!SDL_ttf Error : % s\n", TTF_GetError());
        return;
    }

    tx = SDL_CreateTextureFromSurface(renderer, textSurf);

    if (tx == NULL)
    {
        printf("Unable to create texture from rendered text! SDL Error: %s\n", SDL_GetError());
        return;
    }
    dst.w = textSurf->w;
    dst.h = textSurf->h;

    SDL_FreeSurface(textSurf);

    dst.x = x + (padW / 2) - (dst.w / 2);
    dst.y = y + (padH / 2) - (dst.h / 2);


    SDL_RenderCopyEx(renderer, tx, NULL, &dst, 0, 0, SDL_FLIP_NONE);

    SDL_DestroyTexture(tx);
}

/*void Graphics::Draw(Button* button, int x, int y, SDL_Rect clip)
{
   Draw(button->GetTexture(), x, y, clip);
   DrawText(button->GetLabel(), x, y, button->GetWidth(), button->GetHeight());
}
*/
void Graphics::Draw(Button* button)
{
    Draw(button->GetTexture(), button->GetPos().x, button->GetPos().y, button->GetClips());
    DrawText(button->GetLabel(), button->GetPos().x, button->GetPos().y, button->GetWidth(), button->GetHeight());
}

void Graphics::Pause()
{
    SDL_Log("Graphics::Pause");
    paused = SDL_GetRenderTarget(renderer);
}

//Handles resize events.
void Graphics::Resize(SDL_Event e)
{
    SDL_Log("Graphics::Resize() - Resizing window.");
    width = e.window.data1;
    height = e.window.data2;
    SDL_Texture* t = SDL_GetRenderTarget(renderer);
    Clear();
    if (paused != NULL)
    {
        SDL_SetTextureBlendMode(paused, SDL_BLENDMODE_BLEND);
        SDL_SetRenderTarget(renderer, paused);
        SDL_RenderCopy(renderer, t, nullptr, nullptr);
        SDL_SetRenderTarget(renderer, NULL);
        
        SDL_RenderCopy(renderer, paused, nullptr, nullptr);
        
    }
    else
    {
        SDL_RenderCopy(renderer, t, nullptr, nullptr);
    }
    SDL_DestroyTexture(t);
    printf("Window H: %i\nWindow W: %i\n", height, width);
}

void Graphics::Draw(SDL_Texture* texture)
{
    SDL_RenderCopy(renderer, texture, nullptr, nullptr);
}

SDL_Texture* Graphics::GetTextFromString(std::string text)
{
    SDL_Color c = { 0,0,0 };
    SDL_Texture* t = nullptr;;
    //Render text surface
    SDL_Surface* textSurface = TTF_RenderText_Solid(font, text.c_str(), c);
    if (textSurface == NULL)
    {
        printf("Unable to render text surface! SDL_ttf Error: %s\n", TTF_GetError());
    }
    else
    {
        //Create texture from surface pixels
        t = SDL_CreateTextureFromSurface(renderer, textSurface);
        if (t == NULL)
        {
            printf("Unable to create texture from rendered text! SDL Error: %s\n", SDL_GetError());
        }
        //Get rid of old surface
        SDL_FreeSurface(textSurface);
    }
    if (t == NULL)
    {
        return NULL;
    }

    //Return success
    return t;
}
