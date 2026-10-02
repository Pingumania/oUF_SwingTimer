--[[
# Element: Swing Timer

Handles the visibility and updating of the player's auto attack swing timers.

## Widget

SwingTimer - A `table` or `Frame` holding the sub-widgets.

## Sub-Widgets

.MainHand - A `StatusBar` used to represent the main hand swing timer.
.OffHand  - A `StatusBar` used to represent the off hand swing timer.
.Ranged   - A `StatusBar` used to represent the ranged swing timer.

## Sub-Widgets of each StatusBar

.Time - A `FontString` used to represent the time until the next swing.

## Sub-Widget options

.Time.binding   - A [`DurationTextBinding`](https://warcraft.wiki.gg/wiki/ScriptObject_DurationTextBinding) object to override the default
.Time.formatter - A [`NumericFormatter`](https://warcraft.wiki.gg/wiki/ScriptObject_NumericFormatter) to override the default

## Notes

Only available for the `player` unit, and only in WoW Forever.

A StatusBar is shown while the player can attack with the matching weapon, and hidden otherwise.

A default texture will be applied to the StatusBar widgets if they don't have a texture or a color set.

## Options

.smoothing - Which status bar smoothing method to use, defaults to `Enum.StatusBarInterpolation.Immediate` (number)

## Examples

    local SwingTimer = {}

    for index, key in ipairs({'MainHand', 'OffHand', 'Ranged'}) do
        local Bar = CreateFrame('StatusBar', nil, self)
        Bar:SetSize(120, 6)
        Bar:SetPoint('TOP', self, 'BOTTOM', 0, -8 * index)

        local Time = Bar:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
        Time:SetPoint('RIGHT', Bar)
        Bar.Time = Time

        SwingTimer[key] = Bar
    end

    -- Register with oUF
    self.SwingTimer = SwingTimer
--]]

local _, ns = ...
local oUF = ns.oUF or oUF

assert(oUF, "oUF_SwingTimer was unable to locate oUF install.")

if not C_SwingTimer then
	return
end

local defaultFormatter = C_StringUtil.CreateSecondsFormatter()
defaultFormatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
defaultFormatter:SetMinInterval(Enum.SecondsFormatterInterval.Seconds)
defaultFormatter:SetMillisecondsThreshold(60)

local BAR_KEYS = {
	[Enum.PlayerSwingType.MainHand] = "MainHand",
	[Enum.PlayerSwingType.OffHand] = "OffHand",
	[Enum.PlayerSwingType.Ranged] = "Ranged",
}

local function UpdateBar(bar, attackSpeed)
	if bar then
		bar:SetShown(issecretvalue(attackSpeed) or (attackSpeed ~= nil and attackSpeed > 0))
	end
end

local function Update(self, event)
	local element = self.SwingTimer

	--[[ Callback: SwingTimer:PreUpdate()
	Called before the element has been updated.

	* self - the SwingTimer element
	--]]
	if element.PreUpdate then
		element:PreUpdate()
	end

	local mainHandSpeed, offHandSpeed, rangedSpeed = UnitAttackSpeed("player")
	UpdateBar(element.MainHand, mainHandSpeed)
	UpdateBar(element.OffHand, offHandSpeed)
	UpdateBar(element.Ranged, rangedSpeed)

	--[[ Callback: SwingTimer:PostUpdate(mainHandSpeed, offHandSpeed, rangedSpeed)
	Called after the element has been updated.

	* self          - the SwingTimer element
	* mainHandSpeed - the main hand attack speed in seconds (number)
	* offHandSpeed  - the off hand attack speed in seconds (number?)
	* rangedSpeed   - the ranged attack speed in seconds (number?)
	--]]
	if element.PostUpdate then
		return element:PostUpdate(mainHandSpeed, offHandSpeed, rangedSpeed)
	end
end

local function Path(self, ...)
	--[[ Override: SwingTimer.Override(self, event, ...)
	Used to completely override the internal update function.

	* self  - the parent object
	* event - the event triggering the update (string)
	* ...   - the arguments accompanying the event
	--]]
	return (self.SwingTimer.Override or Update)(self, ...)
end

local function Swing(self, event, swingDuration, swingType)
	local element = self.SwingTimer
	local key = BAR_KEYS[swingType]
	local bar = key and element[key]

	if not bar then
		return
	end

	bar.duration:SetTimeFromStart(GetTime(), swingDuration)
	bar:SetTimerDuration(bar.duration, element.smoothing, Enum.StatusBarTimerDirection.ElapsedTime)

	if bar.Time then
		bar.Time.binding:SetDuration(bar.duration)
	end

	--[[ Callback: SwingTimer:PostSwing(bar, swingType, swingDuration)
	Called after a StatusBar has been updated upon a swing.

	* self          - the SwingTimer element
	* bar           - the StatusBar for the swing type (StatusBar)
	* swingType     - the type of the swing, see `Enum.PlayerSwingType` (number)
	* swingDuration - the time until the next swing in seconds (number)
	--]]
	if element.PostSwing then
		return element:PostSwing(bar, swingType, swingDuration)
	end
end

local function ForceUpdate(element)
	return Path(element.__owner, "ForceUpdate")
end

local function Enable(self, unit)
	local element = self.SwingTimer

	if not element or unit ~= "player" then
		return
	end

	element.__owner = self
	element.ForceUpdate = ForceUpdate

	if not element.smoothing then
		element.smoothing = Enum.StatusBarInterpolation.Immediate
	end

	local bar, time

	for _, key in next, BAR_KEYS do
		bar = element[key]

		if bar then
			time = bar.Time

			if time then
				if not time.binding then
					time.binding = C_DurationUtil.CreateDurationTextBinding()
					time.binding:SetFormatter(time.formatter or defaultFormatter)
				end

				time.binding:SetFontString(time)
				time.binding:SetEnabled(true)
			end

			if not bar.duration then
				bar.duration = C_DurationUtil.CreateDuration()
			end

			if bar:IsObjectType("StatusBar") and not bar:GetStatusBarTexture() then
				bar:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
			end
		end
	end

	self:RegisterEvent("PLAYER_SWING", Swing, true)
	self:RegisterEvent("WEAPON_SLOT_CHANGED", Path, true)
	self:RegisterEvent("UNIT_ATTACK_SPEED", Path)

	return true
end

local function Disable(self)
	local element = self.SwingTimer

	if not element then
		return
	end

	local bar

	for _, key in next, BAR_KEYS do
		bar = element[key]

		if bar then
			bar:Hide()

			if bar.Time then
				bar.Time.binding:SetEnabled(false)
			end
		end
	end

	self:UnregisterEvent("PLAYER_SWING", Swing)
	self:UnregisterEvent("WEAPON_SLOT_CHANGED", Path)
	self:UnregisterEvent("UNIT_ATTACK_SPEED", Path)
end

oUF:AddElement("SwingTimer", Path, Enable, Disable)
