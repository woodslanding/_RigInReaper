------------------------------MSLIDER--------------------------------
-- The core library must be loaded prior to anything else
local libPath = reaper.GetExtState("Scythe v3", "libPath")
if not libPath or libPath == "" then
    reaper.MB("Couldn't load the Scythe library. Please install 'Scythe library v3' from ReaPack, then run 'Script: Scythe_Set v3 library path.lua' in your Action List.", "Whoops!", 0)
    return
end
package.path = debug.getinfo(1,"S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path
loadfile(libPath .. "scythe.lua")()

require 'MoonUtils'

local GUI = require("gui.core")
local M = require("public.message")
local Image = require("public.image")

local Buffer = require("public.buffer")
local Font = require("public.font")
local Color = require("public.color")
local Math = require("public.math")
local Table = require("public.table")
local Sprite = require("public.sprite")
local GFX = require("public.gfx")
local T = Table.T
local Element = require("gui.element")
local Text = require("public.text")

local font = {'Calibri', 28, 'b'}
local lenX, lenY, origW

local MSlider = Element:new()
MSlider.__index = MSlider
MSlider.defaultProps = {
    name = "mslider"..math.random(),
    type = "MSLIDER", displayOnly = false,
    frames = 20, horizontal = false,
    x = 16, y = 32, w = 24, h = 24,
    labelX = 0, labelY = 0,
    caption = "", font = 3, textColor = "text",
    fontSize = 28,
    func = function () end,
    params = {},
    min = 0,
    max = 1,
    sens = 1,
    value = 0,
    frame = 5,
    vertFrames = true,
    shadow = true,
    center = true,  -- 0 for left, 1 for right
    waitToSet = false  --if true, don't actually run the func() until the mouse is released..
}

function MSlider:new(props)
    local MSlider = self:addDefaultProps(props)
    return setmetatable(MSlider, self)
end


function MSlider:init()
    self.sprite = Sprite:new({})
    if self.image then
        self.sprite:setImage(self.image)
        self.sprite.frame = { w = self.w, h = self.h }
    end
    self:val(self.value)
    self.hasBeenDragging = false
    self.dragStartX = 0
    self.dragStartY = 0
    self.origVal = 0
    --well, I could imagine implementing an invisible slider someday....
    --if not self.sprite.image then error("MSlider: The specified image was not found") end
end

--this keeps the component from responding to the mouse
function MSlider:containsPoint (x, y)
    if self.displayOnly then return false
    else return  ( x >= (self.x or 0) and x < ((self.x or 0) + (self.w or 0)) and
                   y >= (self.y or 0) and y < ((self.y or 0) + (self.h or 0)) )
    end
end

function MSlider:draw()

    local x, y, w, h = self.x, self.y, self.w, self.h
    local strWidth, strHeight
    gfx.mode = 0

    --if self.horizontal then

        if self.color then
            Color.set(self.color)
            local round = self.round or 0
            GFX.roundRect(self.x, self.y, self.w-1, self.h-1, round, true, true)
        end

        self.sprite:draw(x, y, w, h, self.frame, self.frames, self.vertFrames)
        -- Draw the caption
        Color.set(self.textColor)
        Font.set({'calibri',self.fontSize,'b'})

        local str = self:formatOutput(self.caption)
        --MSG('caption = '..self.caption)
        str = str:gsub([[\n]],"\n")

        strWidth, strHeight = gfx.measurestr(str)
        local playX = w - strWidth
        local playY = h - strHeight

        gfx.x = x + (playX / 2) + (self.labelX * playX)
        gfx.y = y + (playY / 2) + (self.labelY * playY)
        gfx.drawstr(str)

    --[[else
        local dest = gfx.dest
        gfx.x, gfx.y = 0,0

        Font.set({'calibri',self.fontSize,'b'})
        local str = self:formatOutput(self.caption)
        MSG('caption = '..self.caption)

        strWidth, strHeight = gfx.measurestr(str)
        MSG('width, height = ',strWidth,strHeight)
        local playX, playY = (h - strWidth)/2, (w - strHeight)/2
        local xpos, ypos
        if self.center then
            xpos = playX + (playX * self.labelX)
            ypos = playY + (playY * self.labelY)
        else
            xpos = self.labelY
            ypos = self.labelX
        end
        Color.set(self.color)
        local buff = Buffer.get()
        gfx.dest = buff;                   -- draw to off-screen buffer
        gfx.setimgdim(buff, -1, -1)      -- clear the buffer
        gfx.setimgdim(buff, h + 1, w)  -- sets its size.  For some reason it's a pixel small in one direction
        gfx.rect(0,0, h, w)           -- set the bg colour, for improved anti-aliasing
        if self.color then
            Color.set(self.color)
            local round = self.round or 0
            GFX.roundRect(0, 0, w, h, round, true, true)
        end

        gfx.a = 1

        self.sprite:draw(x, y, w, h, self.frame, self.frames, self.vertFrames)

        -- Draw the caption
        --gfx.r = save_gfxr; gfx.g = save_gfxg; gfx.b = save_gfxb -- set the text colour

        Color.set(self.textColor)

        gfx.x = xpos
        gfx.y = ypos

        gfx.printf("%s", str)

        gfx.dest=-1;                           -- switch back to on-screen
        gfx.mode = 0 +1-1 + 2 +4               -- blend mode (1) deactivated, disable source alpha (2),
        gfx.transformblit(buff,  x,y, w, h, 2,2,  { h,0,  h,w,  0,0,  0,w, } )

        gfx.dest = dest
    end--]]
end

function MSlider:onMouseDown(state)
    self.dragStartX = state.mouse.x
    self.dragStartY = state.mouse.y
    self.origVal = self.value
end
--A drag works normally, but you can touch the fader to immediately go to a specific value
--Todo:  fade to new value?
function MSlider:onMouseUp(state)
    if  not self.hasBeenDragging  then
        --move slider to mouse position
        local pct
        if self.horizontal then
            pct = (state.mouse.x - self.x)/self:throw()
        else  pct = 1 - ((state.mouse.y - self.y)/self:throw()) --y measured from top!
        end
        local v = self:val()
        self:func(table.unpack(self.params))
    elseif self.waitToSet then self:func(table.unpack(self.params))
    end
    self.hasBeenDragging = false
end

-- Will continue being called even if you drag outside the element
function MSlider:onDrag(state)
    self.hasBeenDragging = true
    local pixval = self:getRange()/self:throw()
    local delta
    if self.horizontal then delta = state.mouse.x - self.dragStartX else delta = self.dragStartY - state.mouse.y end
    local newVal = (delta * pixval) + self.origVal
    local v = Math.clamp(newVal,self.min,self.max)
    --MSG('newVal - '..newVal)
    self:val(v)
    if not self.waitToSet then self:func(table.unpack(self.params)) end

end

function MSlider:setColor(color)
    self.color = color
    self:redraw()
end

function MSlider:setCaption(caption)
    self.caption= caption
    self:redraw()
end

function MSlider:getRange() return self.max - self.min end

function MSlider:throw()
    local throw
    if self.horizontal then throw = self.w else throw = self.h end
    return throw
end

function MSlider:val(incoming)
    if incoming then
        self.value = incoming
        MSG('incoming val: '..incoming)
        local pct = ((self.value - self.min)/self:getRange())
        local frame = Math.round((self.frames-1) * pct)
        MSG("FRAME = "..frame)
        if frame < 0 then frame = 0 elseif frame > self.frames - 1 then frame = self.frames - 1 end
        self.frame = frame
        self:redraw()
    else return self.value
    end
end

GUI.elementClasses.MSlider = MSlider
--
slider = GUI.createElement({
    frames = 49, frame = 5,
    horizontal = true,
    caption = 'TESTING',
    name = "slider",
    min = -.5,
    max = .5,
    value = 0,
    fontSize = 36,
    type = "MSlider",
    color = 'red',
    w = 180,h = 48,x = 0,y = 0,
    labelX = 0,labelY = 0,
    image = IMAGE_FOLDER.."SimpleFader.png",
    func = function(self) vSlider.labelX = self:val() end,
    params = {"a", "b", "c"}
  })

  slider2 = GUI.createElement({
    frames = 49, frame = 5,
    horizontal = true,
    caption = 'TESTING',
    name = "slider2",
    min = -.5,
    max = .5,
    value = 0,
    fontSize = 36,
    type = "MSlider",
    color = 'red',
    w = 180,h = 48,x = 0,y = 48,
    labelX = 0,labelY = 0,
    image = IMAGE_FOLDER.."SimpleFader.png",
    func = function(self) vSlider.labelY = self:val() end,
    params = {"a", "b", "c"}
  })

  vSlider = GUI.createElement({
    frames = 108, frame = 0,
    horizontal = false,
    caption = 'test caption',
    name = "vslider",
    min = 0,
    max = 99,
    fontSize = 36,
    value = 0,
    color = 'blue',
    type = "MSlider",
    w = 64,h = 288,x = 200,y = 10,
    labelX = 0,labelY = 0,
    image =  IMAGE_FOLDER.."Volume.png",
    func = function(self, a, b, c) self.caption = self.value end,
    params = {"a", "b", "c"}
  })
------------------------------------
-------- Window settings -----------
------------------------------------

local window = GUI.createWindow({
  name = "MSLIDER TEST",
  w = 600,
  h = 400
})

------------------------------------
-------- GUI Elements --------------
------------------------------------

local layer = GUI.createLayer({name = "Layer1", z = 1})

layer:addElements(vSlider, slider, slider2)
window:addLayers(layer)
window:open()

GUI.Main()--]]
