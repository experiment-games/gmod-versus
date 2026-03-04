---@class VersusTab
local tabMeta = {}
tabMeta.__index = tabMeta

function tabMeta:init(memberData)
  table.Merge(self, memberData or {})

  return self
end

function tabMeta:buildInto(tabPanel)
  self.contentPanel:SetParent(tabPanel)
  self:setTabData(tabPanel:AddTab(self.label, self.contentPanel))

  return self
end

---@param tab table Data returned by DPropertySheet:AddSheet
function tabMeta:setTabData(tab)
  self.tabData = tab
end

function tabMeta:IsValid()
  return true
end

debug.getregistry()["VersusTab"] = tabMeta
