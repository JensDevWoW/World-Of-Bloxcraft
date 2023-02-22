local Aura = {}
Aura.__index = Aura

local Opcodes = require(workspace.Opcodes);
local AuraEffect = require(script.AuraEffect)
-- Auras are objects inside of m_auraList for each unit
-- Each aura has similar functions to Spell where it deals damage and such
-- Haven't decided if I'm going to make it inherit or not
-- Each aura has a caster and a target, the target being the player/unit the aura is currently on
-- A lot of auras will be the same caster and target which is fine (Shield casted on yourself for example)

function Aura.new(spell, key)
	local new_aura = {}
	setmetatable(new_aura, Aura)
	
	new_aura.spell = spell
	new_aura.caster = spell.caster
	new_aura.link = spell.spell
	new_aura.target = spell.target
	new_aura.posneg = spell.m_posneg
	new_aura.hasTimer = spell.m_hasTimer;
	new_aura.m_duration = spell.m_duration
	new_aura.m_isPeriodic = spell.m_isPeriodic;
	new_aura.auraType = spell.m_auraType;
	new_aura.m_maxDuration = spell.m_maxDuration;
	new_aura.m_timeBetweenTicks = spell:GetTimeBetweenTicks();
	new_aura.m_needsClientUpdate = true;
	new_aura.m_key = key
	
	local effect = AuraEffect.new(new_aura, spell, spell.target)
	new_aura.m_effect = effect;
	
	return new_aura
	
end

function Aura:Update(m_time)
	if self.m_needsClientUpdate then
		self:UpdateClient();
	end
	if self.hasTimer then
		if self.m_duration > 0 then
			if self.m_timeBetweenTicks > 0 then
				self.m_timeBetweenTicks = self.m_timeBetweenTicks - m_time;
			else
				self.m_timeBetweenTicks = self.spell:GetTimeBetweenTicks();
				self.m_effect:HandleEffect();
			end
			self.m_duration = self.m_duration - m_time;
		else
			self.m_duration = 0;
			self.m_effect:HandleEffect()
			self.hasTimer = false;
			self:Finish()
		end
	end
end

function Aura:SetNeedClientUpdate()
	self.m_needsClientUpdate = true;
end

function Aura:UpdateClient()
	local packet = Opcodes.FindClientPacket("SMSG_AURA_UPDATE")
	local data = self:BuildUpdatePacket()
	Opcodes.SendMessageToSet(self.caster.link, packet, data);
	self.m_needsClientUpdate = false;
end
function Aura:BuildUpdatePacket()
	local data = {}
	data.Caster = self.caster.link
	data.Target = self.target.link;
	data.AuraInfo = self.link.AuraInfo
	data.Key = self.m_key;
	
	return data
	--TODO: Finish opcode send
end

function Aura:Finish()
	table.remove(self.target.m_auraList, self.key);
end

function Aura:SetLoadedState(maxDuration, duration, amount)
	--TODO: Add charges, stack amount, masks
	self.m_duration = duration
	self.m_maxDuration = maxDuration;
	
	local effect = self:GetAuraEffect()
	if effect then
		effect:SetAmount(amount)
		effect:CalculatePeriodic(self.caster)
	end
	
end

function Aura:GetSpellInfo()
	return self.spell
end

function Aura:SetDuration(duration)
	self.m_duration = duration
	--TODO: Update client data
end

function Aura:RefreshDuration()
	local caster = self.caster
	local duration = self.m_maxDuration;
	--TODO: Add Spell Attributes to check for SPELL_ATTR8_HASTE_AFFECTS_DURATION
	self.m_duration = duration;
	self:SetNeedClientUpdate();
	--self.m_timeBetweenTicks = self.spell:GetTimeBetweenTicks();
	--TODO: Add charge function to reset here
end

function Aura:IsUsingStacks()
	--TODO: Add SpellMgr.cpp
end

function Aura:HasMoreThanOneEffectForType(auraType)
	--TODO: Create auratypes and auraeffects
end

function Aura:IsArea()
	--TODO: Create area-of-effect auras
end

function Aura:IsPassive()
	return self:GetSpellInfo():IsPassive();
end

function Aura:IsDeathPersistent()
	return self:GetSpellInfo():IsDeathPersistent()
end



return Aura
