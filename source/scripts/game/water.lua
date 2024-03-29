-- Handles drawing the water. Adapted from https://gamedev.stackexchange.com/questions/44547/how-do-i-create-2d-water-with-dynamic-waves
-- I did a lot of optimizations to make this performant, and it still kinda drops the frames down to like 25-27 fps sometimes

local pd <const> = playdate
local gfx <const> = pd.graphics

-- Resolution of simulation (THIS IMPACTS PERFOMANCE A GOOD AMOUNT)
local NUM_POINTS = 30
-- Width of simulation
local WIDTH = 420 -- Blaze it
-- Spring constant for forces applied by adjacent points
local SPRING_CONSTANT = 0.005
-- Sprint constant for force applied to baseline
local SPRING_CONSTANT_BASELINE = 0.005
-- Vertical draw offset of simulation
local Y_OFFSET = 190
-- Damping to apply to speed changes
local DAMPING = 0.98
-- Number of iterations of point-influences-point to do on wave per step
-- (this makes the waves animate faster)
-- (THIS IMPACTS PERFORMANCE A DECENT AMOUNT)
local ITERATIONS = 2

local NUM_BACKGROUND_WAVES = 7
local BACKGROUND_WAVE_MAX_HEIGHT = 2
local BACKGROUND_WAVE_COMPRESSION = 1/5
-- Amounts by which a particular sine is offset
local sineOffsets = {}
-- Amounts by which a particular sine is amplified
local sineAmplitudes = {}
-- Amounts by which a particular sine is stretched
local sineStretches = {}
-- Amounts by which a particular sine's offset is multiplied
local offsetStretches = {}
-- Set each sine's values to a reasonable random value
for i=1,NUM_BACKGROUND_WAVES do
    table.insert(sineOffsets, -1 + 2*math.random())
    table.insert(sineAmplitudes, math.random()*BACKGROUND_WAVE_MAX_HEIGHT)
    table.insert(sineStretches, math.random()*BACKGROUND_WAVE_COMPRESSION)
    table.insert(offsetStretches, math.random()*BACKGROUND_WAVE_COMPRESSION)
end

class('Water').extends(gfx.sprite)

function Water:init()
    -- A phase difference to apply to each sine
    self.offset = 0

    local waterImage = gfx.image.new("images/game/water")
    self:setImage(waterImage)
    self:setZIndex(300)
    self:setCenter(0, 0)
    self.yOffset = 170
    self:moveTo(-20, self.yOffset)
    self:add()

    self.wavePoints = self:makeWavePoints(NUM_POINTS)
end

-- This creates that cool splash effect. Since the wave resolution (NUM_POINTS) isn't
-- super high for performance reasons, it sometimes splashes to the side of where the hook
-- is, which is fine for the sake of performance
function Water:impulse(hookX)
    local closestPoint = nil
    local closestDistance = nil
    for _,p in ipairs(self.wavePoints) do
        local distance = math.abs(hookX-p.x)
        if closestDistance == nil then
            closestPoint = p
            closestDistance = distance
        else
            if distance <= closestDistance then
                closestPoint = p
                closestDistance = distance
            end
        end
    end

    closestPoint.y += (hookX / 12)
end

function Water:update()
    self.offset = self.offset + 1
    self:updateWavePoints(self.wavePoints)
    local waterImage = gfx.image.new(450, 240 - self.yOffset - 20)
    -- Couldn't find a good way to optimize the drawing of the wave. I currently have it
    -- drawing on an image at a fixed height, but ideally the size of the image would dynamically
    -- change based on the actual size needed to draw the wave to not draw unecessarily
    gfx.pushContext(waterImage)
        for n,p in ipairs(self.wavePoints) do
            if n ~= 1 then
                local leftPoint = self.wavePoints[n-1]
                local x1 = leftPoint.x
                local y1 = leftPoint.y + self:overlapSines(leftPoint.x)
                local x2 = p.x
                local y2 = p.y + self:overlapSines(p.x)
                gfx.setColor(gfx.kColorWhite)
                local rectHeight = 20
                local rectWidth = x2 - x1
                local rectX = x1 + rectWidth / 2
                local rectY = y2
                -- So I actually draw a bunch of thin white rectangles beneath the wave, to cover
                -- up the pier stilts and also the fishing line when it goes into the water. This has
                -- a big performance impact, but I think it's maybe necessary to get that realistic water
                -- cover up. Definetly a better way to do this
                gfx.fillRect(rectX, rectY - self.yOffset, rectWidth + 1, rectHeight)
                -- Actual wave line drawn here
                gfx.setColor(gfx.kColorBlack)
                gfx.drawLine(x1, y1 - self.yOffset, x2, y2 - self.yOffset)
            end
        end
    gfx.popContext()
    self:setImage(waterImage)
end

-- Make points to go on the wave
function Water:makeWavePoints(numPoints)
    local t = {}
    for n = 1,numPoints do
        -- This represents a point on the wave
        local newPoint = {
            x    = n / numPoints * WIDTH,
            y    = Y_OFFSET,
            spd = {y=0}, -- speed with vertical component zero
            mass = 1
        }
        t[n] = newPoint
    end
    return t
end

-- Update the positions of each wave point
-- Basically each point is like a spring and pulls on adjacent points.
-- IDK just copied the code kekW
function Water:updateWavePoints(points)
    for i=1,ITERATIONS do
        for n,p in ipairs(points) do
            -- force to apply to this point
            local force = 0

            -- forces caused by the point immediately to the left or the right
            local forceFromLeft, forceFromRight

            if n == 1 then -- wrap to left-to-right
                local dy = points[# points].y - p.y
                forceFromLeft = SPRING_CONSTANT * dy
            else -- normally
                local dy = points[n-1].y - p.y
                forceFromLeft = SPRING_CONSTANT * dy
            end
            if n == # points then -- wrap to right-to-left
                local dy = points[1].y - p.y
                forceFromRight = SPRING_CONSTANT * dy
            else -- normally
                local dy = points[n+1].y - p.y
                forceFromRight = SPRING_CONSTANT * dy
            end

            -- Also apply force toward the baseline
            local dy = Y_OFFSET - p.y
            forceToBaseline = SPRING_CONSTANT_BASELINE * dy

            -- Sum up forces
            force = force + forceFromLeft
            force = force + forceFromRight
            force = force + forceToBaseline

            -- Calculate acceleration
            local acceleration = force / p.mass

            -- Apply acceleration (with damping)
            p.spd.y = DAMPING * p.spd.y + acceleration

            -- Apply speed
            p.y = p.y + p.spd.y
        end
    end
end

-- Creates organic looking waves from basically overlapping a
-- bunch of sine waves. I think. Not sure.
function Water:overlapSines(x)
    local result = 0
    for i=1,NUM_BACKGROUND_WAVES do
        result = result
            + sineOffsets[i]
            + sineAmplitudes[i] * math.sin(
                x * sineStretches[i] + self.offset * offsetStretches[i])
    end
    return result
end