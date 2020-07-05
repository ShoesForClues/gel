return function(lumiere,gel)
	local eztask = lumiere:depend "eztask"
	local lmath  = lumiere:depend "lmath"
	local class  = lumiere:depend "class"
	
	local element=gel.class.object:extend()
	
	function element:__tostring()
		return "element"
	end
	
	function element:new()
		element.super.new(self)
		
		self.redraw=true
		
		self.visible           = eztask.property.new(true)
		self.position          = eztask.property.new(lmath.udim2.new(0,0,0,0))
		self.size              = eztask.property.new(lmath.udim2.new(0,0,0,0))
		self.rotation          = eztask.property.new(0)
		self.anchor_point      = eztask.property.new(lmath.vector2.new(0,0))
		self.clip              = eztask.property.new(false)
		self.reactive          = eztask.property.new(false)
		
		--Read only
		self.gui               = eztask.property.new()
		self.clip_parent       = eztask.property.new()
		self.cframe            = eztask.property.new(lmath.cframe.new())
		self.absolute_size     = eztask.property.new(lmath.vector2.new(0,0))
		self.absolute_position = eztask.property.new(lmath.vector2.new(0,0))
		self.absolute_rotation = eztask.property.new(self.rotation.value)
		self.targeted          = eztask.property.new(false)
		self.selected          = eztask.property.new(false)
		
		self.clicked           = eztask.signal.new()
		self.pressed           = eztask.signal.new()
		self.released          = eztask.signal.new()
		
		--Ugly callbacks!
		self.child_removed:     attach(self.append_redraw,self)
		self.child_added:       attach(self.append_redraw,self)
		self.absolute_size:     attach(self.append_redraw,self)
		
		self.index:             attach(self.append_draw,self)
		self.visible:           attach(self.append_draw,self)
		self.absolute_position: attach(self.append_draw,self)
		self.absolute_rotation: attach(self.append_draw,self)
		
		self.parent:            attach(self.append_transformation,self)
		self.gui:               attach(self.append_transformation,self)
		self.clip_parent:       attach(self.append_transformation,self)
		self.position:          attach(self.append_transformation,self)
		self.rotation:          attach(self.append_transformation,self)
		self.anchor_point:      attach(self.append_transformation,self)
		self.size:              attach(self.append_transformation,self)
		
		self.parent:            attach(self.append_parent_gui,self)
		self.gui:               attach(self.append_child_gui,self)
		self.targeted:          attach(self.append_targeted,self)
		self.pressed:           attach(self.append_pressed,self)
		self.released:          attach(self.append_released,self)
	end
	
	function element:delete()
		element.super.delete(self)
	end
	
	function element:draw_begin() end
	function element:draw_end() end
	function element:draw() end
	
	function element:render()
		if not self.visible.value then
			return
		end
		
		self:draw_begin()
		
		if self.redraw or not self.clip.value then
			for _,child in pairs(self.children) do
				if child:is(element) then
					child.clip_parent.value=(
						self.clip.value and self
						or self.clip_parent.value
					)
					child:render()
				end
			end
		end
		
		self.redraw=false
		self:draw_end()
	end
		
	function element:append_draw()
		if not self.parent.value then
			return
		end
		if not self.parent.value.append_redraw then
			return
		end
		self.parent.value:append_redraw()
	end
	
	function element:append_redraw()
		if self.redraw then
			return
		end
		self.redraw=true
		self:append_draw()
	end
	
	function element:append_transformation()
		local parent = self.parent.value
		local size   = self.size.value
		local pos    = self.position.value
		local rot    = self.rotation.value
		local anchor = self.anchor_point.value
		
		local parent_abs_size
		local parent_abs_rot
		local parent_cframe
		
		if parent and parent:is(element) then
			parent_abs_size = parent.absolute_size.value
			parent_abs_rot  = parent.absolute_rotation.value
			parent_cframe   = parent.cframe.value
		elseif self.gui.value then
			parent_abs_size = self.gui.value.resolution.value
			parent_abs_rot  = 0
			parent_cframe   = lmath.cframe.new(
				self.gui.value.resolution.value.x*0.5,
				0,
				self.gui.value.resolution.value.y*0.5
			)
		else
			parent_abs_size = lmath.vector2.new()
			parent_abs_rot  = 0
			parent_cframe   = lmath.cframe.new()
		end
		
		local absolute_size=lmath.vector2.new(
			size.x_offset+size.x_scale*parent_abs_size.x,
			size.y_offset+size.y_scale*parent_abs_size.y
		)
		local cframe=(
			parent_cframe
			*lmath.cframe.new(
				-parent_abs_size.x*0.5
				+pos.x_offset+pos.x_scale*parent_abs_size.x,
				0,
				-parent_abs_size.y*0.5
				+pos.y_offset+pos.y_scale*parent_abs_size.y
			)
			*lmath.cframe.from_euler(0,rot,0)
			*lmath.cframe.new(
				absolute_size.x*0.5-absolute_size.x*anchor.x,
				0,
				absolute_size.y*0.5-absolute_size.y*anchor.y
			)
		)
		local absolute_position=(
			cframe
			*lmath.vector3.new(
				-absolute_size.x*0.5,
				0,
				-absolute_size.y*0.5
			)
		)
		
		self.cframe.value            = cframe
		self.absolute_size.value     = absolute_size
		self.absolute_rotation.value = parent_abs_rot+rot
		self.absolute_position.value = lmath.vector2.new(
			absolute_position.x,
			absolute_position.z
		)
		
		for _,child in pairs(self.children) do
			if child.append_transformation then
				child:append_transformation()
			end
		end
	end
	
	function element:append_cursor(x,y,button,id,state) --Mouse ID=1, Touch ID=2,3,4...
		local debounce=false
		
		local relative_point=(
			self.cframe.value:inverse()
			*lmath.vector3.new(x,0,y)
		)
		local in_bound=(
			relative_point.x>=0
			and relative_point.z>=0
			and relative_point.x<self.absolute_size.value.x
			and relative_point.z<self.absolute_size.value.y
		)
		
		self.targeted.value=in_bound
		
		if in_bound and self.gui.value then
			self.gui.value.targeted_elements[self]=self
			if button then
				if state then
					self.pressed(button,id,x,y)
				else
					self.released(button,id,x,y)
				end
			end
			debounce=self.reactive.value
		end
		
		if in_bound or not self.clip.value then
			for i=#self.children,1,-1 do
				local child=self.children[i]
				if
					child
					and child.append_cursor
					and child:append_cursor(x,y,button,id,state)
				then
					break
				end
			end
		end
		
		return debounce
	end
	
	function element:append_pressed(button,id,x,y)
		if button==1 then
			self.selected.value=true
		end
	end
	
	function element:append_released(button,id,x,y)
		if button==1 then
			self.selected.value=false
		end
		if self.targeted.value then
			self.clicked(button,id,x,y)
		end
	end
	
	function element:append_targeted(targeted)
		if not self.gui.value then
			return
		end
		if not targeted then
			self.selected.value=false
			self.gui.value.targeted_elements[self]=nil
		end
	end
	
	function element:append_parent_gui(new_parent,old_parent)
		if new_parent then
			if new_parent:is(gel.class.gui) then
				self.gui.value=new_parent
			elseif new_parent:is(element) then
				self.gui.value=new_parent.gui.value
			else
				self.gui.value=nil
			end
		else
			self.gui.value=nil
		end
	end
	
	function element:append_child_gui(new_gui,old_gui)
		if old_gui then
			old_gui.targeted_elements[self]=nil
		end
		for _,child in pairs(self.children) do
			if child.gui then
				child.gui.value=new_gui
			end
		end
	end
	
	return element
end