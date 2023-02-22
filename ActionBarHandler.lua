local ABH = {}
ABH.__index = ABH

local SB = require(script.Parent.Set.SpellButton)

function ABH.new(link, UI)
	local button_set = {}
	setmetatable(button_set, ABH)
	
	button_set.link = link
	button_set.UI = UI
	button_set.m_set = {}
	
	button_set.m_spellList = {
		[1] = {
			m_spellId = 5
		},
		[2] = {
			m_spellId = 1
		},
		[3] = {
			m_spellId = 2
		},
		[4] = {
			m_spellId = 8
		},
		[5] = {
			m_spellId = 7
		},
		[6] = {
			m_spellId = 9
		},
		[7] = {
			m_spellId = 25
		}
	}
	
	for _,v in next,button_set.link.Set:GetChildren() do
		if v:IsA("Frame") then
			local spellId = button_set.m_spellList[tonumber(v.Name)].m_spellId
			local cdVal = game.Lighting.Spells[tostring(spellId)].CooldownValue.Value
			local new_button = SB.new(v, spellId, cdVal)
			table.insert(button_set.m_set, new_button)
		end
	end
	
	return button_set
	
end

function ABH:Update(deltaTime)
	for _,v in next,self.m_set do
		v:Update(deltaTime)
	end
end

function ABH:SetOnGCD()
	for _,v in next,self.m_set do
		v:SetOnGCD()
	end
end

return ABH
