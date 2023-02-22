local Spell = { };
Spell.__index = Spell

local Spells = game.Lighting:WaitForChild'Spells':GetChildren()
local Opcodes = require(workspace.Opcodes);
local Database = require(workspace.DatabaseHandler);
--local Player = require();


--SPELL:
-- Each spell object is created when client sends CMSG_CAST_SPELL
-- Spell is prepared to be cast, sends SMSG_SPELL_START to client
-- Client then begins cast, once cast is finished, SMSG_SPELL_GO is sent
-- as server is also keeping track of cast time(so no cast-time cheat)
-- Client then casts spell and delay is begun for spell to hit target(1 second for regular casted spells, 0 seconds for dots and auras)
-- Server executes the spell once the timer has run out which does damage / healing / adds aura

-----------------------------------
--[[Variables]]--
local m_executedCurrently;
local SpellFlags = {
	SPELL_FLAG_EMPTY = 1;	
}
local SpellQueue = require(workspace.SpellQueue);
-----------------------------------

Spell.new = function(caster, spell, target, isSpellQueue)
	local new_spell = {}
	setmetatable(new_spell, Spell)
	
	new_spell.caster = caster
	new_spell.spell = spell
	new_spell.spellId = tonumber(spell.Name)
	new_spell.target = target
	new_spell.isSpellQueue = isSpellQueue
	new_spell.m_spellState = "SPELL_STATE_NONE"
	new_spell.m_spellFlags = {}
	new_spell.typ = nil
	new_spell.m_cooldownLeft = 0
	new_spell.m_spellTime = 1;
	new_spell.m_castTime = spell.CastTime.Value
	new_spell.m_cooldownValue = spell.CooldownValue.Value
	new_spell.m_posneg = spell.PositiveNegative.Value
	new_spell.m_duration = spell.AuraInfo.AuraDuration.Value
	new_spell.m_maxDuration = spell.AuraInfo.AuraDuration.Value
	new_spell.m_passive = false;
	new_spell.m_deathPersistent = false;
	new_spell.m_isPeriodic = spell.AuraInfo.Periodic.Value
	new_spell.m_auraType = spell.AuraInfo.AuraType.Value
	new_spell.m_damageClass = spell.DamageClass.Value
	new_spell.m_school = spell.SpellSchoolMask.Value
	new_spell.m_amount = spell.BasePoints.Value;
	new_spell.m_timeBetweenTicks = spell.AuraInfo.TickSlot.Value
	new_spell.m_effect = spell.SpellEffect.Value
	new_spell.m_hasSpellAura = spell.AuraInfo.HasSpellAura.Value
	new_spell.m_hasTimer = spell.AuraInfo.HasTimer.Value;
	
	-- Load in spell flags
	for _,v in next,spell.SpellFlags:GetChildren() do
		table.insert(new_spell.m_spellFlags, v.Name)
	end
	
	return new_spell
end

--[[

class Spell:
	def __init__(self, link, target, isSpellQueue):
		self.link = link
		self.target = target
		self.isSpellQueue = isSpellQueue
	def GetCharLink():
		return self.charLink;
	def GetSpell():
		return self
		
class Aura(Spell):
	
lol = Aura();

lol:GetSpell() -> returns Spell object

]]

function Spell:GetCharLink()
	return self.charLink;
end

function Spell:IsDoT()
	return self.m_isPeriodic;
end

function Spell:HasSpellAura()
	return self.m_hasSpellAura;
end

function Spell:GetEffect()
	return self.m_effect;
end

function Spell:GetTimeBetweenTicks()
	return self.m_timeBetweenTicks
end

function Spell:GetAmount()
	return self.m_amount;
end

function Spell:GetDamageClass()
	return self.m_damageClass;
end

function Spell:SetState(state)
	self.m_spellState = state
end

function Spell:GetState()
	return self.m_spellState
end

function Spell:IsPassive()
	return self.m_passive
end

function Spell:GetSchool()
	return self.m_school;
end

function Spell:IsDeathPersistent()
	return self.m_deathPersistent
end

function Spell:Cast()
	if not self.caster then return end
	if not self.spell then return end
	if self.spell:IsA("ObjectValue") then
		self.spell = self.spell.Value
	end
	local newTarget = self:SelectSpellTargets();
	self:Go();
	self:Execute();
end

function Spell:Start()
	local data,packet = {},Opcodes.FindClientPacket("SMSG_SPELL_START");
	data.CastFlags = self:GetFlags()
	data.Caster = self.caster.link;
	data.Target = self.target.link;
	data.CastTime = self.spell:findFirstChild'CastTime'.Value;
	data.Spell = self.spell;
	--data.Animation = s.SpellAnimation;
	data.IsSpellQueueSpell = self.isSpellQueue;
	Opcodes.SendMessageToSet(self.caster.link, packet, data);
end
function Spell:Go()
	local data,packet = {},Opcodes.FindClientPacket("SMSG_SPELL_GO");
	data.CastFlags = 0;
	data.Caster = self.caster.link;
	data.Target = self.target.link;
	data.CastTime = self.spell:findFirstChild'CastTime'.Value;
	data.Spell = self.spell;
	data.SpellTime = self.m_spellTime;
	--data.Animation = self.spell.SpellAnimation;
	data.ManaCost = self.spell:findFirstChild'ManaCost'.Value;
	Opcodes.SendMessageToSet(self.caster.link, packet, data);
end
function Spell:Execute()
	if self.caster then
		if self.spell then
			if (self:NeedsTarget()) then
				if self.caster:HasTarget() == false then
					self:HandleFailed("target");
					self:SetState("SPELL_STATE_FAILED");
					self.caster:StopCasting();
					return false;
				end
			end
			if self.caster:IsAlive() == false then
				self:HandleFailed("dead_target");
				self:SetState("SPELL_STATE_FAILED");
				self.caster:StopCasting();
				return false;
			end
			
			--Handle Mana
			self:HandleMana()
			
			-- Handle Auras
			if self:HasSpellAura() then
				local target = self.target
				if target then
					target:AddAura(self);
				end
			end
			
			-- Handle Combat
			if self.spell.PositiveNegative.Value == false then
				self.caster:SetInCombatWith(self.target);
			end
			
			if self:HasCooldown() then
				self.caster:SpellCooldown(self.spell);
			end
			--self.caster:SendManaUpdate(-self.spell.ManaCost.Value);
			--self:finish(true)
			--newSpell.SendSpellAnimation();
			self:SetState("SPELL_STATE_FINISHED")
			self.caster:StopCasting()
			return true;
		else
			error("Something went wrong while finding spell...")
		end
	end
end

function Spell:SelectSpellTargets()
	local newTarget;
	newTarget = self.target
	--[[if self.player and self.spell then
		if self.target ~= nil then
			if Unit.IsEnemy(self.player, self.target) and self.spell.PositiveNegative.Value == true then
				newTarget = self.player;
			end
		end

		if self.SpellName == "5" then
			if self.target == nil then
				newTarget = self.caster;
			end
		end
	end]]
	self.target = newTarget
end

function Spell:Update(m_time)
	local caster = self.caster
	if not caster then return nil end
	if self.m_spellState == "SPELL_STATE_PREPARING" then
		if caster:IsAlive() == false then
			self:Cancel()
		end
		if caster:IsMoving() == true then
			self:Cancel()
		end
		if caster:HasState("UNIT_STATE_SILENCED") then
			self:Cancel()
		end
		if self.m_castTime > 0 then
			if m_time > self.m_castTime then
				self.m_castTime = 0;
			else
				self.m_castTime = self.m_castTime - m_time;
			end
		end
		if self.m_castTime == 0 then
			self:Cast()
		end
	elseif self:GetState() == "SPELL_STATE_FINISHED" then
		if self:HasFlag("SPELL_FLAG_DELAY") then
			self.m_spellTime = self.m_spellTime - m_time
			if self.m_spellTime < 0 then
				self.m_spellTime = 0
				self.caster:DealDamage(self, self.target)
				self:SetState("SPELL_STATE_NULL")
			end
		else
			self.m_spellTime = 0
			if not self:HasFlag("SPELL_FLAG_NDOC") then -- SPELL_FLAG_NDOC removes damage on hit
				self.caster:DealDamage(self, self.target)
			end
			self:SetState("SPELL_STATE_NULL")
		end
		if caster:ToPlayer() ~= nil then
			if caster:IsOnGCD() == false then
				-- Do Spell Queue
			end
		end
	elseif self:GetState() == "SPELL_STATE_NULL" then
		return
	end
end

function Spell:AddData(data)
	-- Add Data to spell such as new spell flags
end

function Spell:Prepare()
	if (self.caster and self.spell) then
		--Run Spellscripts--
		--LoadScripts();
		--Account for Player--
		--if SpellQueue.GetSpell(self.player) then
		--	SpellQueue.RemoveSpell(self.player);
		--end
		if self.target and self.target.link:IsA("Model") and game.Players:GetPlayerFromCharacter(self.target.link) then
			self.target.link = game.Players:GetPlayerFromCharacter(self.target);
		end
		if self.target == nil and self:NeedsTarget() == false then
			self.target = self.caster
		end
		--Check for healing spell cast on enemy
		if self.caster:IsHostile(self.target) then
			if self.spell.PositiveNegative.Value == true then
				self.target = self.caster;
			end
		end
		--Check if we can cast the spell
		local checkcast = self:CheckCast();
		if typeof(checkcast) == "string" then 
			self:HandleFailed(checkcast);
			return false
		end
		self.caster:SetCasting()
		--self:LoadPointers();
		self:SetState("SPELL_STATE_PREPARING")
		self:Start()
		if self:HasFlag("SPELL_FLAG_IGNORES_GCD") == false then 
			self.caster:SetOnGCD();
		end
		if self:IsInstant() then
			self:Cast()
		end
	else
		error("100: Spell or Caster not found!"); -- Should never happen
	end
end

function Spell:HandleMana()
	if self.caster then
		local manaDrop = self.spell.ManaCost.Value;
		if manaDrop > 0 then
			if self.caster:GetMana() - manaDrop > 0 then
				self.caster:SetMana(self.caster:GetMana() - manaDrop)
			else
				self.caster:SetMana(0);
			end
		end
	end
end

function Spell:HasFlag(flag)
	if self.spell then
		for _,v in next, self.spell.SpellFlags:GetChildren() do
			if v.Name == flag then
				return true
			end
		end
	end
	return false
end

function Spell:IsPeriodic()
	local flags = self:GetFlags()
	for _,v in next,flags do
		if v.Name == 'SPELL_FLAG_AURA_PERIODIC' then
			return true
		end
	end
	return false
end

function Spell:IsMelee()
	for _,v in next,self:GetFlags() do
		if v.Name == "SPELL_FLAG_MELEE_RANGE" then
			return true
		end
	end
	return false
end

function Spell:IsRanged()
	for _,v in next,self:GetFlags() do
		if v.Name == "SPELL_FLAG_RANGED" then
			return true
		end
	end
	return false
end

function Spell:IsAoe()
	for _,v in next,self:GetFlags() do
		if v.Name == "SPELL_FLAG_AOE" then
			return true
		end
	end
	return false
end

function Spell:Cancel()
	local caster = self.caster
	if caster then
		self:SetState("SPELL_STATE_FINISHED")
		caster:StopCasting()
		caster:SetOnGCD(false)
	end
end

function Spell:LoadPointers()
	if self.player and self.spell then
		local castTime = self.spell:findFirstChild'CastTime'.Value;
		local bp = self.player:WaitForChild'Backpack';
		local newSpell = Instance.new("ObjectValue", bp.SpellData)
		newSpell.Name = "Spell"
		local SpellId = Instance.new("IntValue", newSpell)
		SpellId.Name = "SpellId"
		local CastTime = Instance.new("NumberValue", newSpell)
		CastTime.Name = "CastTime"
		local SpellName = Instance.new("StringValue", newSpell)
		SpellName.Name = "SpellName"
		local SpellState = Instance.new("StringValue", newSpell)
		SpellState.Name = "SpellState"
		local SpellTarget = Instance.new("ObjectValue", newSpell)
		SpellTarget.Name = "SpellTarget"
		local SpellTime = Instance.new("NumberValue", newSpell)
		SpellTime.Name = "SpellTime"
		newSpell.SpellId.Value = tonumber(self.spell.Name);
		newSpell.CastTime.Value = castTime;
		newSpell.SpellName.Value = self.spell.SpellName.Value;
		newSpell.SpellTarget.Value = target;
		newSpell.SpellTime.Value = 1
		newSpell.Value = self.spell;
	end
end

function Spell:GetTarget()
	return self.target
end

function Spell:NeedsTarget()
	for _,v in next,self:GetFlags() do
		if v == "SPELL_FLAG_NEEDS_TARGET" then
			return true
		end
	end
	return false
end

function Spell:IsOnCooldown()
	return self.caster:GetSpell(self.spellId).m_cooldownTime > 0
end

function Spell:IgnoresGCD()
	for _,v in next,self:GetFlags() do
		if v.Name == "SPELL_FLAG_IGNORES_GCD" then
			return true
		end
	end
	return false
end

function Spell:GetSpellType()
	return self.typ
end

Spell.IsWithinRange = function(unit, target)
	if unit and target then
		local head1 = unit.Head;
		local head2 = target.Head;
		if head1 and head2 then
			local dist = (head1.Position - head2.Position).Magnitude;
			if dist < 40 then
				return true;
			else
				return false;
			end
		end
	end
end

function Spell:GetFlags()
	return self.m_spellFlags
end

function Spell:HandleFailed(reason)
	local opcode = Opcodes.FindClientPacket("SMSG_CAST_FAILED");
	local caster = self.caster
	self.caster:StopCasting();
	if caster then
		if caster:ToPlayer() ~= nil then
			print(reason)
			opcode:FireClient(caster:ToPlayer().link, self.spell, reason)
		end
	end
end

function Spell:HasCooldown()
	return self.m_cooldownValue > 0
end

function Spell:SetOnCooldown()
	local caster = self.caster
	local spell = self.spell
	local list = self.SpellList
	if caster and spell and list then
		for _,v in next,list do
			if tostring(v.Value) == spell.Name then
				v.CooldownHandler.CooldownValue.Value = self.m_cooldownValue
			end
		end
	end
end

function Spell:PosNeg()
	return self.m_posneg
end

function Spell:CheckCast()
	local caster = self.caster
	local target = self.target
	if caster:GetMana() < self.spell.ManaCost.Value then
		return "mana"
	end
	if caster:InRange(target, self.spell.MaxRange.Value) == false then
		return "distance";
	end
	if caster:IsOnGCD() then
		if self:IgnoresGCD() ~= true then
			return "global cooldown"
		end
	end
	if target == nil and self:NeedsTarget() == true then
		return "needs_target"
	end
	if caster:IsAlive() == false then
		return "dead"
	end
	if caster:GetState() == "UNIT_STATE_STUNNED" then
		return "stunned";
	end
	if target:IsAlive() == false then
		return "dead_target"
	end
	--TODO: Add melee spell function
	if caster:IsHostile(target) == false and self:PosNeg() == false then
		return "invalid_target";
	end
	if self:PosNeg() == false and self.target == self.caster then
		return "invalid_target"
	end
	if self:IsOnCooldown() then
		return "cooldown"
	end
	if self:IsDisabled() then
		return "disabled"
	end
	if caster:IsCasting() then
		return "casting"
	end
	if caster:IsMoving() then -- TODO: Add spell flag SPELL_FLAG_CAST_WHILE_MOVING
		return "moving"
	end
	if caster:IsSilenced() then -- TODO: Add spell flag SPELL_FLAG_CAST_WHILE_SILENCED
		return "silenced"
	end
	if caster:IsWithinLOS(target) == false then -- TODO: Add spell flag SPELL_FLAG_CAST_OUT_LOS
		return "LoS"
	end
	--TODO: Custom check for dispel
end

function Spell:IsInstant()
	return self.spell.CastTime.Value == 0
end

function Spell:IsDisabled()
	return self.spell.Disabled.Value
end


return Spell