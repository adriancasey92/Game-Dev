#include "ResourceManager.h"

//namespace fs = std::experimental::filesystem;

ResourceManager::ResourceManager(SDL_Renderer* renderer)
{
	SDL_Log("ResourceManager::ResourceManager() - Constructor called");
	this->renderer = renderer;
}

ResourceManager::~ResourceManager()
{
	SDL_Log("ResourceManager::ResourceManager() - Deconstructor called");
	//Destroy textures
	for (auto& t : textures)
	{
		SDL_DestroyTexture(t.second);
	}
}

bool ResourceManager::Init()
{
	SDL_Log("ResourceManager::Init()");
	if (!LoadMedia())
	{
		SDL_Log("ResourceManager::Init - ERR Could not init.");
		return false;
	}


	return true;
}

bool ResourceManager::LoadMedia()
{
	textures["pause"] = LoadTexture("pause.png");
	textures["button"] = LoadTexture("button.png");
	//textures["buttonHighlight"] = LoadTexture("buttonHighlight.png");
	return true;
}

SDL_Texture* ResourceManager::LoadTexture(const std::string& filePath)
{
    SDL_Log("ResourceManager::ResourceManager() - Loading Resource %s: ",filePath.c_str());
	//If texture is not already loaded, load it
	if (textures.find(filePath) == textures.end()) {
		textures[filePath] = CreateTexture(filePath);
	}
	return textures[filePath];
}

SDL_Texture* ResourceManager::LoadTexture(const std::string& filePath, std::string name, int x, int y)
{
	SDL_Log("ResourceManager::LoadTextureFromSpriteSheet() - Loading Resource %s: ", filePath.c_str());
	//If texture is not already loaded, load it
	if (textures.find(name) == textures.end()) {
		textures[name] = CreateTexture(filePath);
	}
	return textures[filePath];
}

SDL_Texture* ResourceManager::CreateTexture(const std::string& filePath)
{
	std::string fullPath = texturePath + filePath;
	//The final texture
    SDL_Texture* texture = IMG_LoadTexture(renderer, fullPath.c_str());
	//Load image at specified path
    //DL_Surface* loadedSurface = IMG_Load(fullPath.c_str());
	//If the surface is NULL, print the error
    if (texture== NULL)
    {
        printf("Unable to load image %s! SDL_Texture Error: %s\n", fullPath.c_str(), IMG_GetError());
    }
    
    return texture;
}

SDL_Texture* ResourceManager::CreateTextureFromSpriteSheet(const std::string& filePath, int x, int y)
{
	return nullptr;
}

void ResourceManager::LoadImagesFromDirectory(const std::string& dir)
{
	//Loads images from a directory
}