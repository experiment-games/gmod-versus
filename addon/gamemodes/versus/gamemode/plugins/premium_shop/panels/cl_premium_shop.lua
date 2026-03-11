local PLUGIN = PLUGIN

do
  local PANEL = {}

  function PANEL:Init()
    PLUGIN.premiumShopPanel = self

    self:Dock(FILL)
    self:DockPadding(0, GAMEMODE.SPACING * .5, 0, GAMEMODE.SPACING)

    local buttons = self:Add("EditablePanel")
    buttons:SetTall(40)
    buttons:DockMargin(0, 0, 0, 10)
    buttons:Dock(TOP)

    local shopUrl = PLUGIN.premiumShopUrl:GetString()

    self.shopHTML = self:Add("HTML")
    self.shopHTML:Dock(FILL)
    self.shopHTML:OpenURL(shopUrl .. "#in-game")
    self.shopHTML.OnFinishLoadingDocument = function(pnl, url)
      if (url:find("about:blank", 1, true)) then
        self.shopHTML:OpenURL(shopUrl .. "#in-game")
        return
      end

      -- Prevent TAB from cycling through HTML elements when the shop is open in the TAB menu
      pnl:RunJavascript([[
        document.addEventListener('keydown', function(e) {
          if (e.key === 'Tab') {
            e.preventDefault();
          }
        }, true);
      ]])
    end

    local homeButton = buttons:Add("versus_Button")
    homeButton:SetText("Shop Home")
    homeButton:SizeToContents()
    homeButton:Dock(LEFT)
    homeButton:DockMargin(0, 0, 10, 0)
    homeButton.DoClick = function()
      -- For some reason without going to blank first, we're stuck with a background if we go to the PayNow.gg TOS
      self.shopHTML:OpenURL("about:blank")
    end

    if (LocalPlayer():IsSuperAdmin()) then
      local adminButton = buttons:Add("versus_Button")
      adminButton:SetText("Admin Payment Info")
      adminButton:SizeToContents()
      adminButton:Dock(LEFT)
      adminButton:DockMargin(0, 0, 10, 0)
      adminButton.DoClick = function()
        PLUGIN.showAdminPaymentsPanel()
      end
    end

    local historyButton = buttons:Add("versus_Button")
    historyButton:SetText("Payment History")
    historyButton:SizeToContents()
    historyButton:Dock(LEFT)
    historyButton.DoClick = function()
      PLUGIN.showPaymentHistory()
    end

    local steamButton = buttons:Add("versus_Button")
    steamButton:SetText("Open Shop in Steam Browser")
    steamButton:SizeToContents()
    steamButton:Dock(RIGHT)
    steamButton.DoClick = function()
      gui.OpenURL(shopUrl)
      print("Opening shop URL in Steam browser: " .. shopUrl)
    end
  end

  vgui.Register("versus_PremiumShop", PANEL, "EditablePanel")
end
