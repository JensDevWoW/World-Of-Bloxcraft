local UI = {}
UI.__index = UI

local Database = require(workspace.DatabaseHandler)
local AH = require(script.Parent.MainGui.AuraHandler)
local m_time = game:service'RunService'.Heartbeat

function UI.new(player, player_frame, target_frame, actionbar, castbar, Login)
	local new_UI = {}
	setmetatable(new_UI, UI)
	
	new_UI.link = player
	new_UI.player_frame = player_frame
	new_UI.target_frame = target_frame
	new_UI.actionbar = actionbar
	new_UI.castbar = castbar
	new_UI.Login = Login
	new_UI.m_casting = false
	new_UI.DuelFrame = script.Parent.MainGui.Frame.DuelFrame
	new_UI.m_Spell = nil
	new_UI.m_isAlive = true
	new_UI.m_unitState = nil
	new_UI.m_isMoving = false
	new_UI.m_cbarProgress = 0
	new_UI.m_target = nil
	new_UI.m_targetAuraList = {}
	new_UI.m_playerAuraList = {}
	
	local ABH = require(new_UI.actionbar.ActionBarHandler)
	local button_set = ABH.new(actionbar, new_UI)
	
	new_UI.button_set = button_set
	
	return new_UI
end

function UI:DisplayCharacters(list)
	local leng = #list
	print(leng)
	self.Login.Frame.CharSet:ClearAllChildren();
	for i,v in next,list do
		if v:IsA("Folder") then
			local temp = self.Login.Frame.CharTemp:Clone()
			temp.Parent = self.Login.Frame.CharSet;
			temp.Name = v.Name
			temp.Position = UDim2.new(0, 0, 0, ((i-1)*100))
			local button = temp.TextButton
			button.Text = v.Name;
			temp.Visible = true;
			temp.LocalScript.Enabled = true;
		end
	end
end

function UI:GetTarget()
	return self.m_target;
end

function UI:EnableCharCreation()
	self.Login.Frame.CreateChar.Visible = true;
end

function UI:DisableCharCreation()
	self.Login.Frame.CreateChar.Visible = false;
end

function UI:AskDuel(target)
	if target then
		local tar_name = target.Name
		local frame = self.DuelFrame;
		frame.Visible = true
		frame.TextLabel.Text = target.Name.." has challenged you to a duel."
	end
end

function UI:UpdateTarget(data)
	local player = self.link
	local pGUI = player.PlayerGui
	local manaScript = pGUI.MainGui.Frame.Target.ManaBar.ManaScript
	pGUI.MainGui.Frame.Target.Visible = true;
	pGUI.MainGui.Frame.Target.Debuffs.DebuffFolder:ClearAllChildren();
	self.m_targetAuraList = {};
	coroutine.resume(coroutine.create(function()
		local CurrentHealth=data.m_Health
		local MaxHealth=data.m_maxHealth
		local bar=pGUI.MainGui.Frame.Target.HealthBar
		local maxSize=200
		local SizeX=bar.AbsoluteSize.X
		bar.Size=UDim2.new(0,(CurrentHealth/MaxHealth)*maxSize,0,20)
	end))
	manaScript.Disabled=true
	local CurrentMana=data.m_Mana
	local MaxMana=data.m_maxMana
	local bar=pGUI.MainGui.Frame.Target.ManaBar
	local maxSize=200
	local SizeX=bar.AbsoluteSize.X
	bar.Size=UDim2.new(0,(CurrentMana/MaxMana)*maxSize,0,20)
	manaScript.Disabled=false
	self.target_frame.Target.Value = data.link
	if data.link == nil then 
		self.target_frame.Visible = false;
		pGUI.MainGui.Frame.Target.Debuffs.BuffHandler.Disabled = true;
	else
		self.m_target = data.link
	end

	-- Update Name
	if data.link then
		local p = data.link
		if p:IsA("Player") then
			if p.Character.Humanoid then
				if p.Character:findFirstChild'Humanoid'.Health<=0 then
					pGUI.MainGui.Frame.Target.NameBar.TextButton.Text=p.Name.."(Dead)"
				else
					pGUI.MainGui.Frame.Target.NameBar.TextButton.Text=p.Name
				end
			end
		else
			if p.Humanoid.Health<=0 then
				pGUI.MainGui.Frame.Target.NameBar.TextButton.Text=p.Name.."(Dead)"
			else
				pGUI.MainGui.Frame.Target.NameBar.TextButton.Text=p.Name
			end
		end
	end
end

function UI:UpdateAura(caster, target, auraInfo, key, spot) -- checks if aura exists, if it does, update the data for the aura (duration, charges, etc.)
	if target == self.link then -- Check if aura is for the local player
		for _,v in next,self.m_playerAuraList do
			if v.key == key then
				v:UpdateInfo(auraInfo);
				return
			end
		end
	else -- Aura not for local player, must be for target
		for _,v in next,self.m_targetAuraList do
			if v.key == key then
				v:UpdateInfo(auraInfo);
				return
			end
		end
	end
	
	--Aura does not exist anywhere, make new one
	self:AddAura(caster, target, auraInfo, spot);
	
end

function UI:RemoveAura(where, key)
	if where == "target" then
		local aura = self.m_targetAuraList[key];
		if aura then 
			aura.link:Destroy(); 
			table.remove(self.m_targetAuraList, key);
		end;
	end
	if where == "player" then
		local aura = self.m_playerAuraList[key];
		if aura then
			aura.link:Destroy();
			table.remove(self.m_targetAuraList, key);
		end
	end
end

function UI:AddAura(caster, target, auraInfo, spot)
	if target ~= self.link then -- Check if aura is not for the local player
		local key = #self.m_targetAuraList + 1
		local new_aura = AH.new(self, auraInfo, key, spot)
		table.insert(self.m_targetAuraList, new_aura);
	else
		local key = #self.m_playerAuraList + 1
		local new_aura = AH.new(self, auraInfo, key, spot)
		table.insert(self.m_playerAuraList, new_aura);
	end
end

function UI:SetCasting()
	self.m_casting = true;
end

function UI:UpdateSpell(spell)
	self.m_Spell = spell
end

function UI:SetOnGCD()
	self.button_set:SetOnGCD()
end

function UI:SetOnCooldown(spell)
	local spellId = tonumber(spell.Name)
	local cdTime = spell.CooldownValue.Value
	for _,v in next,self.button_set.m_set do
		if spellId == v.spellId then
			v:SetOnCD();
		end
	end
end

function UI:Update(deltaTime)
	--[[Cast Bar]]--
	--local player = self.link
	if self.m_casting == true then
		local cbm = self.castbar.CastBarMain
		local cbc = cbm.CastBarCenter
		local ob = cbc.OrangeBar
		local tl = ob.TextLabel
		local scr = tl.HandleFade;
		scr.Disabled = true;
		local cancel = false;
		cancel = true;
		cbm.Visible=true;
		local castTime = self.m_Spell.CastTime.Value
		local rate = 1 / (castTime - 0.2); -- account for strange delay, need to find cause as it wasn't there before
		local SizeX=190
		local timePassed = 0;
		local numTimes = 0;
		local renderstepped;
		ob.Size = UDim2.new(0, 0, 0, 15);
		tl.TextTransparency = 0;
		ob.BackgroundTransparency = 0;
		cbc.BackgroundTransparency = 0;
		cbm.BackgroundTransparency = 0;
		tl.Text=self.m_Spell.SpellName.Value;
		ob.BackgroundColor3 = Color3.new(255, 170, 0);
		if self.m_cbarProgress >= 1 then
			self.m_cbarProgress = 1;
			cancel = false;
			--bar.Visible=false;
			scr.Disabled = false;
			ob.BackgroundColor3 = Color3.new(0,255,0);
			self.m_casting = false
			self.m_cbarProgress = 0;
		else
			ob.Size=UDim2.new(0,0,0,15):Lerp(UDim2.new(0,190,0,15),self.m_cbarProgress);
			self.m_cbarProgress = self.m_cbarProgress + (rate * deltaTime);
		end
	end
	
	--GCD
	self.button_set:Update(deltaTime)
	
	--Auras
	if #self.m_targetAuraList > 0 then
		for _,v in next,self.m_targetAuraList do
			if v.m_duration == 0 then
				self:RemoveAura(v.spot, v.key);
				continue;
			end
			v:Update(deltaTime);
		end
		
		for i = 1, #self.m_targetAuraList do
			if self.m_targetAuraList[i] then
				if i == 1 then
					self.m_targetAuraList[i].link.Position = UDim2.new(0, 0, 0, 0);
				else
					self.m_targetAuraList[i].link.Position = UDim2.new(0, 30*(i - 1), 0, 0);
				end
			end
		end
	end
	if #self.m_playerAuraList > 0 then
		for _,v in next,self.m_playerAuraList do
			if v.m_duration == 0 then
				self:RemoveAura(v.spot, v.key);
				continue;
			end
			v:Update(deltaTime);
		end

		for i = 1, #self.m_playerAuraList do
			if self.m_playerAuraList[i] then
				if i == 1 then
					self.m_playerAuraList[i].link.Position = UDim2.new(0, 0, 0, 0);
				else
					self.m_playerAuraList[i].link.Position = UDim2.new(0, 30*(i - 1), 0, 0);
				end
			end
		end
	end
	
end

function UI:GetActionSpells()
	return self.m_actionBarButtons
end

function UI:ToPlayer()
	return self.link
end

function UI:AddTargetDebuff(spell)
	if spell then
		local targetUI = self.target_frame;
		local Debuffs = targetUI.Debuffs;
		local debuffFolder = Debuffs.DebuffFolder;
		for _,v in next,debuffFolder:GetChildren() do
			if v and v.Name == spell.Name then
				v.Spell.Value = spell;
				return true;
			end
		end
		Debuffs.DebuffNum.Value = Debuffs.DebuffNum.Value + 1;
		local dbName = Debuffs.DebuffName;
		local newBuff = dbName:Clone();
		local tac1,tac2 = Database.Access("world", "spell_script_decals", spell.Name);
		newBuff.Name = spell.Name;
		newBuff.Spell.Value = spell;
		newBuff.Debuff.Image = tac1.Value;
		newBuff.Parent = debuffFolder;
		newBuff.SpotNum.Value = Debuffs.DebuffNum.Value;
		newBuff.Visible = true
		newBuff.Script.Disabled = false;
		Debuffs.Visible = true;
	end
end

function UI:AddPlayerDebuff(spell)
	-- TODO: Add this
end

function UI:AddTargetBuff(spell)
	-- TODO: Add this
end

function UI:AddPlayerBuff(spell)
	-- TODO: Add this
end

function UI:CastTargetSpell(spell)
	local player = self.link
	local castbar = player.PlayerGui:WaitForChild'MainGui':WaitForChild'Frame':WaitForChild'Target':WaitForChild'CastBarMain';
	if castbar then
		local cbarMain = castbar;
		local cbarScript = cbarMain.CastBarCenter.OrangeBar.TextLabel.RunBar;
		if cbarScript.Disabled == true then
			cbarScript.Disabled = false;
			return true;
		end
	end
	return false;
end

function UI:CastPlacementSpell(spell)
	local placementUI = game:service'ReplicatedStorage'.MousePos:Clone();
	placementUI.Parent = game.Players.LocalPlayer.Backpack;
	local ls = placementUI.LocalScript;
	ls.Disabled = false;
end

function UI:PushCooldown(spell)
	local player = self.link
	if player and spell then
		for _,v in next,player:findFirstChild'Backpack':findFirstChild'Spell List':GetChildren() do
			if tostring(v.Value) == spell.Name then
				spell = v;
			end
		end
		if player.PlayerGui:findFirstChild'ActionBar' then
			for _,v in next,player.PlayerGui:findFirstChild'ActionBar':findFirstChild'Set':GetChildren() do
				if v:IsA("Frame") then
					if v.Name == spell.Name then
						if v:findFirstChild'Cooldown' then
							v.Cooldown.Disabled = true;
							wait()
							v.Cooldown.Disabled = false;
						end
					end
				end
			end
		end
	end
end

function UI:PushSilenced()
	local player = self.link
	if player then
		if player.PlayerGui:findFirstChild'ActionBar' then
			for _,v in next,player.PlayerGui:findFirstChild'ActionBar':findFirstChild'Set':GetChildren() do
				if v:IsA("Frame") then
					if v:findFirstChild'Silenced' then
						v.Silenced.Disabled = false;
					end
				end
			end
		end
	end
end

return UI
