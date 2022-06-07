import "scripts/game/fishManager"

local pd <const> = playdate
local gfx <const> = pd.graphics

class('FishingLine').extends(gfx.sprite)

function FishingLine:init(fishingRod, rodX, rodY, strength, angle)
    self.fishingRod = fishingRod
    self.waterLevel = 198
    self.strength = strength
    self.rodX = rodX
    self.rodY = rodY
    self.hookX = rodX
    self.hookY = rodY
    self.lastX = -1
    self.lastY = -1
    self.xVelocity = math.cos(math.rad(angle)) * strength
    self.yVelocity = -math.sin(math.rad(angle)) * strength
    self.casting = true

    self.reelSpeed = 3
    self.reelingUp = false
    self.reelUpSpeed = 3

    self.fishCaught = false

    self.topYOffset = 50
    self.bottomYOffset = 30

    self:setCenter(0, 0)
    self:moveTo(self.rodX, self.topYOffset)
    self:add()
end

function FishingLine:drawLine()
    if self.lastX ~= self.hookX or self.lastY ~= self.hookY then
        self.lastX = self.hookX
        self.lastY = self.hookY
        local lineImage = gfx.image.new(400 - self.rodX, 240 - self.topYOffset - self.bottomYOffset)
        gfx.pushContext(lineImage)
            gfx.drawLine(self.rodX - self.rodX, self.rodY - self.topYOffset, self.hookX - self.rodX, self.hookY - self.topYOffset)
        gfx.popContext()
        self:setImage(lineImage)
    end
end

function FishingLine:reelUp()
    self.hookX = self.rodX
    self.reelingUp = true
end

function FishingLine:update()
    if self.casting then
        self.yVelocity += 9.8/30
        self.hookX += self.xVelocity
        self.hookY += self.yVelocity
        if self.hookY >= self.waterLevel then
            self.hookY = self.waterLevel
            self.xVelocity = 0
            self.yVelocity = 0
            self.casting = false
            self.fishingRod.water:impulse(self.hookX)
            self.fishManager = FishManager(self.rodX - self.hookX)
        end
    else
        if self.reelingUp then
            self.hookY -= self.reelUpSpeed
            if self.hookY <= self.rodY then
                self.hookY = self.rodY
                self.fishingRod:reeledIn()
            end
        else
            if self.fishHooked then
                self.hookX += self.fishManager:getPullStrength()
            else
                if self.fishManager:isHooked() then
                    self.fishHooked = true
                    self.fishingRod.water:impulse(self.hookX)
                end
            end
            -- Adjust crank ticks based on difficulty of fish?
            -- Increase hookX to simulate fish pulling
            local crankInput = pd.getCrankTicks(18)
            if crankInput ~= 0 then
                if self.hookX > self.rodX + 3 then
                    self.hookX -= self.reelSpeed
                else
                    self:reelUp()
                end
            end
        end
    end
    self:drawLine()
end