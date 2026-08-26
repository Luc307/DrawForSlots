-- Physical lobby buttons / server OpenCasinoPage -> open ShopUI page
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundController = require(ReplicatedStorage.Modules.SoundController)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Signals = ReplicatedStorage:WaitForChild("Signals")
local OpenCasinoPage = Remotes:WaitForChild("OpenCasinoPage")
local RequestOpenUI = Signals:WaitForChild("RequestOpenUI") :: BindableEvent

OpenCasinoPage.OnClientEvent:Connect(function(pageName: string)
	if typeof(pageName) ~= "string" or pageName == "" then
		return
	end
	SoundController.playClick()
	RequestOpenUI:Fire(pageName)
end)
