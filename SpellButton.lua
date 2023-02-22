local SB = {}
SB.__index = SB

function SB.new(link, spellId, cooldown)
	local new_button = {}
	setmetatable(new_button, SB)
	
	new_button.link = link
	new_button.spellId = spellId
	new_button.cooldownValue = cooldown
	new_button.cooldownTime = 0
	new_button.onGCD = false
	new_button.gcdVal = 1.5;
	new_button.cooldownProgress = 0
	new_button.gcdProgress = 0
	new_button.gcdvis = link.CooldownVisual
	
	return new_button
end

function SB:Update(deltaTime)
	if self.cooldownTime > 0 then
		self.gcdvis.Visible = true;
		self.gcdvis.BackgroundTransparency = 0.5;
		local rate = 1 / self.cooldownValue;
		if self.cooldownProgress >= 1 then
			self.cooldownProgress = 1;
			self.gcdvis.BackgroundTransparency = 1;
			self.gcdvis.Size = UDim2.new(0,50,0,50);
			self.cooldownProgress = 0;
			self.cooldownTime = 0;
		else
			self.gcdvis.Size = UDim2.new(0, 50, 0, 50):Lerp(UDim2.new(0,50,0,0), self.cooldownProgress)
			self.cooldownProgress = self.cooldownProgress + (rate * deltaTime);
		end
	end
	if self.onGCD == true and self.cooldownTime == 0 then
		local renderstepped;
		local rate = 1 / (self.gcdVal - 0.2);
		local gcdvis = self.link.GCDVisual;
		if self.link then
			gcdvis.Visible = true;
			gcdvis.BackgroundTransparency = 0.5;
			if self.gcdProgress >= 1 then
				self.gcdProgress = 1;
				gcdvis.BackgroundTransparency = 1;
				self.onGCD = false
				self.gcdProgress = 0
				gcdvis.Size = UDim2.new(0,50,0,50);
			else
				gcdvis.Size = UDim2.new(0, 50, 0, 50):Lerp(UDim2.new(0,50,0,0), self.gcdProgress)
				self.gcdProgress = self.gcdProgress + (rate * deltaTime);
			end
		end
	end
end

function SB:SetOnGCD()
	self.onGCD = true;
end

function SB:SetOnCD()
	self.cooldownTime = self.cooldownValue
end

return SB
