--- @class Panel
local META = FindMetaTable("Panel")

--[[
	Animation methods for panels

	Modified version of sh_animation.lua library:
	https://github.com/NebulousCloud/helix/blob/f97adac5df18c69eaee2944c8ae029ee29327503/gamemode/core/libs/sh_animation.lua

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
local function TweenAnimationThink(object)
  for k, v in pairs(object.tweenAnimations) do
    if (! v.bShouldPlay) then
      continue
    end

    local bComplete = v:update(FrameTime())

    if (v.Think) then
      v:Think(object)
    end

    if (bComplete) then
      v.bShouldPlay = nil

      v:ForceComplete()

      if (v.OnComplete) then
        v:OnComplete(object)
      end

      if (v.bRemoveOnComplete) then
        object.tweenAnimations[k] = nil
      end
    end
  end
end

function META:GetTweenAnimation(index, bNoPlay)
  -- if we don't need to check if the animation is playing we can just return the animation
  if (bNoPlay) then
    return self.tweenAnimations[index]
  else
    for k, v in pairs(self.tweenAnimations or {}) do
      if (k == index and v.bShouldPlay) then
        return v
      end
    end
  end
end

function META:IsPlayingTweenAnimation(index)
  for k, v in pairs(self.tweenAnimations or {}) do
    if (v.bShouldPlay and index == k) then
      return true
    end
  end

  return false
end

function META:StopAnimations(bRemove)
  for k, v in pairs(self.tweenAnimations or {}) do
    if (v.bShouldPlay) then
      v:ForceComplete()

      if (bRemove) then
        self.tweenAnimations[k] = nil
      end
    end
  end
end

function META:CreateAnimation(length, data)
  local animations = self.tweenAnimations or {}
  self.tweenAnimations = animations

  if (self.SetAnimationEnabled) then
    self:SetAnimationEnabled(true)
  end

  local index = data.index or 1
  local bCancelPrevious = data.bCancelPrevious == nil and false or data.bCancelPrevious
  local bIgnoreConfig = SERVER or (data.bIgnoreConfig == nil and false or data.bIgnoreConfig)

  if (bCancelPrevious and self:IsPlayingTweenAnimation()) then
    for _, v in pairs(animations) do
      v:set(v.duration)
    end
  end

  local animation = versus.tween.new(
    ((length == 0 and 1 or length) or 1), -- * (bIgnoreConfig and 1 or BB_CONVAR_ANIMATIONSCALE:GetInt()),
    data.subject or self,
    data.target or {},
    data.easing or "linear"
  )

  animation.index = index
  animation.bIgnoreConfig = bIgnoreConfig
  animation.bAutoFire = (data.bAutoFire == nil and true or data.bAutoFire)
  animation.bRemoveOnComplete = (data.bRemoveOnComplete == nil and true or data.bRemoveOnComplete)
  animation.Think = data.Think
  animation.OnComplete = data.OnComplete

  animation.ForceComplete = function(anim)
    anim:set(anim.duration)
  end

  -- @todo don't use ridiculous method chaining
  animation.CreateAnimation = function(currentAnimation, newLength, newData)
    newData.bAutoFire = false
    newData.index = currentAnimation.index + 1

    local oldOnComplete = currentAnimation.OnComplete
    local newAnimation = currentAnimation.subject:CreateAnimation(newLength, newData)

    currentAnimation.OnComplete = function(...)
      if (oldOnComplete) then
        oldOnComplete(...)
      end

      newAnimation:Fire()
    end

    return newAnimation
  end

  -- if (length == 0 or (! animation.bIgnoreConfig and BB_CONVAR_DISABLEANIMATION:GetBool())) then
  animation.Fire = function(anim)
    anim:set(anim.duration)
    anim.bShouldPlay = true
  end
  -- else
  --   animation.Fire = function(anim)
  --     anim:set(0)
  --     anim.bShouldPlay = true
  --   end
  -- end

  -- we can assume if we're using this library, we're not going to use the built-in
  -- AnimationTo functions, so override AnimationThink with our own
  self.AnimationThink = TweenAnimationThink

  -- fire right away if autofire is enabled
  if (animation.bAutoFire) then
    animation:Fire()
  end

  self.tweenAnimations[index] = animation
  return animation
end
