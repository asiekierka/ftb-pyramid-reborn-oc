local component = require("component")
local unicode = require("unicode")
local gpu = component.gpu
local chars = {" ", unicode.char(0x2584), unicode.char(0x2580), unicode.char(0x2588)}
local palette = {}

local function round(v)
	return math.floor(v + 0.5)
end

local function genPalette(data)
 for i=0,255 do
  if (i < 16) then
    if data == nil then
      palette[i+1] = (i * 15) << 16 | (i * 15) << 8 | (i * 15)
    else
      palette[i+1] = data[3][i]
      gpu.setPaletteColor(i, data[3][i])
    end
  else
    local j = i - 16
    local b = math.floor((j % 5) * 255 / 4.0)
    local g = math.floor((math.floor(j / 5.0) % 8) * 255 / 7.0)
    local r = math.floor((math.floor(j / 40.0) % 6) * 255 / 5.0)
    palette[i+1] = r << 16 | g << 8 | b
  end
 end
end

genPalette(nil)

-- https://www.compuphase.com/cmetric.htm
local function getColorDistance(c1, c2)
	local rMean = (((c1 >> 16) & 255) + ((c2 >> 16) & 255)) / 2
	local r = ((c1 >> 16) & 255) - ((c2 >> 16) & 255)
	local g = ((c1 >> 8) & 255) - ((c2 >> 8) & 255)
	local b = (c1 & 255) - (c2 & 255)
	return (((512 + rMean) * r * r) / 256) + 4*g*g + (((767 - rMean) * b * b) / 256)
end

local function getColorNearest(color)
	-- we're going to be terrible hacks
	-- we have 16 grayscale colors + a 6*8*5 cube
	local gray = round((0.299 * ((color >> 16) & 255) + 0.587 * ((color >> 8) & 255) + 0.114 * (color & 255)) * 17 / 255)
	local grayC = math.floor(gray * 255 / 16) * 0x10101
	local c

	if gray == 0 then c = 17
	elseif gray == 17 then c = 256
	else c = gray end

	if color == grayC then return c, grayC end
	local smallestColor = grayC
	local smallestDist = getColorDistance(color, grayC)

	local rb = round(((color >> 16) & 255) * 5 / 255)
	local gb = round(((color >> 8) & 255) * 7 / 255)
	local bb = round(((color) & 255) * 4 / 255)

	for r=rb-1,rb+1 do for g=gb-1,gb+1 do for b=bb-1,bb+1 do
		if r >= 0 and g >= 0 and b >= 0 and r < 6 and g < 8 and b < 5 then
			local rgb = 17 + (r * 40) + (g * 5) + b
			local rgbC = (math.floor(r * 255 / 5) << 16) | (math.floor(g * 255 / 7) << 8) | math.floor(b * 255 / 4)
			if color == rgbC then return rgb, rgbC end
			local dist = getColorDistance(color, rgbC)
			if dist < smallestDist then
				c = rgb
				smallestColor = rgbC
				smallestDist = dist
			end
		end
	end end end
	return c, smallestColor
end

local function getColorNearestFast(color)
	-- we're going to be terrible hacks
	-- we have 16 grayscale colors + a 6*8*5 cube
	local gray = round((0.299 * ((color >> 16) & 255) + 0.587 * ((color >> 8) & 255) + 0.114 * (color & 255)) * 17 / 255)
	local grayC = math.floor(gray * 255 / 16) * 0x10101
	local r = round(((color >> 16) & 255) * 5 / 255)
	local g = round(((color >> 8) & 255) * 7 / 255)
	local b = round(((color) & 255) * 4 / 255)
	local rgb = 17 + (r * 40) + (g * 5) + b
	local rgbC = (math.floor(r * 255 / 5) << 16) | (math.floor(g * 255 / 7) << 8) | math.floor(b * 255 / 4)
	if getColorDistance(color, grayC) < getColorDistance(color, rgbC) then
		if gray == 0 then
			return 17, grayC
		elseif gray == 17 then
			return 256, grayC
		else
			return gray, grayC
		end
	else
		return rgb, rgbC
	end  
end

local function addQuantError(col, re, ge, be, m)
	if col == nil or col == -1 then return col end
	m = m * 1.0
	local r = ((col >> 16) & 255) + round(re*m)
	local g = ((col >> 8) & 255) + round(ge*m)
	local b = (col & 255) + round(be*m)
	if r < 0 then r = 0 end
	if g < 0 then g = 0 end
	if b < 0 then b = 0 end
	if r > 255 then r = 255 end
	if g > 255 then g = 255 end
	if b > 255 then b = 255 end
	return (math.floor(r) << 16) | (math.floor(g) << 8) | (math.floor(b))
end

local exports = {}

function exports.draw(png, xp, yp, w, h, dither, bgColor)
	local colors = {}
	if w == nil then w = png.w end
	if h == nil then h = png.h end
	local wm = png.w / w
	local hm = png.h / h
 if bgColor == nil then bgColor = 0 end
 local bgcp, bgcc = getColorNearest(bgColor)
 bgColor = bgcc
	for y=1,h do
		colors[y] = {}
		for x=1,w do
   local alpha = png:getAlpha(math.floor((x-1) * wm), math.floor((y-1) * hm), false)
   if alpha < 16 then
     colors[y][x] = -1
   else
     colors[y][x] = png:get(math.floor((x-1) * wm), math.floor((y-1) * hm), false)
   end
		end
	end
	for y=1,h do
		for x=1,w do
			local c1 = colors[y][x]
   local l_dither = dither
   local ci, c2 = 0, 0
   if c1 == -1 then
     ci, c2 = getColorNearest(bgColor)
     c1 = c2
   else
			  ci, c2 = getColorNearest(c1)
   end
			colors[y][x] = ci
			if l_dither then
				local r = ((c1 >> 16) & 255) - ((c2 >> 16) & 255)
				local g = ((c1 >> 8) & 255) - ((c2 >> 8) & 255)
				local b = (c1 & 255) - (c2 & 255)
				colors[y][x+1] = addQuantError(colors[y][x+1], r, g, b, 7/16.0)
				if y < h then
					colors[y+1][x-1] = addQuantError(colors[y+1][x-1], r, g, b, 3/16.0)
					colors[y+1][x] = addQuantError(colors[y+1][x], r, g, b, 5/16.0)
					colors[y+1][x+1] = addQuantError(colors[y+1][x+1], r, g, b, 1/16.0)
				end
			end
		end
	end
	local oldBG = nil
	local oldFG = nil
	for y=1,h-1,2 do
		local str = ""
		local strx = 1
		for x=1,w do
			local bg = colors[y][x]
			local fg = colors[y+1][x]
			local chr = chars[2]
			if bg == fg then
				if oldBG == bg then
					chr = chars[1]
				elseif oldFG == fg then
					chr = chars[4]
				end
			elseif oldBG == fg and oldFG == bg then
				chr = chars[3]
			end
			local refresh = false
			if chr ~= chars[4] and oldBG ~= bg then refresh = true end
			if chr ~= chars[1] and oldFG ~= fg then refresh = true end
			if refresh then
				gpu.set(xp+strx - 1, yp+((y - 1) / 2), str)
				if oldBG ~= bg then gpu.setBackground(palette[bg]) end
				if oldFG ~= fg then gpu.setForeground(palette[fg]) end
				str = ""
				strx = x
				oldBG = bg
				oldFG = fg
			end
			str = str .. chr
		end
		if #str > 0 then gpu.set(xp+strx - 1, yp+((y - 1) / 2), str) end
	end
	gpu.setBackground(0x000000)
	gpu.setForeground(0xFFFFFF)
end

return exports