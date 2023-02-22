local World = {}
World.__index = World
-- Get ModuleScripts
local Spell = require(workspace.Spell)
local Unit = require(workspace.Unit)
local Player = require(workspace.Player)
local Config = require(script["worldserver.conf"]);
local Database = require(workspace.DatabaseHandler)
local DuelHandler = require(workspace.DuelHandler);
local Connection = require(workspace.ConnectionHandler)

-------------------------------------------------------
function World.new()
	local new_world = {}
	setmetatable(new_world, World)

	new_world.client_opcodes = {}
	new_world.opcodesList = {}
	new_world.UnitList = {}
	new_world.connection_list = {}
	
	return new_world
end

function World:Update(m_time)
	for _,v in next,self.UnitList do
		if v ~= nil then
			v:Update(m_time)
		end
	end
end

function World:GetCharacter(CharId)
	local list = Database.Access("characters", "character", nil)
	for _,v in next,list:GetChildren() do
		for i,g in next,v:GetChildren() do
			if g.CharId.Value == CharId then
				return g;
			end
		end
	end
end

function World:BuildCharacter(connection, name, class)
	local char = Instance.new("Folder");
	char.Name = name
	local classId = Instance.new("IntValue", char);
	classId.Value = class
	classId.Name = "classId"
	local factionID = Instance.new("IntValue", char)
	factionID.Value = 2
	factionID.Name = "factionID"
	char.Parent = game:service'ReplicatedStorage'.Database.characters.character[connection.player.Name];
	connection:DisplayCharacters();
end

function World:ForceData(c_ops, opList)
	self.client_opcodes = c_ops
	self.opcodesList = opList
end

function World:GetConnection(player)
	for _,v in next,self.connection_list do
		if v.player == player then
			return v;
		end
	end
end

function World:AddUnit(unit)
	table.insert(self.UnitList, unit)
end

function World:AddConnection(connection)
	table.insert(self.connection_list, connection);
end

function World:GetUnit(unit)
	for _,v in next,self.UnitList do
		if v.link == unit then
			return v
		end
	end
end

function World:ToWorld()
	return self;
end

local serverPackets={};
local clientPackets={};
local numSuc = 0;
local rs=game:service'ReplicatedStorage';

-- Create World Object
local GameWorld = World.new()

-- When new player is added, create a Unit object
game.Players.PlayerAdded:connect(function(player)
	wait(2)
	local connection = Connection.new(player)
	GameWorld:AddConnection(connection);
	connection:DisplayCharacters();
end)

-- Add unit objects for NPCs, in this case it will be Todd
local todd = workspace.Todd
local new_todd = Unit.new(todd, "Creature", GameWorld)
GameWorld:AddUnit(new_todd)

local client_opcodes={ -- Add in here to setup what happens
	["CMSG_CAST_SPELL"]=function(player, spell)
		if not player then return false end; -- Should never happen
		local m_unit = GameWorld:GetUnit(player)
		if not spell then return false end; -- Should never happen
		local newSpell = m_unit:BuildSpell(spell, m_unit:GetTarget(), false)
		newSpell:Prepare()
	end,
	["CMSG_UPDATE_WORLD"]=function(player)
		--Working: Ignore for now
	end,
	["CMSG_CHATMESSAGE_SAY"]=function(player,msg)
		--Working: Ignore for now
	end,
	["CMSG_MOVE_JUMP"]=function(player, active)
		--Working: Ignore for now
	end,
	["CMSG_MOVE_FALL_LAND"]=function(player, active)
		--Working: Ignore for now
	end,
	["CMSG_STAT_CHANGED"]=function(player, stat, newVal)
		Player.HandleStatChanged(player, stat, newVal);
	end,
	["CMSG_UPDATE_STATS"]=function(player, target, stat, value)
		Player.HandleUpdateStats(target, stat, value);
	end,
	["CMSG_CAST_SUCCEEDED"]=function(player, scr, secondScr)
		local spell = Spell.GetSpellInfo();
		player.Backpack.IsCasting.Value = false;
		scr.Disabled = true;
		secondScr.Disabled = false;
		numSuc = numSuc + 1;
		--Spell.DoCast();
	end,
	["CMSG_DISABLE_SCRIPT"]=function(player, ...)
		local tab = {...};
		if #tab>0 then
			for i=1,#tab do
				tab[i].Disabled = true;
			end
		end
	end,
	["CMSG_UPDATE_TARGET"]=function(player, target)
		local m_unit = GameWorld:GetUnit(player)
		local m_target = GameWorld:GetUnit(target)
		m_unit:UpdateTarget(m_target)
	end,
	["CMSG_PLAYER_LOGIN"]=function(player)
		local Id = player:WaitForChild'Backpack':WaitForChild'Id';
		Id.Value = player.UserId;
		local fol = Database.Access("characters", "character", player.Name);
		if fol then return false end;
		local folder = Instance.new("Folder");
		folder.Name = player.Name;
		local faction = Instance.new("IntValue");
		faction.Name = "factionID";
		faction.Value = 1;
		faction.Parent = folder;
		Database.Insert("characters","character",folder);
	end,
	["CMSG_ANIMATION_FINISHED"]=function(player, caster, spellName, target)

	end,
	["CMSG_INIT_DUEL"]=function(player, data)
		local m_unit = GameWorld:GetUnit(data.Initiator)
		local m_player = m_unit:ToPlayer();
		if m_player then
			m_player:InitiateDuel(m_unit:GetTarget());
		else
			error("Player not found!")
		end
	end,
	["CMSG_ACCEPTED_DUEL"]=function(player)
		local m_player = GameWorld:GetUnit(player):ToPlayer()
		if m_player:HasDuel() then
			m_player:AcceptDuel();
		end
	end,
	["CMSG_DECLINED_DUEL"]=function(player)
		local m_player = GameWorld:GetUnit(player):ToPlayer()
		if m_player:HasDuel() then
			m_player:DeclineDuel();
		end
	end,
	["CMSG_DUEL_FINISHED"]=function(player, target, winner)
		DuelHandler.DuelFinished(player, target, winner);
	end,
	["CMSG_SELECTED_CLASS"]=function(player, class)
		Player.HandleSelectClass(player, class);
	end,
	["CMSG_JOIN_WORLD"]=function(player, data)
		local charId = data.CharId
		local char = GameWorld:GetCharacter(charId);
		--TODO: Create unit for player logged in, do LoadCharacter
		local new_unit = Unit.new(player, "Player", GameWorld, char.Name)
		GameWorld:AddUnit(new_unit);
	end,
	["CMSG_CREATE_CHAR"]=function(player, data)
		--TODO: Handle Character Creation
		local name = data.Name
		local class = data.Class
		local con = GameWorld:GetConnection(player);
		GameWorld:BuildCharacter(con, name, class);
	end,
}
local opcodes={
	"CMSG_CAST_SPELL",
	"CMSG_UPDATE_WORLD",
	"CMSG_CHATMESSAGE_SAY",
	"CMSG_MOVE_JUMP"	,
	"CMSG_MOVE_FALL_LAND",
	"CMSG_STAT_CHANGED",
	"CMSG_UPDATE_STATS",
	"CMSG_CAST_SUCCEEDED",
	"CMSG_CAST_CANCELED",
	"CMSG_DISABLE_SCRIPT",
	"CMSG_UPDATE_TARGET",
	"CMSG_DEAL_DAMAGE",
	"CMSG_DEAL_HEALING",
	"CMSG_PLAYER_LOGIN",
	"CMSG_ANIMATION_FINISHED",
	"CMSG_INIT_DUEL",
	"CMSG_ACCEPTED_DUEL",
	"CMSG_DUEL_FINISHED",
	"CMSG_SELECTED_CLASS",
	"CMSG_DECLINED_DUEL",
	"CMSG_JOIN_WORLD",
	"CMSG_CREATE_CHAR"
}

GameWorld:ForceData(client_opcodes, opcodes)

-------------------------------------------------------
--[[Build necessary packets]]--
function BuildServerPacket(n,p,pl,newobj)
	local remev=Instance.new("RemoteEvent",p);
	remev.Name=n;
	if newobj then
		newobj.Parent=remev
	end
	table.insert(serverPackets,remev);
	return remev;
end

for i=1,#GameWorld.opcodesList do wait()
	print(i)
	BuildServerPacket(GameWorld.opcodesList[i],workspace);
end
-------------------------------------------------------
function ParseClientPacket(p,...)
	if p then
		if GameWorld.client_opcodes[p.Name] then
			GameWorld.client_opcodes[p.Name](...);
			--print(p.Name..": Send to server!");
		end
	end
end
function InvokeClientPacket(p,...)
	if p then
		p:FireClient(...);
	end
end

---------- TODO: Make separate core scripts to handle opcodes
-- Create the function handling the opcode
function PlayerJoinedWorld(...)
	ParseClientPacket(game.Workspace["CMSG_JOIN_WORLD"],...);
end
function PlayerCreatedChar(...)
	ParseClientPacket(game.Workspace["CMSG_CREATE_CHAR"],...);
end
function PlayerCastedSpell(...)
	ParseClientPacket(game.Workspace["CMSG_CAST_SPELL"],...);
end
function PlayerUpdateWorld(...)
	ParseClientPacket(game.Workspace["CMSG_UPDATE_WORLD"],...);
end
function PlayerChatMessageSay(...)
	ParseClientPacket(game.Workspace["CMSG_CHATMESSAGE_SAY"],...);
end
function PlayerMoveJump(...)
	ParseClientPacket(game.Workspace["CMSG_MOVE_JUMP"],...);
end
function PlayerDeclinedDuel(...)
	ParseClientPacket(game.Workspace["CMSG_DECLINED_DUEL"],...);
end
function PlayerMoveFallLand(...)
	ParseClientPacket(game.Workspace["CMSG_MOVE_FALL_LAND"],...);
end
function PlayerStatChanged(...)
	ParseClientPacket(game.Workspace["CMSG_STAT_CHANGED"],...);
end
function PlayerUpdateStats(...)
	ParseClientPacket(game.Workspace["CMSG_UPDATE_STATS"],...);
end
function PlayerCastSucceeded(...)
	ParseClientPacket(game.Workspace["CMSG_CAST_SUCCEEDED"],...);
end
function PlayerCastCanceled(...)
	ParseClientPacket(game.Workspace["CMSG_CAST_CANCELED"],...);
end
function PlayerDisableScript(...)
	ParseClientPacket(game.Workspace["CMSG_DISABLE_SCRIPT"],...);
end
function PlayerUpdateTarget(...)
	ParseClientPacket(game.Workspace["CMSG_UPDATE_TARGET"],...);
end
function PlayerDealDamage(...)
	ParseClientPacket(game.Workspace["CMSG_DEAL_DAMAGE"],...);
end
function PlayerDealHealing(...)
	ParseClientPacket(game.Workspace["CMSG_DEAL_HEALING"],...);
end
function PlayerLoggedIn(...)
	ParseClientPacket(game.Workspace["CMSG_PLAYER_LOGIN"],...)
end
function SpellAnimationFinished(...)
	ParseClientPacket(game.Workspace["CMSG_ANIMATION_FINISHED"],...);
end
function PlayerRequestDuel(...)
	ParseClientPacket(game.Workspace["CMSG_INIT_DUEL"],...);
end
function PlayerAcceptedDuel(...)
	ParseClientPacket(game.Workspace["CMSG_ACCEPTED_DUEL"],...);
end
function PlayerFinishedDuel(...)
	ParseClientPacket(game.Workspace["CMSG_DUEL_FINISHED"],...);
end
function PlayerSelectedClass(...)
	ParseClientPacket(game.Workspace["CMSG_SELECTED_CLASS"],...);
end
_G.CastSpell = function(...)
	GameWorld.client_opcodes["CMSG_CAST_SPELL"](...);
end
_G.AnimationFinished = function(...)
	GameWorld.client_opcodes["CMSG_ANIMATION_FINISHED"](...);
end
-- Create the listener of the opcode
game.Workspace["CMSG_JOIN_WORLD"].OnServerEvent:connect(PlayerJoinedWorld);
game.Workspace["CMSG_CREATE_CHAR"].OnServerEvent:connect(PlayerCreatedChar);
game.Workspace["CMSG_CAST_SPELL"].OnServerEvent:connect(PlayerCastedSpell);
game.Workspace["CMSG_UPDATE_WORLD"].OnServerEvent:connect(PlayerUpdateWorld);
game.Workspace["CMSG_CHATMESSAGE_SAY"].OnServerEvent:connect(PlayerChatMessageSay);
game.Workspace["CMSG_MOVE_JUMP"].OnServerEvent:connect(PlayerMoveJump);
game.Workspace["CMSG_MOVE_FALL_LAND"].OnServerEvent:connect(PlayerMoveFallLand);
game.Workspace["CMSG_STAT_CHANGED"].OnServerEvent:connect(PlayerStatChanged);
game.Workspace["CMSG_UPDATE_STATS"].OnServerEvent:connect(PlayerUpdateStats);
game.Workspace["CMSG_CAST_SUCCEEDED"].OnServerEvent:connect(PlayerCastSucceeded);
game.Workspace["CMSG_CAST_CANCELED"].OnServerEvent:connect(PlayerCastCanceled);
game.Workspace["CMSG_DISABLE_SCRIPT"].OnServerEvent:connect(PlayerDisableScript);
game.Workspace["CMSG_UPDATE_TARGET"].OnServerEvent:connect(PlayerUpdateTarget);
game.Workspace["CMSG_DEAL_DAMAGE"].OnServerEvent:connect(PlayerDealDamage);
game.Workspace["CMSG_DEAL_HEALING"].OnServerEvent:connect(PlayerDealHealing);
game.Workspace["CMSG_PLAYER_LOGIN"].OnServerEvent:connect(PlayerLoggedIn);
game.Workspace["CMSG_ANIMATION_FINISHED"].OnServerEvent:connect(SpellAnimationFinished);
game.Workspace["CMSG_INIT_DUEL"].OnServerEvent:connect(PlayerRequestDuel);
game.Workspace["CMSG_ACCEPTED_DUEL"].OnServerEvent:connect(PlayerAcceptedDuel);
game.Workspace["CMSG_DECLINED_DUEL"].OnServerEvent:connect(PlayerDeclinedDuel);
game.Workspace["CMSG_DUEL_FINISHED"].OnServerEvent:connect(PlayerFinishedDuel);
game.Workspace["CMSG_SELECTED_CLASS"].OnServerEvent:connect(PlayerSelectedClass);







--Update World Function

game:service'RunService'.Stepped:connect(function(s, m_time)
	GameWorld:Update(m_time)
end)













-------------------------------------

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local playerCollisionGroupName = "Units";
PhysicsService:CreateCollisionGroup(playerCollisionGroupName)
PhysicsService:CollisionGroupSetCollidable(playerCollisionGroupName, playerCollisionGroupName, false)
local previousCollisionGroups = {}

local function setCollisionGroup(object)
	if object:IsA("BasePart") then
		previousCollisionGroups[object] = object.CollisionGroupId
		PhysicsService:SetPartCollisionGroup(object, playerCollisionGroupName)
	end
end

local function setCollisionGroupRecursive(object)
	setCollisionGroup(object)

	for _, child in ipairs(object:GetChildren()) do
		setCollisionGroupRecursive(child)
	end
end

local function resetCollisionGroup(object)
	local previousCollisionGroupId = previousCollisionGroups[object]
	if not previousCollisionGroupId then return end 

	local previousCollisionGroupName = PhysicsService:GetCollisionGroupName(previousCollisionGroupId)
	if not previousCollisionGroupName then return end

	PhysicsService:SetPartCollisionGroup(object, previousCollisionGroupName)
	previousCollisionGroups[object] = nil
end

local function onCharacterAdded(character)
	setCollisionGroupRecursive(character)

	character.DescendantAdded:Connect(setCollisionGroup)
	character.DescendantRemoving:Connect(resetCollisionGroup)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(onCharacterAdded)
end

Players.PlayerAdded:Connect(onPlayerAdded)