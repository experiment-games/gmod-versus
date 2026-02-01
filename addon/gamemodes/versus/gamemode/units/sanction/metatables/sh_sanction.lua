local g_Player = player

---@class VersusSanction
local sanctionMeta = {}
sanctionMeta.__index = sanctionMeta

function sanctionMeta:init(sanctionKey)
  if (sanctionKey:len() > 255) then
    ErrorNoHaltWithStack("Too long sanction key specified! Won't fit in database.")
  end

  self.key = sanctionKey
  self.hook = {}
  self:reset()

  return self
end

function sanctionMeta:reset()
  -- ! Only functions and hooks can safely be reset, tables may be added at
  -- ! runtime and removing them may have undesired effects
  for member, value in pairs(self) do
    if (isfunction(value)) then
      self[member] = nil
    end
  end

  for eventName, callback in pairs(self.hook) do
    hook.Remove(eventName, self)
    self.hook[eventName] = nil
  end
end

function sanctionMeta:registerHooks()
  for eventName, callback in pairs(self.hook) do
    -- Call hook callbacks in a protected manner so one sanction doesn't break all others
    hook.Add(eventName, self, function(...)
      local success, a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z = xpcall(
        callback,
        function(errorMessage)
          ErrorNoHaltWithStack(
            string.format(
              "[Sanction \"%s\"] %s Hook Failed! Error: %q\n",
              self.key,
              eventName,
              errorMessage
            )
          )
        end,
        ...
      )

      if (not success) then
        return
      end

      -- Because it's susceptible to bugs we do a sanity check to help
      -- us recognize hooks which return more than 23 varargs (seems
      -- like bad design, just return a table if you must)
      if (x ~= nil or y ~= nil or z ~= nil) then
        ErrorNoHaltWithStack(
          string.format("[Sanction %q] %s Warning! Hook has unreasonable varargs count! Expect bugs.\n",
            self.key,
            eventName
          )
        )
        print(success, a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z)
      end

      return a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z
    end)
  end
end

function sanctionMeta:reset()
  self.description = "No description specified"
end

function sanctionMeta:IsValid()
  return true
end

function sanctionMeta:getApplied(player, data)
  if (not player.sanctions[self.key]) then
    return
  end

  if (player.sanctions[self.key].data ~= data) then
    return
  end

  return player.sanctions[self.key]
end

function sanctionMeta:apply(player, playerSanction)
  if (self.onApply and self:onApply(player, playerSanction) == false) then
    return false
  end

  player.sanctions[self.key] = playerSanction
end

function sanctionMeta:expire(player, playerSanction)
  if (self.onExpire and self:onExpire(player, playerSanction) == false) then
    return false
  end

  player.sanctions[self.key] = nil
end

debug.getregistry()["VersusSanction"] = sanctionMeta
