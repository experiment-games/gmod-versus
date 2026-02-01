---@class VersusTab
local tabMeta = {}
tabMeta.__index = tabMeta

function tabMeta:init(memberData)
  table.Merge(self, memberData or {})

  return self
end

function tabMeta:buildInto(propertySheet)
  self.contentPanel:SetParent(propertySheet)
  self:setTabData(propertySheet:AddSheet(self.label, self.contentPanel, self.icon))

  return self
end

---@param tab table Data returned by DPropertySheet:AddSheet
function tabMeta:setTabData(tab)
  self.tabData = tab
end

function tabMeta:IsValid()
  return true
end

function tabMeta:setEnabled(isEnabled)
  -- Testing disabling a tab for when we are still creating a character
  self.tabData.Tab:SetEnabled(isEnabled)
  self.tabData.Tab._OldPerformLayout = self.tabData.Tab._OldPerformLayout or self.tabData.Tab.PerformLayout

  if (isEnabled) then
    self.tabData.Tab.PerformLayout = self.tabData.Tab._OldPerformLayout
    -- test.Tab.DoClick = function(tab)
    --   tab:GetPropertySheet():SetActiveTab(tab)
    -- end
  else
    -- Make it even more apparant this tab is disabled by dimming the image
    -- more
    self.tabData.Tab.PerformLayout = function(tab, w, h)
      self.tabData.Tab._OldPerformLayout(tab, w, h)

      if (IsValid(tab.Image)) then
        tab.Image:SetImageColor(Color(200, 200, 200, 100))
      end
    end
  end
end

debug.getregistry()["VersusTab"] = tabMeta
