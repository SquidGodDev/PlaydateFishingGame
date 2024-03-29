local pd <const> = playdate
local gfx <const> = pd.graphics

class('TensionBar').extends(gfx.sprite)

function TensionBar:init(tension, tensionRate, fishingLine)
    self.tension = math.random(math.ceil(tension * 0.8), math.ceil(tension * 1.2))
    if self.tension >= 99 then
        self.tension = 99
    elseif self.tension <= 0 then
        self.tension = 0
    end
    self.tensionRate = math.random(math.ceil(tensionRate * 0.8 * 100), math.ceil(tensionRate * 1.2 * 100)) / 100
    self.fishingLine = fishingLine
    self.tensionLossVelocity = 0
    self.tensionLossAcceleration = 0.05
    self.maxTension = 100

    self.tensionBarWidth = 15
    self.tensionBarHeight = 120
    self.tensionBarCornerRadius = 2

    self.tensionBarRunning = true

    self.tensionBarBackground = gfx.image.new(self.tensionBarWidth, self.tensionBarHeight)
    gfx.pushContext(self.tensionBarBackground)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRoundRect(0, 0, self.tensionBarWidth, self.tensionBarHeight, self.tensionBarCornerRadius)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRoundRect(0, 0, self.tensionBarWidth, self.tensionBarHeight, self.tensionBarCornerRadius)
    gfx.popContext()
    self:setImage(self.tensionBarBackground)

    local lineBreakIconImage = gfx.image.new("images/game/lineBreakIcon")
    self.lineBreakIcon = gfx.sprite.new(lineBreakIconImage)

    self.transitionTime = 800
    self.offScreenX = 420
    self.tensionBarX = 380
    self.enterAnimator = gfx.animator.new(self.transitionTime, self.offScreenX, self.tensionBarX, pd.easingFunctions.inOutCubic)
    self.exitAnimator = nil

    self.tensionBarY = 100
    self:moveTo(self.offScreenX, self.tensionBarY)
    self.lineBreakIcon:moveTo(self.offScreenX, self.tensionBarY - self.tensionBarHeight / 2 - 15)

    self:setZIndex(100)
    self:add()
    self.lineBreakIcon:setZIndex(100)
    self.lineBreakIcon:add()

    self.lineSnapSound = pd.sound.sampleplayer.new("sound/LineSnap")
end

function TensionBar:drawTensionBar()
    local tensionLevelHeight = (self.tension / self.maxTension) * self.tensionBarHeight
    local tensionLevelY = self.tensionBarHeight - tensionLevelHeight
    local tensionBarImage = self.tensionBarBackground:copy()
    gfx.pushContext(tensionBarImage)
        gfx.fillRoundRect(0, tensionLevelY, self.tensionBarWidth, tensionLevelHeight, self.tensionBarCornerRadius)
    gfx.popContext()
    self:setImage(tensionBarImage)
end

function TensionBar:increaseTension(struggling)
    if self.tensionBarRunning then
        local struggleTension = 0
        if struggling then
            struggleTension = self.tensionRate * 0.25
        end
        self.tension += self.tensionRate + struggleTension
        self.tensionLossVelocity = 0
        if self.tension >= self.maxTension then
            self.lineSnapSound:play()
            self.fishingLine:reeledIn(false)
        end
    end
end

function TensionBar:stopTensionBar()
    self.tensionBarRunning = false
    if not self.exitAnimator then
        self.exitAnimator = gfx.animator.new(self.transitionTime, self.tensionBarX, self.offScreenX, pd.easingFunctions.inOutCubic)
    end
end

function TensionBar:update()
    if self.enterAnimator then
        local xPos = self.enterAnimator:currentValue()
        self:moveTo(xPos, self.y)
        self.lineBreakIcon:moveTo(xPos, self.lineBreakIcon.y)
        if self.enterAnimator:ended() then
            self.enterAnimator = nil
        end
    elseif self.exitAnimator then
        local xPos = self.exitAnimator:currentValue()
        self:moveTo(xPos, self.y)
        self.lineBreakIcon:moveTo(xPos, self.lineBreakIcon.y)
        if self.exitAnimator:ended() then
            self:remove()
        end
    end

    if self.tensionBarRunning then
        self.tensionLossVelocity += self.tensionLossAcceleration
        self.tension -= self.tensionLossVelocity
        if self.tension <= 0 then
            self.tension = 0
        end
        self:drawTensionBar()
    end
end