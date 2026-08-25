local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local CoinDS = DataStoreService:GetDataStore("PlayerCoins")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetCoins = Remotes:WaitForChild("GetCoins")

local GiveCoinsFunc = script:WaitForChild("GiveCoinsFunc") :: BindableFunction
local AdjustCoinsFunc = script:WaitForChild("AdjustCoinsFunc") :: BindableFunction
local GetCoinsFunc = script:WaitForChild("GetCoinsFunc") :: BindableFunction

GetCoins.OnServerInvoke = function(player)
	local key = "coins_" .. player.UserId
	local ok, coins = pcall(function()
		return CoinDS:GetAsync(key)
	end)
	if ok then
		return coins or 500
	else
		warn("[CoinService] GetAsync failed for " .. player.Name .. ": " .. tostring(coins))
		return 0
	end
end

local function giveCoins(player, amount)
	local key = "coins_" .. player.UserId
	local ok, err = pcall(function()
		CoinDS:UpdateAsync(key, function(old)
			return (old or 0) + amount
		end)
	end)
	if not ok then
		warn("[CoinService] UpdateAsync failed: " .. tostring(err))
	else
		print("[CoinService] +" .. amount .. " coins -> " .. player.Name)
	end
end

GiveCoinsFunc.OnInvoke = function(player, amount)
	giveCoins(player, amount)
end

local function adjustCoins(player, delta)
	local key = "coins_" .. player.UserId
	local ok, err = pcall(function()
		CoinDS:UpdateAsync(key, function(old)
			return math.max(0, (old or 500) + delta)
		end)
	end)
	if not ok then
		warn("[CoinService] adjust failed: " .. tostring(err))
		return false
	end
	return true
end

AdjustCoinsFunc.OnInvoke = function(player, delta)
	return adjustCoins(player, delta)
end

local function readCoins(player)
	local key = "coins_" .. player.UserId
	local ok, coins = pcall(function()
		return CoinDS:GetAsync(key)
	end)
	if ok then
		return coins or 500
	end
	return 0
end

GetCoinsFunc.OnInvoke = readCoins

if Config.TESTING_GIVE_COINS then
	local amount = Config.TESTING_COINS_AMOUNT
	local function grantTestCoins(player)
		giveCoins(player, amount)
	end
	Players.PlayerAdded:Connect(grantTestCoins)
	for _, player in Players:GetPlayers() do
		task.spawn(grantTestCoins, player)
	end
	print("[CoinService] Testing: +" .. amount .. " coins each session")
end

print("[CoinService] Ready!")
