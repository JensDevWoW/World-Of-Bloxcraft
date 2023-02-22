local Opcodes = require(workspace.Opcodes);
local Database = require(workspace.DatabaseHandler);
local Player = require(workspace.Player)
local Spell = require(workspace.Spell)
local Aura = require(workspace.Spell.Aura)
local Duel = require(workspace.DuelHandler);
local Unit = {
	TypeIds = {
		TYPEID_PLAYER = 1;
		TYPEID_UNIT = 2;
		TYPEID_CREATURE = 3;	
	}
};
Unit.__index = Unit

function Unit.new(link, typ, world, Name)
	local new_unit = {}
	setmetatable(new_unit, Unit)
	
	new_unit.world = world;
	new_unit.Name = Name;
	new_unit.link = link
	new_unit.typ = typ
	new_unit.m_player = nil
	new_unit.m_silenced = false
	new_unit.flags = {}
	new_unit.m_alive = true
	new_unit.m_casting = false
	new_unit.m_Health = 100
	new_unit.m_maxHealth = 100
	new_unit.m_Mana = 100
	new_unit.m_maxMana = 100
	new_unit.m_unitState = "NONE"
	new_unit.m_spellList = {}
	new_unit.m_gcdTime = 0
	new_unit.m_Spell = nil
	new_unit.target = nil
	new_unit.m_debuffs = {}
	new_unit.m_buffs = {}
	new_unit.m_isMoving = false
	new_unit.m_Mana = 100
	new_unit.m_MaxMana = 100
	new_unit.m_Head = nil
	new_unit.m_auraList = {}
	new_unit.m_creature = nil
	new_unit.m_combatList = {} -- List of units the player is in combat with, if empty, player leaves combat after 3 seconds
	new_unit.m_combatTimer = 0;
	new_unit.m_duel = nil;
	new_unit.m_manaTickTimer = 1;
	new_unit.m_manaTickAmount = 3;
	new_unit.m_manaTickAmountCombat = 1;
	
	if new_unit.link:IsA("Player") then
		new_unit.m_Head = new_unit.link.Character.Head
		new_unit.m_player = Player.new(link, link.Character, nil, new_unit)
	else
		new_unit.m_Head = new_unit.link.Head
	end
	
	if new_unit.typ == "Creature" then
		-- Must have creature script
		local fol = Database.Access("world", "creature_template", new_unit.link.Name);
		if fol then
			local creature_script = fol.CreatureScript.Value
			local creature = require(creature_script)
			local new_creature = creature.new(new_unit)
			new_unit.m_creature = new_creature;
		end
	end
	
	new_unit.stats = {
		["stamina"] = 1000,
		["strength"] = 10,
		["speed"] = 10,
		["intellect"] = 50,
		["agility"] = 10
	}
	new_unit.m_availableSpells = {
		[1] = {
			["m_spellId"] = 5, ["m_spellTime"] = 1, ["m_cooldownTime"] = 0
		},
		[2] = {
			["m_spellId"] = 1, ["m_spellTime"] = 1, ["m_cooldownTime"] = 0
		},
		[3] = {
			["m_spellId"] = 2, ["m_spellTime"] = 1, ["m_cooldownTime"] = 0
		},
		[4] = {
			["m_spellId"] = 8, ["m_spellTime"] = 1, ["m_cooldownTime"] = 0
		},
		[5] = {
			["m_spellId"] = 10, ["m_spellTime"] = 0, ["m_cooldownTime"] = 0
		},
		[6] = {
			["m_spellId"] = 9, ["m_spellTime"] = 1, ["m_cooldownTime"] = 0
		},
		[7] = {
			["m_spellId"] = 25, ["m_spellTime"] = 1, ["m_cooldownTime"] = 0
		}
	}
	
	return new_unit
end

function Unit:GetSpell(spellId)
	-- Gets spell from m_availableSpells
	for _,v in next,self.m_availableSpells do
		if v.m_spellId == spellId then
			return v
		end
	end
end

function Unit:IsInCombat()
	return self.m_combatTimer > 0;
end

function Unit:IsHostile(target)
	-- Players in Duel
	if self:ToPlayer() ~= nil and target:ToPlayer() ~= nil then
		if self:ToPlayer():IsInDuel(target:ToPlayer()) then
			return true;
		end
	end
	
	if self:GetFactionId() ~= target:GetFactionId() then
		return true
	end
	return false;
end

function Unit:GetFactionId()
	if self:ToPlayer() ~= nil then
		local tab, fact = Database.Access("characters", "character", self.link.Name, self.Name);
		local fac = fact[1].factionID;
		return fac.Value;
	else
		local tab, fact = Database.Access("world", "creature_template", self.link.Name, "factionID");
		local fac = fact[1];
		return fac.Value;
	end
end

function Unit:SetInCombat()
	self.m_combatTimer = 6;
end

function Unit:DropCombat()
	self.m_combatTimer = 0;
end

function Unit:Update(m_time)
	
	if self:GetHealth() <= 0 then
		self:SetHealth(0);
		self.m_alive = false;
		self:StopCasting();
		--TODO: Remove auras on death;
		if self.m_creature ~= nil then
			self.m_creature:Died();
		end
	end
	
	if self:ToPlayer() ~= nil then
		self:ToPlayer():Update(m_time)
	end
	
	if self.m_gcdTime > 0 then
		self.m_gcdTime = self.m_gcdTime - m_time
	else
		self.m_gcdTime = 0
	end
	
	
	for _,v in next,self.m_spellList do --TODO: Add key for spell to be removed from m_spellList once completed
		if v ~= nil then
			v:Update(m_time)
		end
	end
	
	-- Update Cooldowns
	for i = 1, #self:GetSpellList() do
		local v = self.m_availableSpells[i]
		if v["m_cooldownTime"] > 0 then
			v["m_cooldownTime"] = v["m_cooldownTime"] - m_time
		else
			v["m_cooldownTime"] = 0;
		end
	end
	
	-- Update Auras
	for _,v in next,self.m_auraList do
		v:Update(m_time)
	end
	
	if self.m_creature ~= nil then
		self.m_creature:Update(m_time);
	end
	
	-- Mana Regen
	if self:GetMana() < self:GetMaxMana() then
		if self.m_manaTickTimer > 0 then
			self.m_manaTickTimer = self.m_manaTickTimer - m_time
		else
			if self:IsInCombat() then
				if (self:GetMana() + self.m_manaTickAmountCombat) < self:GetMaxMana() then -- Check if mana amount tick is more less than their max mana(don't want to go over max)
					self:SetMana(self:GetMana() + self.m_manaTickAmountCombat);
				else
					self:SetMana(self:GetMaxMana())
				end
			else
				if (self:GetMana() + self.m_manaTickAmount) < self:GetMaxMana() then -- Same thing as above just for tick amount outside of combat
					self:SetMana(self:GetMana() + self.m_manaTickAmount);
				else
					self:SetMana(self:GetMaxMana())
				end
			end
			self.m_manaTickTimer = 1;
		end
	end
	
	--Handle Combat
	if self:IsInCombat() then
		if #self.m_combatList > 0 then
			for i,v in next,self.m_combatList do
				if v:IsAlive() == false then
					table.remove(self.m_combatList, i);
				end
			end
			if #self.m_combatList == 0 then
				self:DropCombat();
			end
		end
		self.m_combatTimer = self.m_combatTimer - m_time;
		if self.m_combatTimer <= 0 then
			self:DropCombat();
			print("Out of combat!");
		end
	end
end

function Unit:GetSpellList()
	return self.m_availableSpells
end

function Unit:SetInCombatWith(unit)
	self:SetInCombat()
	unit:SetInCombat()
	table.insert(self.m_combatList, unit)
	table.insert(unit.m_combatList, self);
end

function Unit:SpellCooldown(spell)
	local spellId = tonumber(spell.Name)
	local currentSpell = self:GetSpell(spellId)
	if currentSpell ~= nil then
		currentSpell.m_cooldownTime = spell.CooldownValue.Value
	else
		error("Couldn't find spell when setting cooldown!")
	end
end

function Unit:UpdateTargetData(new_target)
	self.link = new_target
	if new_target:IsA("Player") then
		self.typ = "Player"
	else
		self.typ = "Creature"
	end
end

function Unit:IsOnGCD()
	return self.m_gcdTime > 0
end

function Unit:GetGCD()
	return self.m_gcdTime
end

function Unit:BuildSpell(spell, target, isSpellQueue)
	local new_spell = Spell.new(self, spell, target, isSpellQueue)
	table.insert(self.m_spellList, new_spell)
	return new_spell
end

function Unit:ToSpell()
	return self.m_Spell
end

function Unit.GetTypeID(unit)
	if unit then
		return unit.Backpack.TypeID.Value;
	end
end

function Unit:AddAura(spell)
	if not spell then error("No spell found!") return nil end;
	-- First check if aura already exists, if it does then refresh the duration
	for _,v in next,self.m_auraList do
		if v.spell.link == spell.link then
			v:RefreshDuration();
			return;
		end
	end
	local key = #self.m_auraList + 1;
	local aura = Aura.new(spell, key);
	table.insert(self.m_auraList, aura);
end

function Unit:CastSpell(spell, target)
	if not target then return false end; -- Should never happen
	if not spell then return false end; -- Should never happen
	if typeof(spell) == "number" then
		spell = game.Lighting.Spells:findFirstChild(tostring(spell));
	end
	local newSpell = self:BuildSpell(spell, target, false)
	newSpell:Prepare();
end

function Unit:AddSelfAura(spellId)
	local spell;
	for _,v in next,game.Lighting.Spells:GetChildren() do
		if v.Name == tostring(spellId) then
			spell = v;
			break
		end
	end
	
	if not spell then
		error("Spell not found!")
		return;
	end
	
	local spellInfo = Spell.new(self, spell, self, false)
	local aura = Aura.new(spellInfo)
	table.insert(self.m_auraList, aura);
	
end

function Unit:ToPlayer(unit)
	if self.link:IsA("Player") then
		return self.m_player
	else
		return nil
	end
end

function Unit:IsMoving()
	return self.m_isMoving
end

Unit.IsCastingAnimation = function(unit)
	if unit then
		if unit:IsA("Player") then
			unit = unit.Character;
		end
		if unit:findFirstChild'Humanoid' then
			local tracks = unit.Humanoid:GetPlayingAnimationTracks();
			for _,v in next,tracks do
				if v.Name == "SpellAnimation: 1" or v.Name == "SpellAnimation: 2" or v.Name == "SpellAnimation: 3" or v.Name == "SpellAnimation: 4" then
					return true
				end
			end
		end
		return false;
	end
	return false;
end

Unit.GetCastingAnimation = function(unit)
	if unit then
		if unit:IsA("Player") then
			unit = unit.Character;
		end
		if unit:findFirstChild'Humanoid' then
			local tracks = unit.Humanoid:GetPlayingAnimationTracks();
			for _,v in next,tracks do
				if v.Name == "SpellAnimation: 1" or v.Name == "SpellAnimation: 2" or v.Name == "SpellAnimation: 3" or v.Name == "SpellAnimation: 4" then
					return v;
				end
			end
		end
	end
	return nil;
end

Unit.ClearPlayingAnimation = function(unit)
	if unit then
		if unit:IsA("Player") then
			unit = unit.Character;
		end
		if unit:findFirstChild'Humanoid' then
			for _,v in next,unit.Humanoid:GetPlayingAnimationTracks() do
				if v.Name == "SpellAnimation" then
					v:Stop();
				end
			end
		end
	end
end

function Unit:SetOnGCD()
	if self.m_gcdTime == 0 then
		self.m_gcdTime = 1.5
	end
end

function Unit:SetCasting()
	self.m_casting = true
end

function Unit:IsCasting()
	return self.m_casting
end

Unit.GetStats = function(unit)
	if unit then
		if unit:findFirstChild'Backpack' then
			return unit.Backpack:findFirstChild'Stats';
		end
	end
end

Unit.IsFacingTarget = function(unit, target)
	if not target then return true end;
	
	if unit:IsA("Player") then
		unit = unit.Character;
	end
	
	if target:IsA("Player") then
		target = target.Character;
	end
	
	local facing = unit.HumanoidRootPart.CFrame.lookVector;
	local vector = (target.HumanoidRootPart.Position - unit.HumanoidRootPart.Position).unit
	local angle = math.acos(facing:Dot(vector))
	
	if math.deg(angle) < 90 then
		return true
	else
		return false;
	end
end

function Unit:HasTarget()
	return self:GetTarget() ~= nil
end

function Unit:IsSilenced()
	return self.m_silenced
end

function Unit:HasFlag(flag)
	for _,v in next,self.flags do
		if v.Name == flag then
			return true
		end
	end
	return false
end

function Unit:IsEnemy(unit)
	if unit then
		if unit:GetFactionId() ~= self:GetFactionId() then
			return true
		end
	end
end

function Unit:IsAlive()
	if self.m_alive == false then
		return false
	else
		return true
	end
end

function Unit:GetFlags()
	return self.flags
end

function Unit:StopCasting()
	self.m_casting = false
end

function Unit:GetTarget()
	return self.target
end

function Unit:IsWithinLOS(target)
	local caster = self.link
	if caster:IsA("Player") then
		caster = caster.Character;
	end
	local target = target.link
	if target:IsA("Player") then
		target = target.Character;
	end
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {caster, target}
	params.FilterType = Enum.RaycastFilterType.Blacklist
	local casterHead = caster.HumanoidRootPart
	local targetHead = target.HumanoidRootPart
	local rayOrigin = casterHead.Position
	local rayDirection = targetHead.Position
	local result = workspace:Raycast(rayOrigin, (rayDirection - rayOrigin), params)
	if result == nil then
		return true;
	end
	return false;
end

function Unit:SelectNearbyTarget(exclude, dist)
	local list = self.world:GetNearestUnitsFromUnit(self, dist)
	
	if #list == 0 then
		return nil
	end
	
	-- remove current target
	for i,v in next,list do
		if v == self.target then
			table.remove(list, i)
		end
		
		if v == exclude then
			table.remove(list, i)
		end
		
		--TODO: Remove LoS targets
	end
	
	local rand = math.random(1, #list)
	return list[rand];
	
end

function Unit:IsPlayer()
	return Unit:ToPlayer() ~= nil
end

function Unit:HasAura(aura)
	for _,v in next,self.m_auraList do
		if v.spellId == aura.spellId then
			return true
		end
	end
	return false
end

function Unit:GetAura(aura)
	for _,v in next,self.m_auraList do
		if v.spellId == aura.spellId then
			return v
		end
	end
	return nil
end

function Unit:RemoveAura(aura)
	for _,v in next,self.m_auraList do
		if v.spellId == aura.spellId then
			table.remove(self.m_auraList, v)
		end
	end
end

function Unit:GetNegativeAuraList()
	local list = {}
	for _,v in next,self.m_auraList do
		if v.typ == "debuff" then
			table.insert(list, v)
		end
	end
	return list
end

function Unit:SetHealth(val)
	self.m_Health = val
end

function Unit:SetMana(val)
	self.m_Mana = val
	local data,packet = {},Opcodes.FindClientPacket("SMSG_UPDATE_STAT")
	data.Target = self.link
	data.Health = self:GetMana(); -- Naming health cause it's easier
	data.MaxHealth = self:GetMaxMana();
	data.Stat = "Mana"
	Opcodes.SendMessageToSet(self.link, packet, data)
end

function Unit:GetMana()
	return self.m_Mana
end

function Unit:GetMaxMana()
	return self.m_MaxMana
end

function Unit:GetStats()
	return self.stats
end

function Unit:GetHealth()
	return self.m_Health
end

function Unit:GetStat(stat)
	return self:GetStats()[stat];
end

function Unit:SpellDamageBonusDone(victim, spell)
	--TODO: Add damage type and spell attribute SPELL_ATTR3_INGORE_CASTER_MODIFIERS
	
	local DoneTotal = 0;
	local DoneTotalMod = self:SpellDamagePctDone(spell) --TODO: Add this
	
	-- Get fixed damage bonus auras
	--local DoneAdvertisedBenefit = self:SpellBaseDamageBonusDone() --TODO: Add this
	
	--TODO: Add SPELL_AURA_MOD_DAMAGE_TAKEN aura
	
	-- Default Calculation
	DoneTotal = DoneTotal + math.random(spell:GetAmount(), spell:GetAmount() * 1.5);
	print(DoneTotal);
	-- Modifiers
	local damageClass = spell:GetDamageClass()
	if damageClass == "Intellect" then
		local int = self:GetStat("intellect")
		--local damage = math.floor(math.random(damageEstimation + (int/4), damageEstimation + (int/3.5)));
		DoneTotal = math.floor(math.random(DoneTotal + (int/4), DoneTotal + (int/3.5)))
		if spell:IsDoT() then
			DoneTotal = math.floor(DoneTotal * 0.25);
		end
	elseif damageClass == "Strength" then
		local str = self:GetStat("strength")
		
		DoneTotal = math.floor(math.random(DoneTotal + (str/10), DoneTotal + (str/9)))
		if spell:IsDoT() then
			DoneTotal = math.floor(DoneTotal * 0.25);
		end
	end
	
	local tmpDamage = DoneTotal * DoneTotalMod;
	return tmpDamage;
end

function Unit:SpellDamagePctDone(spell)
	--TODO: Check direct damage type, return 1;
	--TODO: Check SPELL_ATTR3_IGNORE_CASTER_MODIFIERS, return 1;
	--TODO: Check SPELL_ATTR6_IGNORE_CASTER_DAMAGE_MODIFIERS, return 1;
	
	local DoneTotalMod = 1;
	
	--TODO: Add pet damage
	
	--TODO: Add particular stat modifier
	
	local maxModDamagePercentSchool = 1;
	if self:ToPlayer() ~= nil then
		local player = self:ToPlayer()
		maxModDamagePercentSchool = player:GetModDamageDonePercent(spell:GetSchool())
	end
	
	DoneTotalMod = DoneTotalMod * maxModDamagePercentSchool
	
	return DoneTotalMod;
end

function Unit:DealDamage(spell, target)
	if spell and target then
		local m_spellInfo = spell.spell
		if m_spellInfo then
			local stats = target:GetStats()
			local spellType = m_spellInfo.DamageClass.Value;
			if spellType == "Intellect" then
				local int = stats["intellect"]
				local damage = self:SpellDamageBonusDone(target, spell)
				local packet = Opcodes.FindClientPacket("SMSG_SEND_COMBAT_TEXT")
				local packet2 = Opcodes.FindClientPacket("SMSG_UPDATE_STAT")
				if spell.m_posneg == false then
					if target:GetHealth() - damage > 0 then
						target:SetHealth(target:GetHealth() - damage)
					else
						target:SetHealth(0);
					end
					local data = {}
					data.Stat = "Health"
					data.Health = target:GetHealth()
					data.MaxHealth = target:GetMaxHealth();
					data.Target = target.link;
					
					Opcodes.SendMessageToSet(self.link, packet2, data);
					if self.link:IsA("Player") then
						packet:FireClient(self.link, damage, target.m_Head, false, false)
					end
				else
					if target:GetHealth() + damage < target:GetMaxHealth() then
						target:SetHealth(target:GetHealth() + damage)
					else
						target:SetHealth(target:GetMaxHealth());
					end
					local data = {}
					data.Stat = "Health"
					data.Health = target:GetHealth()
					data.MaxHealth = target:GetMaxHealth();
					data.Target = target.link;
					
					Opcodes.SendMessageToSet(self.link, packet2, data);
					if self.link:IsA("Player") then
						packet:FireClient(self.link, damage, target.m_Head, false, true)
					end
				end
			elseif spellType == "Strength" then
				local int = stats["strength"]
				local damage = self:SpellDamageBonusDone(target, spell)
				local packet = Opcodes.FindClientPacket("SMSG_SEND_COMBAT_TEXT")
				local packet2 = Opcodes.FindClientPacket("SMSG_UPDATE_STAT")
				if spell.m_posneg == false then
					if target:GetHealth() - damage > 0 then
						target:SetHealth(target:GetHealth() - damage)
					else
						target:SetHealth(0);
					end
					local data = {}
					data.Stat = "Health"
					data.Health = target:GetHealth()
					data.MaxHealth = target:GetMaxHealth();
					data.Target = target.link;

					Opcodes.SendMessageToSet(self.link, packet2, data);
					if self.link:IsA("Player") then
						packet:FireClient(self.link, damage, target.m_Head, false, false)
					end
				else
					if target:GetHealth() + damage < target:GetMaxHealth() then
						target:SetHealth(target:GetHealth() + damage)
					else
						target:SetHealth(target:GetMaxHealth());
					end
					local data = {}
					data.Stat = "Health"
					data.Health = target:GetHealth()
					data.MaxHealth = target:GetMaxHealth();
					data.Target = target.link;

					Opcodes.SendMessageToSet(self.link, packet2, data);
					if self.link:IsA("Player") then
						packet:FireClient(self.link, damage, target.m_Head, false, true)
					end
				end
			end
			
			
		end
	end
end

Unit.GetNearestEnemies=function(player, pos)
	local enemiesList={}
	for _,v in next,workspace:GetChildren() do
		if v:IsA("Model") then
			if (v:findFirstChild'NPC Value' or game.Players:GetPlayerFromCharacter(v)) and Unit.IsAttackable(player, v) then
				local distance = (pos - v:WaitForChild'Head'.Position).magnitude;
				if distance < 20 then
					table.insert(enemiesList, v);
				end
			end
		end
	end
	return enemiesList;
end

function Unit:SetMaxHealth(value)
	self.m_maxHealth = value
end

function Unit:SetStat(stat, val)
	self.stats[stat] = val
end

Unit.HandleStatChanged = function(unit, stat, value)
	
end

function Unit:UpdateTarget(target)
	if target then
		if typeof(target) ~= "table" then
			local targetObj = self.world:GetUnit(target);
			if targetObj then
				target = targetObj
			end
		end
		self.target = target
		local data = {}
		data.link = target.link
		data.m_silenced = target.m_silenced
		data.flags = target.flags
		data.m_alive = target.m_alive
		data.m_casting = target.m_casting
		data.m_Health = target.m_Health
		data.m_maxHealth = target.m_maxHealth
		data.m_unitState = target.m_unitState
		data.m_Mana = target.m_Mana
		data.m_maxMana = target.m_MaxMana
		if self.link:IsA("Player") then
			local opcode = Opcodes.FindClientPacket("SMSG_UPDATE_TARGET")
			opcode:FireClient(self.link, data)
		end
	end
end

function Unit:GetState()
	return self.unitState
end

function Unit:HasState(state)
	return self.unitState == state
end

function Unit:SetState(state)
	self.unitState = state
end

function Unit:GetMaxHealth()
	return self.m_maxHealth
end

function Unit:InRange(target, range)
	local char;
	if self:ToPlayer() then
		char = self.link.Character
	else
		char = self.link
	end
	
	local tarchar;
	if target:ToPlayer() then
		tarchar = target.link.Character
	else
		tarchar = target.link
	end
	local head1 = char.HumanoidRootPart;
	local head2 = tarchar.HumanoidRootPart;
	if head1 and head2 then
		local distance = math.abs((head1.Position  - head2.Position).magnitude);
		if distance < range then
			return true
		else
			return false;
		end
	end
end

Unit.IsWithinRangeOfTarget = function(unit, target, range)
	if unit:IsA("Player") then
		unit = unit.Character;
	end
	if target:IsA("Player") then
		target = target.Character;
	end
	local head1 = unit.Head;
	local head2 = target.Head;
	if head1 and head2 then
		local distance = math.abs((head1.Position  - head2.Position).magnitude);
		if distance < range then
			return true
		else
			return false;
		end
	end
end

Unit.RunAnimation = function(unit, anim)
	if unit then
		if unit:IsA("Player") then
			unit = unit.Character;
			local hum = unit.Humanoid;
			local animID = anim.AnimationId;
			if animID and hum then
				local animation = Instance.new("Animation",unit)
				animation.Name = anim.Name;
				animation.AnimationId = animID;
				local newAnimation = hum:LoadAnimation(animation);
				newAnimation:Play();
				return true;
			end
		end
		if anim then
			local animID = anim.AnimationId;
			local controller = Instance.new("AnimationController",unit);
			if animID and controller then
				local animation = Instance.new("Animation",unit)
				animation.Name = anim.Name;
				animation.AnimationId = animID;
				local newAnimation = controller:LoadAnimation(animation);
				newAnimation:Play();
			end
		end
	end
end

function Unit.ReturnTypeIDList()
	return Unit.TypeIds;
end
return Unit
