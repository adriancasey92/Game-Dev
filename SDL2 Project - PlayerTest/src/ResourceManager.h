#pragma once
#include "common.h"
#include <filesystem>
#include <unordered_map>
#include "Object.h"


class ResourceManager
{
	public:
		ResourceManager(SDL_Renderer* renderer);
		~ResourceManager();

		bool Init();

		bool LoadMedia();
		SDL_Texture* LoadTexture(const std::string& filePath);
		SDL_Texture* LoadTexture(const std::string& filePath,std::string name, int x, int y);
		SDL_Texture* CreateTexture(const std::string& filePath);
		SDL_Texture* CreateTextureFromSpriteSheet(const std::string& filePath, int x, int y);

	private:
		void LoadImagesFromDirectory(const std::string& dir);
	
		std::unordered_map<std::string, SDL_Texture*> textures;
		SDL_Renderer* renderer;
		const std::string texturePath = "resource/texture/";
		const std::string soundPath = "resource/sound/";
		const std::string fontPath = "resources/font/";
		const std::string root = SDL_GetBasePath();

		std::vector<Object*> objects;
};