wait(1)
local player=game.Players.LocalPlayer
local mouse=player:GetMouse()
local rs=game:service'ReplicatedStorage';
local uis = game:service("UserInputService")
local UI = require(player.PlayerGui.UIHandler);
local Opcodes = require(workspace.Opcodes);
local Player = require(workspace.Player);
local Unit = require(workspace.Unit)
local pGUI = player.PlayerGui
local CombatText = require(workspace.CombatText)
--------------

-- Objects --
local m_playerGUI = UI.new(player, pGUI.MainGui.Frame.Player, pGUI.MainGui.Frame.Target, pGUI.ActionBar, pGUI.CastBar, pGUI.LoginGUI)

game:service'RunService'.Heartbeat:connect(function(deltaTime)
	m_playerGUI:Update(deltaTime)
end)

local character = game.Workspace:WaitForChild(player.Name)
local server_opcodes={
	["SMSG_SEND_COMBAT_TEXT"]=function(message, object, combat, positive_negative)
		CombatText.sendMessage(message, object, combat, positive_negative);
	end,
	["SMSG_SEND_CAST_REQUEST"]=function(player, spell, target, ...)
		local packet = Opcodes.FindServerPacket("SMSG_CAST_SPELL");
		if packet then packet:FireServer(spell, target, ...); end
	end,
	["SMSG_CAST_FAILED"]=function(spell, reason)
		if reason  == "global cooldown" or reason == "casting" then
			print("Spell is not ready yet.");
		elseif reason == "moving" then
			print("Can't do that while moving.");
		elseif reason == "mana" then
			print("You can't do that yet.");
		elseif reason == "disabled" then
			print("You can't do that yet.");
		elseif reason == "needs_target" then
			print("You have no target.");
		elseif reason == "dead_target" or reason == "invalid_target" then
			print("Invalid target.");
		elseif reason == "silenced" then
			print("You are silenced.");
		elseif reason == "dead" then
			print("You are dead.");
		elseif reason == "distance" then
			print("Out of range.");
		elseif reason == "facing" then
			print("You must face your target.");
		end
	end,
	["SMSG_UPDATE_TARGET"]=function(data)
		m_playerGUI:UpdateTarget(data);
	end,
	["SMSG_UPDATE_STAT"]=function(data)
		local target = data.Target
		local health = data.Health
		local maxHealth = data.MaxHealth
		if target == m_playerGUI:GetTarget() then
			local stat = data.Stat
			if stat == "Health" then
				local bar=pGUI.MainGui.Frame.Target.HealthBar
				bar.Size=UDim2.new(0,(health/maxHealth)*200,0,20)
			elseif stat == "Mana" then
				local bar = pGUI.MainGui.Frame.Target.ManaBar
				bar.Size=UDim2.new(0,(health/maxHealth)*200,0,20)
			end
		end
		if target == player then
			local stat = data.Stat
			if stat == "Health" then
				local bar = pGUI.MainGui.Frame.Player.HealthBar
				bar.Size = UDim2.new(0, (health/maxHealth)*200, 0, 20);
			elseif stat == "Mana" then
				local bar = pGUI.MainGui.Frame.Player.ManaBar
				bar.Size = UDim2.new(0, (health/maxHealth)*200, 0, 20);
			end
		end
	end,
	["SMSG_INIT_DUEL"]=function(data)
		local caster = data.Initiator
		local target = data.Target;
		if target == player then
			-- We are the target of the duel, ask if we want to accept or decline
			m_playerGUI:AskDuel(caster);
		end
	end,
	["SMSG_CHAR_LIST"]=function(data)
		local list = data.List;
		
		-- Disable Character creation if max chars are made
		if #list == 6 then
			m_playerGUI:DisableCharCreation();
		else
			m_playerGUI:EnableCharCreation();
		end
		
		m_playerGUI:DisplayCharacters(list);
	end,
}

--------------------------------------------------

mouse.KeyDown:connect(function(keycode)
	for _,v in next,player:findFirstChild'Backpack'["Spell List"]:GetChildren() do
		if v.Name == tostring(keycode) then
			local spell = game:service'Lighting'.Spells:findFirstChild(tostring(v.Value))
			local packet=Opcodes.FindServerPacket("CMSG_CAST_SPELL");
			packet:FireServer(spell);
		end
	end
end)

---------------------------------------------------------

function OnChatted(msg)
	if msg then
		local packet=Opcodes.FindServerPacket("CMSG_CHATMESSAGE_SAY");
		packet:FireServer(msg);
	end
end

player.Chatted:connect(OnChatted);

----------------------------------------------------------------

-- Build packet and invoke it
function PlayerMoveFreefall(active)
	if not active then
		local packet=Opcodes.FindServerPacket("CMSG_MOVE_FALL_LAND");
		packet:FireServer(active);
	end
end
---------------------------------------------------------
character.Humanoid.FreeFalling:connect(PlayerMoveFreefall);

-- Build packet and invoke it
function PlayerMoveJump(active)
	if active then
		local packet=Opcodes.FindServerPacket("CMSG_MOVE_JUMP");
		packet:FireServer(active);
	end
end
---------------------------------------------------------
character.Humanoid.Jumping:connect(PlayerMoveJump);

-----------------------------------------------------------

function MyCastFailed2(...)
	ParseServerPacket(game:service'ReplicatedStorage'["SMSG_CAST_FAILED"],...);
end

game:service("ReplicatedStorage"):WaitForChild("SMSG_CAST_FAILED").OnClientEvent:connect(MyCastFailed2);


----------------------------------------------------------------------------


local CombatText = require(workspace.CombatText);

function ParseServerPacket(p,...)
	if p then
		if server_opcodes[p.Name] then
			server_opcodes[p.Name](...);
		end
	end
end

function MyCastFailed1(...)
	ParseServerPacket(game:service'ReplicatedStorage'["SMSG_SEND_COMBAT_TEXT"],...);
end

function UpdateTarget(...)
	ParseServerPacket(game:service'ReplicatedStorage'["SMSG_UPDATE_TARGET"],...);
end

function UpdateStat(...)
	ParseServerPacket(game:service'ReplicatedStorage'["SMSG_UPDATE_STAT"], ...)
end

function InitDuel(...)
	ParseServerPacket(game:service'ReplicatedStorage'["SMSG_INIT_DUEL"], ...);
end

function GetCharList(...)
	ParseServerPacket(game:service'ReplicatedStorage'["SMSG_CHAR_LIST"], ...);
end

game:service("ReplicatedStorage"):WaitForChild("SMSG_UPDATE_STAT").OnClientEvent:connect(UpdateStat)
game:service("ReplicatedStorage"):WaitForChild("SMSG_SEND_COMBAT_TEXT").OnClientEvent:connect(MyCastFailed1);
game:service("ReplicatedStorage"):WaitForChild("SMSG_UPDATE_TARGET").OnClientEvent:connect(UpdateTarget)
game:service("ReplicatedStorage"):WaitForChild("SMSG_INIT_DUEL").OnClientEvent:connect(InitDuel)
game:service("ReplicatedStorage"):WaitForChild("SMSG_CHAR_LIST").OnClientEvent:connect(GetCharList)
--------------------------------------------------------------------------
function HandleCastRequest(...)
	ParseServerPacket(game:service'ReplicatedStorage'["SMSG_SEND_CAST_REQUEST"],...);
end

game:service("ReplicatedStorage"):WaitForChild("SMSG_SEND_CAST_REQUEST").OnClientEvent:connect(HandleCastRequest);

------------------------------------------------------------------------------------------------------
--SMSG_SPELL_GO
local next=next
local pcall=pcall
local player=game.Players.LocalPlayer
local character=player.Character
local rs=game:service'ReplicatedStorage';
local target = player:WaitForChild'Backpack':waitForChild'Target';
local SVH = require(workspace.SpellVisualHandler);
local SpellQueue = require(workspace.SpellQueue);

function cast(data)
	local CastFlags = data.CastFlags;
	local Target = data.Target;
	local CastTime = data.CastTime;
	local Extra = data.Extra;
	local Spell = data.Spell;
	local SpellTime = data.SpellTime;
	local ManaCost = data.ManaCost;
	local IsSpellQueueSpell = data.IsSpellQueueSpell;
	local Caster = data.Caster;
	if Caster == player then
		--if Unit.IsAttackable(player, Target) and Spell.PositiveNegative.Value == true then
		--	Target = player;
		--end
		m_playerGUI:SetOnCooldown(Spell)
	end
	local newAnimation = require(script.SpellAnimationHandler).new(Caster, Target, Spell)
	newAnimation:Cast()
	local anim = require(Caster.Backpack.Scripts.AnimationHandler)
	anim.Finish(Spell);
	SVH.EndSpellVisual(Caster);
end

game:service("ReplicatedStorage"):WaitForChild("SMSG_SPELL_GO").OnClientEvent:connect(cast);

---------------------------------------------------------------------------------------------
-- SMSG_SPELL_START
local player=game.Players.LocalPlayer
local character=player.Character
local rs=game:service'ReplicatedStorage';
local target = player:WaitForChild'Backpack':waitForChild'Target';

function CastSpell(data)
	local CastFlags = data.CastFlags;
	local Target = data.Target;
	local Player = data.Player;
	local CastTime = data.CastTime;
	local Extra = data.Extra;
	local m_spellInfo = data.Spell;
	local ManaCost = data.ManaCost;
	local IsSpellQueueSpell = data.IsSpellQueueSpell;
	local Caster = data.Caster;
	local anim = require(Caster.Backpack.Scripts.AnimationHandler)
	anim.CastSpell(target, m_spellInfo);
	SVH.CastSpellVisual(Caster, m_spellInfo);
	if Caster == player then
		--AnimationHandler.CastSpellVisual(m_spellInfo);

		-- Check for Mouse-Targeted AoE Spell
		if m_spellInfo.SpellFlags:findFirstChild'SPELL_FLAG_MOUSE_TARGET' then
			m_playerGUI:CastPlacementSpell(m_spellInfo);
			return;
		end

		if not m_spellInfo.SpellFlags:findFirstChild'SPELL_FLAG_IGNORES_GCD' then
			m_playerGUI:SetOnGCD();
		end
		if CastTime > 0 then
			m_playerGUI:SetCasting()
			m_playerGUI:UpdateSpell(m_spellInfo)
			if (target.Value == player) then
				m_playerGUI:CastTargetSpell(m_spellInfo);
			end
		end
	elseif target.Value ~= nil and CastTime ~= 0 then
		m_playerGUI:CastTargetSpell(m_spellInfo);
	end
end

game:service("ReplicatedStorage"):WaitForChild("SMSG_SPELL_START").OnClientEvent:connect(CastSpell);

--Update Aura
function UpdateAura(data)
	local caster = data.Caster
	local target = data.Target
	local auraInfo = data.AuraInfo
	local Key = data.Key
	--print(Key);
	if target == m_playerGUI:GetTarget() then -- Update target frame if local player is targetting the data.target
		m_playerGUI:UpdateAura(caster, target, auraInfo, Key, "target");
	end
	
	if target == player then -- Update local player aura list if target is local player
		m_playerGUI:UpdateAura(caster, target, auraInfo, Key, "player")
	end
	
	if caster == player then
		m_playerGUI:UpdateAura(caster, target, auraInfo, Key, "player")
	end
end

game:service("ReplicatedStorage"):WaitForChild("SMSG_AURA_UPDATE").OnClientEvent:connect(UpdateAura);

--UPDATE TARGET
local next=next
local pcall=pcall
local player = game.Players.LocalPlayer
local mouse = player:GetMouse();
local unitstate = player.Backpack.UnitState;
local MainGui = player.PlayerGui.MainGui;
local ContextActionService = game:GetService("ContextActionService")
local FREEZE_ACTION = "freezeMovement"
-------------------------

mouse.Button1Down:connect(function()
	local target=mouse.Target
	if target and target.Parent.className=="Model" then
		for _,v in next,target.Parent:GetChildren() do
			if v.Name=="NPC Value" then
				local tarGui=player.PlayerGui.MainGui.Frame.Target
				local packet=Opcodes.FindServerPacket("CMSG_UPDATE_TARGET");
				packet:FireServer(target.Parent);
				tarGui.Visible=true
			elseif game.Players:GetPlayerFromCharacter(target.Parent) then
				local tarGui = player.PlayerGui.MainGui.Frame.Target;
				local packet = Opcodes.FindServerPacket("CMSG_UPDATE_TARGET");
				packet:FireServer(game.Players:GetPlayerFromCharacter(target.Parent));
				tarGui.Visible = true;
			end
		end
	end
	local TargetOptions = MainGui.Frame.Target.NameBar.TextButton.TargetOptions;
	if TargetOptions.Visible == true then
		TargetOptions.Visible = false;
	end
end)

game:service'RunService'.RenderStepped:connect(function(deltaTime)
	if unitstate.Value == "UNIT_STATE_STUNNED" then
		ContextActionService:BindAction(
			FREEZE_ACTION,
			function() return Enum.ContextActionResult.Sink end,
			false,
			unpack(Enum.PlayerActions:GetEnumItems())
		)
	else
		ContextActionService:UnbindAction(FREEZE_ACTION)
	end
end)

