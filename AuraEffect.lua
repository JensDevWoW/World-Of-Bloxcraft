local AuraEffect = {}
AuraEffect.__index = AuraEffect

-- Aura Effects are what deal the damage / healing / everything else
-- If someone gets feared, this is where it's handled

function AuraEffect.new(aura, spell, target)
	local new_effect = {}
	setmetatable(new_effect, AuraEffect)
	
	new_effect.aura = aura
	new_effect.spell = spell
	new_effect.target = target
	new_effect.m_amount = spell:GetAmount();
	new_effect.effect = spell:GetEffect()
	
	return new_effect
end

function AuraEffect:HandleEffect() -- Happens for ticks, constant auras have no handle function ATM as they are usually spell modifiers (if HasAura then do this)
	local spell = self:GetSpellInfo()
	local caster = spell.caster
	local target = self.target
	local effect = self.effect;
	if effect == "DoT" then
		caster:DealDamage(spell, target)
	end
	--TODO: Handle more aura effects
end

function AuraEffect:GetSpellInfo()
	return self.spell
end

function AuraEffect:GetAmount()
	return self.m_amount;
end

function AuraEffect:SetAmount(amount)
	self.m_amount = amount;
end

function AuraEffect:SendTickImmune()
	
end

function AuraEffect:HasTimer()
	return self.m_hasTimer;
end

function AuraEffect:CalculateAmount(caster, target)
	return caster:SpellDamageBonusDone(target, self:GetSpellInfo())
end

function AuraEffect:HandlePeriodicDamageAurasTick(target, caster)
	if not target:IsAlive() then
		return;
	end
	
	if target:IsImmuneToDamage(self.spell) then
		self:SendTickImmune();
		return;
	end
	
	local damage = self:CalculateAmount(caster, target)
	
	
end

return AuraEffect
