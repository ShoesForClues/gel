--[[
Graphic Elements Library

MIT License

Copyright (c) 2020 Shoelee

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

return function(lumiere,lib_dir)
	local eztask = lumiere:depend "eztask"
	local class  = lumiere:depend "class"
	local lmath  = lumiere:depend "lmath"
	
	local gel={
		_version = {0,5,8},
		enum     = {},
		class    = {},
		backend  = nil
	}
	
	--Enums
	gel.enum.scale_mode={
		stretch = "stretch",
		slice   = "slice",
		tile    = "tile"
	}
	gel.enum.filter_mode={
		nearest  = "nearest",
		bilinear = "bilinear",
		bicubic  = "bicubic"
	}
	gel.enum.alignment={
		x={
			left   = "left",
			right  = "right",
			center = "center"
		},
		y={
			top    = "top",
			bottom = "bottom",
			center = "center"
		}
	}
	
	--Load modules
	gel.font          = lumiere.require(lib_dir..".modules.font")    (lumiere,gel)
	gel.texture       = lumiere.require(lib_dir..".modules.texture") (lumiere,gel)
	
	--Load classes
	gel.class.object  = lumiere.require(lib_dir..".classes.object")  (lumiere,gel)
	gel.class.gui     = lumiere.require(lib_dir..".classes.gui")     (lumiere,gel)
	gel.class.element = lumiere.require(lib_dir..".classes.element") (lumiere,gel)
	gel.class.frame   = lumiere.require(lib_dir..".classes.frame")   (lumiere,gel)
	gel.class.image   = lumiere.require(lib_dir..".classes.image")   (lumiere,gel)
	gel.class.text    = lumiere.require(lib_dir..".classes.text")    (lumiere,gel)
	
	--Wrap all class methods to call backend
	for class_name,_class in pairs(gel.class) do
		for atr_name,atr in pairs(_class) do
			if type(atr)=="function" and atr_name:sub(1,2)~="__" then
				_class[atr_name]=function(instance,...)
					if 
						gel.backend
						and gel.backend.class[class_name]
						and gel.backend.class[class_name][atr_name]
					then
						return
							atr(instance,...),
							gel.backend.class[class_name][atr_name](instance,...)
					else
						return atr(instance,...)
					end
				end
			end
		end
	end
	
	function gel.new(class_name,...)
		return gel.class[class_name](...)
	end
	
	function gel:init(backend)
		gel.backend=backend(lumiere,gel)
	end
	
	return gel
end