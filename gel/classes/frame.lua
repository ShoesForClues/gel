return function(lumiere,gel)
	local eztask = lumiere:depend "eztask"
	local lmath  = lumiere:depend "lmath"
	local class  = lumiere:depend "class"
	
	local frame=gel.class.element:extend()
	
	function frame:__tostring()
		return "frame"
	end
	
	function frame:new()
		frame.super.new(self)
		
		self.background_color   = eztask.property.new(lmath.color3.new(1,1,1))
		self.background_opacity = eztask.property.new(1)
		
		self.background_color:   attach(self.append_draw,self)
		self.background_opacity: attach(self.append_draw,self)
	end
	
	function frame:delete()
		frame.super.delete(self)
	end
	
	function frame:draw()
		frame.super.draw(self)
	end
	
	return frame
end