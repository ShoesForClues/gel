--[[
MIT License

Copyright (c) 2020 ShoesForClues

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

return function(lumiere)
	local eztask = lumiere:depend "eztask"
	local class  = lumiere:depend "class"
	local lmath  = lumiere:depend "lmath"

	local min    = math.min
	local max    = math.max
	local sin    = math.sin
	local cos    = math.cos
	local floor  = math.floor
	local ceil   = math.ceil
	local remove = table.remove
	local insert = table.insert
	
	local gel={
		_version = {0,5,4},
		enum     = {},
		class    = {}
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
	
	--Functions
	function gel.wrap(class_name,method,wrap)
		local class=gel.class[class_name]
		assert(class,"No class named "..tostring(class_name))
		assert(class[method],("No method named %s in class %s"):format(method,class))
		assert(wrap,"Cannot wrap method with nil")
		local _method=class[method]
		class[method]=function(...) _method(...);wrap(...) end
		return class
	end
	
	function gel.new(class_name)
		local class=gel.class[class_name]
		assert(class,"No class named "..tostring(class_name))
		return class()
	end
	
	------------------------------[gel_object]------------------------------
	local gel_object=class:extend()
	
	function gel_object:__tostring()
		return "gel_object"
	end

	function gel_object:new()
		self.children      = {}
		self.children_name = {}
		
		self.parent = eztask.property.new()
		self.name   = eztask.property.new(tostring(self))
		self.index  = eztask.property.new()
		
		self.child_added   = eztask.signal.new()
		self.child_removed = eztask.signal.new()
		
		self.parent:attach(function(_,new_parent,old_parent)
			local name=self.name.value
			if name==nil then
				return
			end
			if old_parent then
				local children=old_parent.children
				for i=1,#children do
					if children[i]==self then
						remove(children,i)
						break
					end
				end
				if old_parent.children_name[name] then
					local objects=old_parent.children_name[name]
					for i=1,#objects do
						if objects[i]==self then
							remove(objects,i)
							break
						end
					end
					if #objects==0 then
						old_parent.children_name[name]=nil
					end
				end
				old_parent.child_removed:invoke(self)
			end
			if new_parent then
				local objects=new_parent.children_name[name] or {}
				objects[#objects+1]=self
				new_parent.children_name[name]=objects
				self.index._value=#new_parent.children+1
				new_parent.children[self.index.value]=self
				new_parent.child_added:invoke(self)
			end
		end,true)
		
		self.name:attach(function(_,new_name,old_name)
			local parent=self.parent.value
			if not parent then
				return
			end
			if old_name and parent.children_name[old_name] then
				local objects=parent.children_name[old_name]
				for i=1,#objects do
					if objects[i]==self then
						remove(objects,i)
						break
					end
				end
				if #objects==0 then
					parent.children_name[old_name]=nil
				end
			end
			if new_name then
				local objects=parent.children_name[new_name] or {}
				objects[#objects+1]=self
				parent.children_name[new_name]=objects
			end
		end,true)
		
		self.index:attach(function(_,new_index,old_index)
			if not self.parent.value then
				return
			end
			for i,child in pairs(self.children) do
				if child==self then
					remove(self.children,i)
					break
				end
			end
			insert(self.children,lmath.clamp(new_index or #self.children+1,1,#self.children+1))
		end,true)
	end

	function gel_object:delete()
		for _,child in pairs(self.children) do
			child:delete()
		end
		
		self.parent.value=nil
		
		self.parent:detach()
		self.name:detach()
		self.index:detach()
		
		self.child_added:detach()
		self.child_removed:detach()
	end

	function gel_object:get_children(name)
		if name then
			return self.children_name[name]
		else
			return self.children
		end
	end

	function gel_object:get_child(name)
		if self.children_name[name] then
			return self.children_name[name][1]
		end
	end
	
	------------------------------[gui]------------------------------
	local gui=gel_object:extend()
	
	function gui:__tostring()
		return "gui"
	end
	
	function gui:new()
		gui.super.new(self)
		
		self.focused_elements = {}
		
		self.resolution      = eztask.property.new(lmath.vector2.new(0,0))
		self.cursor_position = eztask.property.new(lmath.vector2.new(0,0))
		
		self.cursor_pressed  = eztask.signal.new()
		self.cursor_released = eztask.signal.new()
		
		self.cursor_position:attach(function(_,position)
			local resolution_x=self.resolution.value.x
			local resolution_y=self.resolution.value.y
			
			local cursor_x=lmath.clamp(position.x,0,resolution_x-1)
			local cursor_y=lmath.clamp(position.y,0,resolution_y-1)
			
			for _,element in pairs(self.focused_elements) do
				local abs_pos=element.absolute_position.value
				local abs_size=element.absolute_size.value
				local in_bound=(
					cursor_x>=abs_pos.x and 
					cursor_y>=abs_pos.x and 
					cursor_x<abs_pos.x+abs_size.x and 
					cursor_y<abs_pos.y+abs_size.y
				)
				if not in_bound then
					element.focused.value=false
					self.focused_elements[element]=nil
				end
			end
			
			for _,child in pairs(self.children) do
				if child:is(gel.class.element) then
					child:append_cursor(cursor_x,cursor_y)
				end
			end
		end,true)
		
		self.cursor_pressed:attach(function(_,button,x,y)
			for _,element in pairs(self.focused_elements) do
				element.cursor_pressed:invoke(button,x,y)
			end
		end,true)
		
		self.cursor_released:attach(function(_,button,x,y)
			for _,element in pairs(self.focused_elements) do
				element.cursor_released:invoke(button,x,y)
			end
		end,true)
	end
	
	function gui:delete()
		gui.super.delete(self)
		
		self.resolution:detach()
		self.cursor_position:detach()
		
		self.cursor_pressed:detach()
		self.cursor_released:detach()
	end
	
	function gui:draw()
		for _,child in pairs(self.children) do
			if child.render then
				child:render()
			end
		end
	end
	
	------------------------------[element]------------------------------
	local element=gel_object:extend()
	
	function element:__tostring()
		return "gui_object"
	end
	
	function element:new()
		element.super.new(self)
		
		self.redraw=true
		
		self._draw=function()
			if self.parent.value~=nil and self.parent.value._redraw then
				self.parent.value._redraw()
			end
		end
		self._redraw=function()
			if self.redraw then
				return
			end
			self.redraw=true
			self._draw()
		end
		
		self.visible      = eztask.property.new(false)
		self.position     = eztask.property.new(lmath.udim2.new(0,0,0,0))
		self.size         = eztask.property.new(lmath.udim2.new(0,0,0,0))
		self.rotation     = eztask.property.new(0)
		self.anchor_point = eztask.property.new(lmath.vector2.new(0,0))
		self.clip         = eztask.property.new(false)
		
		--Read only
		self.gui               = eztask.property.new()
		self.clip_parent       = eztask.property.new()
		self.absolute_size     = eztask.property.new(lmath.vector2.new(0,0))
		self.absolute_position = eztask.property.new(lmath.vector2.new(0,0))
		self.absolute_anchor   = eztask.property.new(lmath.vector2.new(0,0))
		self.absolute_rotation = eztask.property.new(self.rotation.value)
		self.relative_position = eztask.property.new(lmath.vector2.new(0,0))
		self.relative_rotation = eztask.property.new(self.rotation.value)
		self.rendering         = eztask.property.new()
		self.focused           = eztask.property.new(false)
		self.selected          = eztask.property.new(false)
		
		self.cursor_clicked  = eztask.signal.new()
		self.cursor_pressed  = eztask.signal.new()
		self.cursor_released = eztask.signal.new()
		
		--Ugly callbacks
		self.parent:attach(self._redraw,true)
		self.visible:attach(self._draw,true)
		self.position:attach(self._draw,true)
		self.rotation:attach(self._draw,true)
		self.anchor_point:attach(self._draw,true)
		self.size:attach(self._redraw,true)
		self.absolute_size:attach(self._redraw,true)
		self.absolute_position:attach(self._draw,true)
		self.absolute_anchor:attach(self._draw,true)
		self.absolute_rotation:attach(self._draw,true)
		self.relative_rotation:attach(self._draw,true)
		self.relative_position:attach(self._draw,true)
		
		self.child_removed:attach(self._redraw,true)
		self.child_added:attach(self._redraw,true)
		
		self.parent:attach(function(_,new_parent,old_parent)
			if new_parent then
				if new_parent:is(gui) then
					self.gui.value=new_parent
				elseif new_parent:is(element) then
					self.gui.value=new_parent.gui.value
				else
					self.gui.value=nil
				end
			else
				self.gui.value=nil
			end
		end,true)
		
		self.gui:attach(function(_,new_gui,old_gui)
			if old_gui then
				old_gui.focused_elements[self]=nil
			end
			for _,child in pairs(self.children) do
				if child.gui then
					child.gui.value=new_gui
				end
			end
		end,true)
		
		self.focused:attach(function(_,focused)
			if not self.gui.value then
				return
			end
			if not focused then
				self.selected.value=false
				self.gui.value.focused_elements[self]=nil
			end
		end,true)
		
		self.cursor_pressed:attach(function(_,button,x,y)
			if button==1 then
				self.selected.value=true
			end
		end,true)
		
		self.cursor_released:attach(function(_,button,x,y)
			if button==1 then
				self.selected.value=false
			end
			if self.focused.value then
				self.cursor_clicked:invoke(button,x,y)
			end
		end,true)
	end
	
	function element:delete()
		element.super.delete(self)
		
		self.visible:detach()
		self.position:detach()
		self.size:detach()
		size.rotation:detach()
		self.anchor_point:detach()
		self.clip:detach()
		
		self.gui:detach()
		self.clip_parent:detach()
		self.absolute_size:detach()
		self.absolute_position:detach()
		self.absolute_anchor:detach()
		self.absolute_rotation:detach()
		self.relative_position:detach()
		self.relative_rotation:detach()
		self.rendering:detach()
		self.focused:detach()
		self.selected:detach()
		
		self.cursor_clicked:detach()
		self.cursor_pressed:detach()
		self.cursor_released:detach()
	end
	
	function element:update_geometry() --This was a huge pain
		local parent   = self.parent.value
		local position = self.position.value
		local size     = self.size.value
		
		local abs_size_x   = self.absolute_size.value.x
		local abs_size_y   = self.absolute_size.value.y
		local abs_pos_x    = self.absolute_position.value.x
		local abs_pos_y    = self.absolute_position.value.y
		local abs_anchor_x = self.absolute_anchor.value.x
		local abs_anchor_y = self.absolute_anchor.value.y
		local abs_rot      = self.absolute_rotation.value
		local rel_pos_x    = self.relative_position.value.x
		local rel_pos_y    = self.relative_position.value.y
		local rel_rot      = self.relative_rotation.value
		
		if parent and parent:is(element) then
			local clip_parent=self.clip_parent.value or parent
			
			local parent_abs_size = parent.absolute_size.value
			local parent_abs_pos  = parent.absolute_position.value
			
			abs_size_x=floor(parent_abs_size.x*size.x.scale+size.x.offset)
			abs_size_y=floor(parent_abs_size.y*size.y.scale+size.y.offset)
			
			abs_rot=parent.absolute_rotation.value+self.rotation.value
			
			local anchor_size_x=abs_size_x*self.anchor_point.value.x
			local anchor_size_y=abs_size_y*self.anchor_point.value.y
			
			local anchor_offset_x,anchor_offset_y=lmath.rotate_point(
				parent_abs_size.x*position.x.scale+position.x.offset,
				parent_abs_size.y*position.y.scale+position.y.offset,
				0,
				0,
				parent.absolute_rotation.value
			)
			
			local abs_offset_x,abs_offset_y=lmath.rotate_point(
				parent_abs_size.x*position.x.scale+position.x.offset-anchor_size_x,
				parent_abs_size.y*position.y.scale+position.y.offset-anchor_size_y,
				0,
				0,
				parent.absolute_rotation.value
			)
			
			abs_anchor_x=parent_abs_pos.x+anchor_offset_x
			abs_anchor_y=parent_abs_pos.y+anchor_offset_y
			
			abs_pos_x,abs_pos_y=lmath.rotate_point(
				parent_abs_pos.x+abs_offset_x,
				parent_abs_pos.y+abs_offset_y,
				abs_anchor_x,
				abs_anchor_y,
				self.rotation.value
			)
			
			local n_clip_parent_abs_pos_x,n_clip_parent_abs_pos_y=lmath.rotate_point(
				clip_parent.absolute_position.value.x,
				clip_parent.absolute_position.value.y,
				clip_parent.absolute_anchor.value.x,
				clip_parent.absolute_anchor.value.y,
				-clip_parent.absolute_rotation.value
			)
			
			local n_abs_pos_x,n_abs_pos_y=lmath.rotate_point(
				abs_pos_x,
				abs_pos_y,
				clip_parent.absolute_anchor.value.x,
				clip_parent.absolute_anchor.value.y,
				-clip_parent.absolute_rotation.value
			)
			
			rel_pos_x=floor(n_abs_pos_x-n_clip_parent_abs_pos_x)
			rel_pos_y=floor(n_abs_pos_y-n_clip_parent_abs_pos_y)
			
			rel_rot=abs_rot-clip_parent.absolute_rotation.value
		else
			if self.gui.value then
				abs_size_x=floor(self.gui.value.resolution.value.x*size.x.scale+size.x.offset)
				abs_size_y=floor(self.gui.value.resolution.value.y*size.y.scale+size.y.offset)
				abs_anchor_x=floor(self.gui.value.resolution.value.x*position.x.scale+position.x.offset)
				abs_anchor_y=floor(self.gui.value.resolution.value.y*position.y.scale+position.y.offset)
			else
				abs_size_x=size.x.offset
				abs_size_y=size.y.offset
				abs_anchor_x=position.x.offset
				abs_anchor_y=position.y.offset
			end
			
			local anchor_size_x=abs_size_x*self.anchor_point.value.x
			local anchor_size_y=abs_size_y*self.anchor_point.value.y
			
			abs_pos_x,abs_pos_y=lmath.rotate_point(
				abs_anchor_x-anchor_size_x,
				abs_anchor_y-anchor_size_y,
				abs_anchor_x,
				abs_anchor_y,
				self.rotation.value
			)
			
			abs_rot=self.rotation.value
			
			rel_pos_x=abs_pos_x
			rel_pos_y=abs_pos_y
			
			rel_rot=self.rotation.value
		end
		
		if self.absolute_size.value.x~=abs_size_x or self.absolute_size.value.y~=abs_size_y then
			self.absolute_size.value.x=abs_size_x
			self.absolute_size.value.y=abs_size_y
			self.absolute_size:invoke(self.absolute_size.value)
		end
		if self.absolute_position.value.x~=abs_pos_x or self.absolute_position.value.y~=abs_pos_y then
			self.absolute_position.value.x=abs_pos_x
			self.absolute_position.value.y=abs_pos_y
			self.absolute_position:invoke(self.absolute_position.value)
		end
		if self.absolute_anchor.value.x~=abs_anchor_x or self.absolute_anchor.value.y~=abs_anchor_y then
			self.absolute_anchor.value.x=abs_anchor_x
			self.absolute_anchor.value.y=abs_anchor_y
			self.absolute_anchor:invoke(self.absolute_anchor.value)
		end
		if self.relative_position.value.x~=rel_pos_x or self.relative_position.value.y~=rel_pos_y then
			self.relative_position.value.x=rel_pos_x
			self.relative_position.value.y=rel_pos_y
			self.relative_position:invoke(self.relative_position.value)
		end
		if self.absolute_rotation.value~=abs_rot then
			self.absolute_rotation.value=abs_rot
		end
		if self.relative_rotation.value~=rel_rot then
			self.relative_rotation.value=rel_rot
		end
	end
	
	function element:draw() end
	function element:draw_render() end
	function element:draw_buffer() end
	
	function element:render()
		if not self.visible.value then
			return
		end
		
		self:update_geometry()
		self:draw()
		
		if self.redraw or not self.clip.value then
			if self.clip.value then
				for _,child in pairs(self.children) do
					if child:is(element) then
						child.clip_parent.value=self
						child:render()
					end
				end
			else
				for _,child in pairs(self.children) do
					if child:is(element) then
						child.clip_parent.value=self.clip_parent.value
						child:render()
					end
				end
			end
			self.redraw=false
		end
		
		self:draw_buffer()
		self.rendering.value=nil
	end
	
	function element:append_cursor(x,y)
		local abs_pos_x=self.absolute_position.value.x
		local abs_pos_y=self.absolute_position.value.y
		local abs_size_x=self.absolute_size.value.x
		local abs_size_y=self.absolute_size.value.y
		
		local rel_x,rel_y=lmath.rotate_point(
			x,y,
			abs_pos_x,
			abs_pos_y,
			-self.absolute_rotation.value
		)
		
		local in_bound=(
			rel_x>=abs_pos_x and 
			rel_y>=abs_pos_y and 
			rel_x<abs_pos_x+abs_size_x and 
			rel_y<abs_pos_y+abs_size_y
		)
		
		self.focused.value=in_bound
		
		if in_bound or not self.clip.value then
			if in_bound and self.gui.value then
				self.gui.value.focused_elements[self]=self
			end
			for _,child in pairs(self.children) do
				if child:is(element) then
					child:append_cursor(x,y)
				end
			end
		end
	end
	
	------------------------------[frame]------------------------------
	local frame=element:extend()
	
	function frame:__tostring()
		return "frame"
	end
	
	function frame:new()
		frame.super.new(self)
		
		self.background_color   = eztask.property.new(lmath.color3.new(1,1,1))
		self.background_opacity = eztask.property.new(1)
		
		self.background_color:attach(self._draw,true)
		self.background_opacity:attach(self._draw,true)
	end
	
	function frame:delete()
		frame.super.delete(self)
		
		self.background_color:detach()
		self.background_opacity:detach()
	end
	
	------------------------------[text_label]------------------------------
	local text_label=frame:extend()
	
	function text_label:__tostring()
		return "text_label"
	end
	
	function text_label:new()
		text_label.super.new(self)
		
		self.font             = eztask.property.new()
		self.text             = eztask.property.new("")
		self.text_color       = eztask.property.new(lmath.color3.new(1,1,1))
		self.text_opacity     = eztask.property.new(0)
		self.text_size        = eztask.property.new(12)
		self.text_scaled      = eztask.property.new(false)
		self.text_wrapped     = eztask.property.new(false)
		self.text_x_alignment = eztask.property.new(gel.enum.alignment.x.center)
		self.text_y_alignment = eztask.property.new(gel.enum.alignment.y.center)
		self.filter_mode      = eztask.property.new(gel.enum.filter_mode.nearest)
		self.selectable       = eztask.property.new(false)
		
		--Read only
		self.cursor_position = eztask.property.new()
		self.highlighted     = eztask.property.new()
		
		self.font:attach(self._draw,true)
		self.text:attach(self._draw,true)
		self.text_color:attach(self._draw,true)
		self.text_opacity:attach(self._draw,true)
		self.text_size:attach(self._draw,true)
		self.text_scaled:attach(self._draw,true)
		self.text_wrapped:attach(self._draw,true)
		self.text_x_alignment:attach(self._draw,true)
		self.text_y_alignment:attach(self._draw,true)
		self.filter_mode:attach(self._draw,true)
		self.selectable:attach(self._draw,true)
		self.cursor_position:attach(self._draw,true)
		self.highlighted:attach(self._draw,true)
	end
	
	function text_label:delete()
		text_label.super.delete(self)
		
		self.font:detach()
		self.text:detach()
		self.text_color:detach()
		self.text_opacity:detach()
		self.text_size:detach()
		self.text_scaled:detach()
		self.text_wrapped:detach()
		self.text_x_alignment:detach()
		self.text_y_alignment:detach()
		self.filter_mode:detach()
		self.selectable:detach()
		self.cursor_position:detach()
		self.highlighted:detach()
	end
	
	------------------------------[image_label]------------------------------
	local image_label=frame:extend()
	
	function image_label:__tostring()
		return "image_label"
	end
	
	function image_label:new()
		image_label.super.new(self)
		
		self.image         = eztask.property.new()
		self.image_opacity = eztask.property.new(1)
		self.image_color   = eztask.property.new(lmath.color3.new(1,1,1))
		self.scale_mode    = eztask.property.new(gel.enum.scale_mode.stretch)
		self.filter_mode   = eztask.property.new(gel.enum.filter_mode.nearest)
		self.slice_center  = eztask.property.new(lmath.rect.new(0,0,0,0))
		self.tile_size     = eztask.property.new(lmath.udim2.new(1,0,1,0))
		self.rect_offset   = eztask.property.new(lmath.rect.new(0,0,1,1))
		
		self.image:attach(self._draw,true)
		self.image_opacity:attach(self._draw,true)
		self.image_color:attach(self._draw,true)
		self.scale_mode:attach(self._draw,true)
		self.filter_mode:attach(self._draw,true)
		self.slice_center:attach(self._draw,true)
		self.tile_size:attach(self._draw,true)
		self.rect_offset:attach(self._draw,true)
	end
	
	function image_label:delete()
		image_label.super.delete(self)
		
		self.image:detach()
		self.image_opacity:detach()
		self.image_color:detach()
		self.scale_mode:detach()
		self.filter_mode:detach()
		self.slice_center:detach()
		self.tile_size:detach()
		self.rect_offset:detach()
	end
	
	----------------------------------------------------------------------
	gel.class.gel_object  = gel_object
	gel.class.interactor  = interactor
	gel.class.element     = element
	gel.class.gui         = gui
	gel.class.frame       = frame
	gel.class.image_label = image_label
	gel.class.text_label  = text_label
	
	return gel
end