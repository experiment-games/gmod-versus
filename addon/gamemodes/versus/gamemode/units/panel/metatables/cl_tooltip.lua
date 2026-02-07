--[[
	Tooltip for panels

	Modified version of cl_tooltip.lua:
	https://github.com/NebulousCloud/helix/blob/f74ba9759789e0c588789d407a4ce512cecc2ddb/gamemode/core/derma/cl_tooltip.lua

	Original License:

	The MIT License (MIT)

	Copyright (c) 2015 Brian Hang, Kyu Yeon Lee
	Copyright (c) 2018-2021 Alexander Grist-Hucker, Igor Radovanovic

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
]]

-- Text container for `versus_Tooltip`.
-- Rows are the main way of interacting with `versus_Tooltip`s. These derive from
-- [DLabel](https://wiki.garrysmod.com/page/Category:DLabel) panels, which means that making use of this panel
-- will be largely the same as any DLabel panel.
-- @panel versus_TooltipRow

local animationTime = 1

function derma.SkinFunc(name, panel, a, b, c, d, e, f, g)
  local skin = (ispanel(panel) and IsValid(panel)) and panel:GetSkin() or derma.GetDefaultSkin()

  if (not skin) then
    return
  end

  local func = skin[name]

  if (not func) then
    return
  end

  return func(skin, panel, a, b, c, d, e, f, g)
end

local tooltip
local lastHover

do
  --- @class Panel
  local META = FindMetaTable("Panel")

  local versusChangeTooltip = ChangeTooltip
  local versusRemoveTooltip = RemoveTooltip

  --- Sets a tooltip to show when the mouse hovers over this panel. The callback
  --- is to build the tooltip.
  --- For example:
  --- ```lua
  --- panel:SetVersusTooltip(function(tooltip)
  --- 	local name = tooltip:AddRow("name")
  --- 	name:SetImportant()
  --- 	name:SetText(client:SteamName())
  --- 	name:SetBackgroundColor(team.GetColor(client:Team()))
  --- 	name:SizeToContents()
  --- 	tooltip:SizeToContents()
  --- end)
  --- ```
  --- @param callback fun(tooltip: versus_Tooltip)
  function META:SetVersusTooltip(callback)
    self:SetMouseInputEnabled(true)
    self.versusTooltip = callback
  end

  function ChangeTooltip(panel, ...) -- luacheck: globals ChangeTooltip
    if (not IsValid(panel) or not panel.versusTooltip) then
      return versusChangeTooltip(panel, ...)
    end

    RemoveTooltip()

    timer.Create("versus_Tooltip", 0.1, 1, function()
      if (not IsValid(panel) or lastHover ~= panel) then
        return
      end

      tooltip = vgui.Create("versus_Tooltip")
      panel.versusTooltip(tooltip)
      tooltip:SizeToContents()
    end)

    lastHover = panel
  end

  function RemoveTooltip() -- luacheck: globals RemoveTooltip
    if (IsValid(tooltip)) then
      tooltip:Remove()
      tooltip = nil
    end

    timer.Remove("versus_Tooltip")
    lastHover = nil

    return versusRemoveTooltip()
  end
end

do
  --- @class versus_TooltipRow : DLabel
  local PANEL = {}

  DEFINE_BASECLASS("DLabel")

  AccessorFunc(PANEL, "backgroundColor", "BackgroundColor")
  AccessorFunc(PANEL, "maxWidth", "MaxWidth", FORCE_NUMBER)
  AccessorFunc(PANEL, "bNoMinimal", "MinimalHidden", FORCE_BOOL)

  function PANEL:Init()
    self:SetFont("VersusDefault")
    self:SetText("unknown")
    self:SetTextColor(color_white)
    self:SetTextInset(4, 0)
    self:SetContentAlignment(4)
    self:Dock(TOP)

    self.maxWidth = ScrW() * 0.2
    self.bNoMinimal = false
    self.bMinimal = false
  end

  --- Whether or not this tooltip row should be displayed in a minimal format. This usually means no background and/or
  --- smaller font. You probably won't need this if you're using regular `versus_TooltipRow` panels, but you should take into
  --- account if you're creating your own panels that derive from `versus_TooltipRow`.
  --- @return boolean # True if this tooltip row should be displayed in a minimal format
  function PANEL:IsMinimal()
    return self.bMinimal
  end

  --- Sets this row to be more prominent with a larger font and more noticable background color. This should usually
  --- be used once per tooltip as a title row. For example, item tooltips have one "important" row consisting of the
  --- item's name. Note that this function is a fire-and-forget function; you cannot revert a row back to it's regular state
  --- unless you set the font/colors manually.
  function PANEL:SetImportant()
    self.bImportant = true
    self:SetFont("VersusDefaultOutlined")
    self:SetExpensiveShadow(1, color_black)
    self:SetBackgroundColor(color_background)

    if (IsValid(self.rightText)) then
      self.rightText:SetFont("VersusDefaultOutlined")
      self.rightText:SetExpensiveShadow(1, color_black)
    end
  end

  --- Sets the background color of this row. This should be used sparingly to avoid overwhelming players with a
  --- bunch of different colors that could convey different meanings.
  --- @param color Color New color of the background. The alpha is clamped to 100-255 to ensure visibility
  function PANEL:SetBackgroundColor(color)
    color = table.Copy(color)
    color.a = math.min(color.a or 255, 100)

    self.backgroundColor = color
  end

  --- Sets the right text, to be drawn on the right side of the row.
  --- @param text string Text to be displayed
  function PANEL:SetRightText(text)
    if (IsValid(self.rightText)) then
      self.rightText:Remove()
    end

    self.rightText = vgui.Create("DLabel", self)
    self.rightText:SetText(text)
    self.rightText:SetTextColor(color_white)
    self.rightText:SetTextInset(0, 2)
    self.rightText:SetContentAlignment(6)

    if (self.bImportant) then
      self.rightText:SetFont("VersusDefault")
      self.rightText:SetExpensiveShadow(1, color_black)
    else
      self.rightText:SetFont("VersusDefault")
    end

    self.rightText:SizeToContents()
  end

  --- Resizes this panel to fit its contents. This should be called after setting the text.
  function PANEL:SizeToContents()
    local contentWidth, contentHeight = self:GetContentSize()
    contentWidth = contentWidth + 4
    contentHeight = contentHeight + 4

    if (IsValid(self.rightText)) then
      local rightWidth, rightHeight = self.rightText:GetContentSize()
      contentWidth = contentWidth + rightWidth + 48
      contentHeight = math.max(contentHeight, rightHeight)
    end

    if (contentWidth > self.maxWidth) then
      self:SetWide(self.maxWidth - 4) -- to account for text inset
      self:SetTextInset(4, 0)
      self:SetWrap(true)

      self:SizeToContentsY()
    else
      self:SetSize(contentWidth, contentHeight)
    end

    self:InvalidateLayout(true)
  end

  function PANEL:PerformLayout(width, height)
    BaseClass.PerformLayout(self, width, height)

    if (IsValid(self.rightText)) then
      self.rightText:SetX(
        width - self.rightText:GetWide() - 4
      )
    end
  end

  --- Resizes the height of this panel to fit its contents.
  function PANEL:SizeToContentsY()
    BaseClass.SizeToContentsY(self)
    self:SetTall(self:GetTall() + 4)
  end

  --- Called when the background of this row should be painted. This will paint the background with the
  --- `DrawImportantBackground` function set in the skin by default.
  --- @param width number Width of the panel
  --- @param height number Height of the panel
  function PANEL:PaintBackground(width, height)
    if (self.backgroundColor) then
      derma.SkinFunc("DrawImportantBackground", 0, 0, width, height, self.backgroundColor)
    end
  end

  --- Called when the foreground of this row should be painted. If you are overriding this in a subclassed panel,
  --- make sure you call `versus_TooltipRow:PaintBackground` at the *beginning* of your function to make its style
  --- consistent with the rest of the framework.
  --- @params width number Width of the panel
  --- @params height number Height of the panel
  function PANEL:Paint(width, height)
    self:PaintBackground(width, height)
  end

  vgui.Register("versus_TooltipRow", PANEL, "DLabel")
end

do
  --- Generic information panel.
  --- Tooltips are used extensively throughout Helix/Versus: for item information, character displays, entity status, etc.
  --- The tooltip system can be used on any panel or entity you would like to show standardized information for. Tooltips
  --- consist of the parent container panel (`versus_Tooltip`), which is filled with rows of information (usually
  --- `versus_TooltipRow`, but can be any docked panel if non-text information needs to be shown, like an item's size).
  ---
  --- Tooltips can be added to panel with `panel:SetVersusTooltip()`. An example taken from the scoreboard:
  --- ```lua
  --- panel:SetVersusTooltip(function(tooltip)
  --- 	local name = tooltip:AddRow("name")
  --- 	name:SetImportant()
  --- 	name:SetText(client:SteamName())
  --- 	name:SetBackgroundColor(team.GetColor(client:Team()))
  --- 	name:SizeToContents()
  --- 	tooltip:SizeToContents()
  --- end)
  --- ```
  --- @class versus_Tooltip : Panel
  local PANEL = {}
  DEFINE_BASECLASS("Panel")

  AccessorFunc(PANEL, "entity", "Entity")
  AccessorFunc(PANEL, "mousePadding", "MousePadding", FORCE_NUMBER)
  AccessorFunc(PANEL, "bDrawArrow", "DrawArrow", FORCE_BOOL)
  AccessorFunc(PANEL, "arrowColor", "ArrowColor")
  AccessorFunc(PANEL, "bArrowFollowEntity", "ArrowFollowEntity", FORCE_BOOL)

  function PANEL:Init()
    self.fraction = 0
    self.mousePadding = 16
    self.arrowColor = color_background
    self.bArrowFollowEntity = true
    self.bMinimal = false

    self.lastX, self.lastY = self:GetCursorPosition()
    self.arrowX, self.arrowY = ScrW() * 0.5, ScrH() * 0.5

    self:SetAlpha(0)
    self:SetSize(0, 0)
    self:SetDrawOnTop(true)
    self:SetMouseInputEnabled(false)

    self:CreateAnimation(animationTime, {
      index = 1,
      target = { fraction = 1 },
      easing = "outQuint",

      Think = function(animation, panel)
        panel:SetAlpha(panel.fraction * 255)
      end
    })
  end

  --- Whether or not this tooltip should be displayed in a minimal format.
  --- @return boolean # True if this tooltip should be displayed in a minimal format
  --- @see versus_TooltipRow:IsMinimal
  function PANEL:IsMinimal()
    return self.bMinimal
  end

  -- ensure all children are painted manually
  function PANEL:Add(...)
    local panel = BaseClass.Add(self, ...)
    panel:SetPaintedManually(true)

    return panel
  end

  --- Creates a new `versus_TooltipRow` panel and adds it to the bottom of this tooltip.
  --- @param id string Name of the new row. This is used to reorder rows if needed
  --- @return versus_TooltipRow # Created row
  function PANEL:AddRow(id)
    local panel = self:Add("versus_TooltipRow")
    panel.id = id
    panel:SetZPos(#self:GetChildren() * 10)

    return panel
  end

  --- Creates a new `versus_TooltipRow` and adds it after the row with the given `id`. The order of the rows is set via
  --- setting the Z position of the panels, as this is how VGUI handles ordering with docked panels.
  --- @param after string Name of the row to insert after
  --- @param id string Name of the newly created row
  --- @return versus_TooltipRow # Created row
  function PANEL:AddRowAfter(after, id)
    local panel = self:AddRow(id)
    local afterPanel = self:GetRow(after)

    if (not IsValid(afterPanel)) then
      return panel
    end

    panel:SetZPos(afterPanel:GetZPos() + 1)

    return panel
  end

  --- Sets the entity associated with this tooltip. Note that this function is not how you get entities to show tooltips.
  --- @param entity Entity Entity to associate with this tooltip
  function PANEL:SetEntity(entity)
    if (not IsValid(entity)) then
      self.bEntity = false
      return
    end

    -- don't show entity tooltips if we have an entity menu open
    if (IsValid(versus.menu.panel)) then
      self:Remove()
      return
    end

    if (entity:IsPlayer()) then
      local character = entity:GetCharacter()

      if (character) then
        -- we want to group things that will most likely have backgrounds (e.g name/health status)
        hook.Run("PopulateImportantCharacterInfo", entity, character, self)
        hook.Run("PopulateCharacterInfo", entity, character, self)
      end
    else
      if (entity.OnPopulateEntityInfo) then
        entity:OnPopulateEntityInfo(self)
      else
        hook.Run("PopulateEntityInfo", entity, self)
      end
    end

    self:SizeToContents()

    self.entity = entity
    self.bEntity = true
  end

  function PANEL:PaintUnder(width, height)
  end

  function PANEL:Paint(width, height)
    self:PaintUnder()

    if (not self.bClosing) then
      if (self.bEntity and IsValid(self.entity) and self.bArrowFollowEntity) then
        local entity = self.entity
        local position = select(1, entity:GetBonePosition(entity:LookupBone("ValveBiped.Bip01_Spine") or -1)) or
            entity:LocalToWorld(entity:OBBCenter())

        position = position:ToScreen()
        self.arrowX = math.Clamp(position.x, 0, ScrW())
        self.arrowY = math.Clamp(position.y, 0, ScrH())
      end
    end

    -- arrow
    if (self.bDrawArrow or (self.bDrawArrow)) then
      local x, y = self:ScreenToLocal(self.arrowX, self.arrowY)

      DisableClipping(true)
      surface.SetDrawColor(self.arrowColor)
      surface.DrawLine(0, 0, x * self.fraction, y * self.fraction)
      surface.DrawRect((x - 2) * self.fraction, (y - 2) * self.fraction, 4, 4)
      DisableClipping(false)
    end

    -- contents
    local x, y = self:GetPos()

    render.SetScissorRect(x, y, x + width * self.fraction, y + height, true)

    versus.util.drawBlur(self, 1)

    surface.SetDrawColor(color_background)
    surface.DrawRect(0, 0, width, height)

    for _, v in ipairs(self:GetChildren()) do
      if (IsValid(v)) then
        v:PaintManual()
      end
    end
    render.SetScissorRect(0, 0, 0, 0, false)
  end

  --- Returns the current position of the mouse cursor on the screen.
  --- @return number, number # X and Y position of cursor
  function PANEL:GetCursorPosition()
    local width, height = self:GetSize()
    local mouseX, mouseY = input.GetCursorPos()

    return math.Clamp(mouseX + self.mousePadding, 0, ScrW() - width), math.Clamp(mouseY, 0, ScrH() - height)
  end

  function PANEL:Think()
    if (not self.bEntity) then
      if (not vgui.CursorVisible()) then
        self:SetPos(self.lastX, self.lastY)

        -- if the cursor isn't visible then we don't really need the tooltip to be shown
        if (not self.bClosing) then
          self:Remove()
        end
      else
        local newX, newY = self:GetCursorPosition()

        self:SetPos(newX, newY)
        self.lastX, self.lastY = newX, newY
      end

      self:MoveToFront() -- dragging a panel w/ tooltip will push the tooltip beneath even the menu panel(???)
    elseif (IsValid(self.entity) and not self.bClosing) then
      if (self.bRaised) then
        self:SetPos(
          ScrW() * 0.5 - self:GetWide() * 0.5,
          math.min(ScrH() * 0.5 + self:GetTall() + 32, ScrH() - self:GetTall())
        )
      else
        local entity = self.entity
        local min, max = entity:GetRotatedAABB(entity:OBBMins() * 0.5, entity:OBBMaxs() * 0.5)
        min = entity:LocalToWorld(min):ToScreen().x
        max = entity:LocalToWorld(max):ToScreen().x

        self:SetPos(
          math.Clamp(math.max(min, max), ScrW() * 0.5 + 64, ScrW() - self:GetWide()),
          ScrH() * 0.5 - self:GetTall() * 0.5
        )
      end
    end
  end

  --- Returns an `versus_TooltipRow` corresponding to the given name.
  --- @param id string Name of the row
  --- @return Panel? # Corresponding row
  function PANEL:GetRow(id)
    for _, v in ipairs(self:GetChildren()) do
      if (IsValid(v) and v.id == id) then
        return v
      end
    end
  end

  --- Resizes the tooltip to fit all of the child panels. You should always call this after you are done
  --- adding all of your rows.
  function PANEL:SizeToContents()
    local height = 0
    local width = 0

    for _, v in ipairs(self:GetChildren()) do
      if (v:GetWide() > width) then
        width = v:GetWide()
      end

      height = height + v:GetTall()
    end

    self:SetSize(width, height)
  end

  function PANEL:Remove()
    if (self.bClosing) then
      return
    end

    self.bClosing = true
    self:CreateAnimation(animationTime * 0.5, {
      target = { fraction = 0 },
      easing = "outQuint",

      Think = function(animation, panel)
        panel:SetAlpha(panel.fraction * 255)
      end,

      OnComplete = function(animation, panel)
        BaseClass.Remove(panel)
      end
    })
  end

  vgui.Register("versus_Tooltip", PANEL, "Panel")
end

do
  --- @class versus_TooltipMinimalRow : versus_TooltipRow
  local PANEL = {}

  function PANEL:Init()
    self.bMinimal = true
    self.versusAlpha = 0 -- to avoid conflicts if we're animating a non-tooltip panel

    self:SetExpensiveShadow(1, color_black)
    self:SetContentAlignment(5)
  end

  function PANEL:SetImportant()
    self:SetFont("VersusDefault")
    self:SetBackgroundColor(color_background)
  end

  -- background color will affect text instead in minimal tooltips
  function PANEL:SetBackgroundColor(color)
    color = table.Copy(color)
    color.a = math.min(color.a or 255, 100)

    self:SetTextColor(color)
    self.backgroundColor = color
  end

  function PANEL:PaintBackground()
  end

  vgui.Register("versus_TooltipMinimalRow", PANEL, "versus_TooltipRow")
end

do
  --- @class versus_TooltipMinimal : versus_Tooltip
  local PANEL = {}

  DEFINE_BASECLASS("versus_Tooltip")

  function PANEL:Init()
    self.bMinimal = true

    -- we don't want to animate the alpha since children will handle their own animation, but we want to keep the fraction
    -- for the background to animate
    self:CreateAnimation(animationTime, {
      index = 1,
      target = { fraction = 1 },
      easing = "outQuint",
    })

    self:SetAlpha(255)
  end

  -- we don't need the children to be painted manually
  function PANEL:Add(...)
    local panel = BaseClass.Add(self, ...)
    panel:SetPaintedManually(false)

    return panel
  end

  function PANEL:AddRow(id)
    local panel = self:Add("versus_TooltipMinimalRow")
    panel.id = id
    panel:SetZPos(#self:GetChildren() * 10)

    return panel
  end

  function PANEL:Paint(width, height)
    self:PaintUnder()

    derma.SkinFunc("PaintTooltipMinimalBackground", self, width, height)
  end

  function PANEL:Think()
  end

  function PANEL:SizeToContents()
    -- remove any panels that shouldn't be shown in a minimal tooltip
    for _, v in ipairs(self:GetChildren()) do
      if (v.bNoMinimal) then
        v:Remove()
      end
    end

    BaseClass.SizeToContents(self)
    self:SetPos(ScrW() * 0.5 - self:GetWide() * 0.5, ScrH() * 0.5 + self.mousePadding)

    -- we create animation here since this is the only function that usually gets called after all the rows are populated
    local children = self:GetChildren()

    -- sort by z index so we can animate them in order
    table.sort(children, function(a, b)
      return a:GetZPos() < b:GetZPos()
    end)

    local i = 1
    local count = table.Count(children)

    for _, v in ipairs(children) do
      v.versusAlpha = v.versusAlpha or 0

      v:CreateAnimation((animationTime / count) * i, {
        easing = "inSine",
        target = { versusAlpha = 255 },
        Think = function(animation, panel)
          panel:SetAlpha(panel.versusAlpha)
        end
      })

      i = i + 1
    end
  end

  DEFINE_BASECLASS("Panel")
  function PANEL:Remove()
    if (self.bClosing) then
      return
    end

    self.bClosing = true

    -- we create animation here since this is the only function that usually gets called after all the rows are populated
    local children = self:GetChildren()

    -- sort by z index so we can animate them in order
    table.sort(children, function(a, b)
      return a:GetZPos() > b:GetZPos()
    end)

    local duration = animationTime * 0.5
    local i = 1
    local count = table.Count(children)

    for _, v in ipairs(children) do
      v.versusAlpha = v.versusAlpha or 255

      v:CreateAnimation(duration / count * i, {
        target = { versusAlpha = 0 },
        Think = function(animation, panel)
          panel:SetAlpha(panel.versusAlpha)
        end
      })

      i = i + 1
    end

    self:CreateAnimation(duration, {
      target = { fraction = 0 },
      OnComplete = function(animation, panel)
        BaseClass.Remove(panel)
      end
    })
  end

  vgui.Register("versus_TooltipMinimal", PANEL, "versus_Tooltip")
end
