return function(lumiere,gel)
	local eztask = lumiere:depend "eztask"
	local lmath  = lumiere:depend "lmath"
	local class  = lumiere:depend "class"
	
	local image=gel.class.frame:extend()
	
	function image:__tostring()
		return "image"
	end
	
	function image:new()
		image.super.new(self)
		
		self.image         = eztask.property.new()
		self.image_opacity = eztask.property.new(1)
		self.image_color   = eztask.property.new(lmath.color3.new(1,1,1))
		self.scale_mode    = eztask.property.new(gel.enum.scale_mode.stretch)
		self.filter_mode   = eztask.property.new(gel.enum.filter_mode.nearest)
		self.slice_center  = eztask.property.new(lmath.rect.new(0,0,0,0))
		self.tile_size     = eztask.property.new(lmath.udim2.new(1,0,1,0))
		self.rect_offset   = eztask.property.new(lmath.rect.new(0,0,1,1))
		
		self.image:         attach(self.append_draw,self)
		self.image_opacity: attach(self.append_draw,self)
		self.image_color:   attach(self.append_draw,self)
		self.scale_mode:    attach(self.append_draw,self)
		self.filter_mode:   attach(self.append_draw,self)
		self.slice_center:  attach(self.append_draw,self)
		self.tile_size:     attach(self.append_draw,self)
		self.rect_offset:   attach(self.append_draw,self)
	end
	
	function image:delete()
		image.super.delete(self)
	end
	
	function image:draw()
		image.super.draw(self)
	end
	
	return image
end