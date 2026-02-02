-- Source: https://github.com/Lexicality/applejack/tree/master/entities/weapons/cider_hand

SWEP.Slot = 1
SWEP.SlotPos = 1
SWEP.DrawAmmo = false
SWEP.IconLetter = "H"
SWEP.DrawCrosshair = false

local title_color = "<color=230,230,230,255>"
local text_color = "<color=150,150,150,255>"
local end_color = "</color>"
SWEP.Instructions =
    end_color .. title_color .. "%s: " .. end_color .. text_color .. " Lock\n" ..               -- primary
    end_color .. title_color .. "%s: " .. end_color .. text_color .. " Unlock\n" ..             -- secondary
    end_color .. title_color .. "%s + %s: " .. end_color .. text_color .. " Throw / Knock\n" .. -- sprint + primary
    end_color .. title_color .. "%s + %s: " .. end_color .. text_color .. " Pick Up / Drop"     -- sprint + secondary
SWEP.Purpose = "Picking stuff up and knocking on doors."

function SWEP:DrawWeaponSelection(x, y, wide, tall, alpha)
  draw.SimpleText(self.IconLetter, "CSSelectIcons", x + 0.59 * wide, y + tall * 0.2, Color(255, 220, 0, 255),
    TEXT_ALIGN_CENTER)
  self:PrintWeaponInfo(x + wide + 20, y + tall * 0.95, alpha)
end

killicon.AddFont("versus_hands", "CSKillIcons", SWEP.IconLetter, Color(255, 80, 0, 255))
