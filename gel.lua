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
		_version = {0,5,6},
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
		
		--assert(class,"No class named "..tostring(class_name))
		
		return class()
	end
	
	--Wrapped
	function gel.get_font_height(font)
		return 0
	end
	function gel.get_text_width(text,font,font_size)
		return 0
	end
	function gel.get_text_wrap(text,font,font_size,wrap)
		return 0,0,{}
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
				if old_parent.children_name[name] then
					old_parent.children_name[name][self]=nil
					if not next(old_parent.children_name[name]) then
						old_parent.children_name[name]=nil
					end
				end
				remove(old_parent.children,self.index.value)
				for i=self.index.value,#old_parent.children do
					old_parent.children[i].index.value=i
				end
				old_parent.child_removed(self)
			end
			if new_parent then
				local objects=new_parent.children_name[name] or {}
				objects[self]=self
				new_parent.children_name[name]=objects
				self.index._value=#new_parent.children+1
				new_parent.children[self.index.value]=self
				new_parent.child_added(self)
			end
		end,true)
		
		self.name:attach(function(_,new_name,old_name)
			local parent=self.parent.value
			if not parent then
				return
			end
			if old_name and parent.children_name[old_name] then
				parent.children_name[old_name][self]=nil
				if not next(parent.children_name[old_name]) then
					parent.children_name[old_name]=nil
				end
			end
			if new_name then
				local objects=parent.children_name[new_name] or {}
				objects[self]=self
				parent.children_name[new_name]=objects
			end
		end,true)
		
		self.index:attach(function(_,new_index,old_index)
			if not self.parent.value then
				return
			end
			local children=self.parent.value.children
			if children[new_index]==self then
				return
			end
			for i,child in pairs(children) do
				if child==self then
					remove(children,i);break
				end
			end
			insert(
				children,
				lmath.clamp(new_index or #children+1,1,#children+1),
				self
			)
			for i,child in pairs(children) do
				child.index.value=i
			end
		end,true)
	end

	function gel_object:delete()
		self.parent.value=nil
		
		for i=#self.children,1,-1 do
			self.children[i]:delete()
		end
		
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
			return next(self.children_name[name])
		end
	end
	
	function gel_object:set(property_name,value)
		local property=self[property_name]
		
		--[[
		assert(
			property,
			("Property %s does not exist in %s"):format(property,self)
		)
		assert(
			getmetatable(property)==eztask.property,
			("%s is not a property"):format(property_name)
		)
		]]
		
		property.value=value
		
		return self
	end
	
	------------------------------[gui]------------------------------
	local gui=gel_object:extend()
	
	function gui:__tostring()
		return "gui"
	end
	
	function gui:new()
		gui.super.new(self)
		
		self.targeted_elements = {}
		
		self.resolution      = eztask.property.new(lmath.vector2.new(0,0))
		self.cursor_position = eztask.property.new(lmath.vector2.new(0,0))
		self.focused_text    = eztask.property.new()
		
		self.cursor_pressed  = eztask.signal.new()
		self.cursor_released = eztask.signal.new()
		self.key_pressed     = eztask.signal.new()
		self.key_released    = eztask.signal.new()
		self.text_input      = eztask.signal.new()
		
		self.cursor_position:attach(function(_,position)
			self:append_cursor(position.x,position.y)
		end,true)
		self.cursor_pressed:attach(function(_,button,x,y)
			self.focused_text.value=nil
			self:append_cursor(x,y,button,1,true)
		end,true)
		self.cursor_released:attach(function(_,button,x,y)
			self:append_cursor(x,y,button,1,false)
		end,true)
		
		self.resolution:attach(function()
			for _,child in pairs(self.children) do
				if child.update_geometry then
					child:update_geometry()
				end
			end
		end,true)
		
		self.text_input:attach(function(_,char)
			local text_object=self.focused_text.value
			if text_object and text_object.editable.value then
				local text=text_object.text.value
				text_object.text.value=(
					text:sub(0,text_object.cursor_position.value)..
					char..
					text:sub(text_object.cursor_position.value+1,#text)
				)
				text_object.cursor_position.value=text_object.cursor_position.value+1
			end
		end,true)
		
		self.key_pressed:attach(function(_,key)
			local text_object=self.focused_text.value
			if text_object and text_object.editable.value then
				local text=text_object.text.value
				if key=="left" then
					text_object.cursor_position.value=lmath.clamp(
						text_object.cursor_position.value-1,
						0,
						#text
					)
				elseif key=="right" then
					text_object.cursor_position.value=lmath.clamp(
						text_object.cursor_position.value+1,
						0,
						#text
					)
				elseif key=="backspace" then
					text_object.text.value=(
						text:sub(0,lmath.clamp(text_object.cursor_position.value-1,0,#text))..
						text:sub(text_object.cursor_position.value+1,#text)
					)
					text_object.cursor_position.value=lmath.clamp(
						text_object.cursor_position.value-1,
						0,
						#text
					)
				elseif key=="tab" then
					text_object.text.value=(
						text:sub(0,text_object.cursor_position.value)..
						"\t"..
						text:sub(text_object.cursor_position.value+1,#text)
					)
					text_object.cursor_position.value=text_object.cursor_position.value+1
				elseif key=="return" and text_object.multiline.value then
					text_object.text.value=(
						text:sub(0,text_object.cursor_position.value)..
						"\n"..
						text:sub(text_object.cursor_position.value+1,#text)
					)
					text_object.cursor_position.value=text_object.cursor_position.value+1
				end
			end
		end,true)
	end
	
	function gui:delete()
		gui.super.delete(self)
		
		self.targeted_elements={}
		
		self.resolution:detach()
		self.focused_text:detach()
		self.cursor_position:detach()
		
		self.cursor_pressed:detach()
		self.cursor_released:detach()
		self.key_pressed:detach()
		self.key_released:detach()
		self.text_input:detach()
	end
	
	function gui:draw()
		for _,child in pairs(self.children) do
			if child.render then
				child:render()
			end
		end
	end
	
	function gui:append_cursor(x,y,button,id,state)
		local resolution_x=self.resolution.value.x
		local resolution_y=self.resolution.value.y
		
		local cursor_x=lmath.clamp(x,0,resolution_x-1)
		local cursor_y=lmath.clamp(y,0,resolution_y-1)
		
		for _,element in pairs(self.targeted_elements) do
			local abs_pos=element.absolute_position.value
			local abs_size=element.absolute_size.value
			local in_bound=(
				cursor_x>=abs_pos.x and 
				cursor_y>=abs_pos.x and 
				cursor_x<abs_pos.x+abs_size.x and 
				cursor_y<abs_pos.y+abs_size.y
			)
			if not in_bound then
				element.targeted.value=false
				self.targeted_elements[element]=nil
			end
		end
		
		for i=#self.children,1,-1 do
			local child=self.children[i]
			if child and child:is(gel.class.element) then
				if child:append_cursor(cursor_x,cursor_y,button,id,state) then
					break
				end
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
		self._update_geometry=function()
			if self:update_geometry() then
				self._redraw()
			end
		end
		
		self.visible      = eztask.property.new(true)
		self.position     = eztask.property.new(lmath.udim2.new(0,0,0,0))
		self.size         = eztask.property.new(lmath.udim2.new(0,0,0,0))
		self.rotation     = eztask.property.new(0)
		self.anchor_point = eztask.property.new(lmath.vector2.new(0,0))
		self.clip         = eztask.property.new(false)
		self.active       = eztask.property.new(false)
		
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
		self.targeted          = eztask.property.new(false)
		self.selected          = eztask.property.new(false)
		
		self.clicked  = eztask.signal.new()
		self.pressed  = eztask.signal.new()
		self.released = eztask.signal.new()
		
		--Ugly callbacks
		self.index:attach(self._draw,true)
		self.visible:attach(self._draw,true)
		
		--self.parent:attach(self._update_geometry,true)
		--self.gui:attach(self._update_geometry,true)
		self.clip_parent:attach(self._update_geometry,true)
		self.position:attach(self._update_geometry,true)
		self.rotation:attach(self._update_geometry,true)
		self.anchor_point:attach(self._update_geometry,true)
		self.size:attach(self._update_geometry,true)
		
		self.child_removed:attach(self._redraw,true)
		self.child_added:attach(self._redraw,true)
		
		self.parent:attach(function(_,new_parent,old_parent)
			self._update_geometry()
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
			self._update_geometry()
			if old_gui then
				old_gui.targeted_elements[self]=nil
			end
			for _,child in pairs(self.children) do
				if child.gui then
					child.gui.value=new_gui
				end
			end
		end,true)
		
		self.targeted:attach(function(_,targeted)
			if not self.gui.value then
				return
			end
			if not targeted then
				self.selected.value=false
				self.gui.value.targeted_elements[self]=nil
			end
		end,true)
		
		self.pressed:attach(function(_,button,id,x,y)
			if button==1 then
				self.selected.value=true
			end
		end,true)
		
		self.released:attach(function(_,button,id,x,y)
			if button==1 then
				self.selected.value=false
			end
			if self.targeted.value then
				self.clicked(button,id,x,y)
			end
		end,true)
	end
	
	function element:delete()
		element.super.delete(self)
		
		self.visible:detach()
		self.position:detach()
		self.size:detach()
		self.rotation:detach()
		self.anchor_point:detach()
		self.clip:detach()
		self.active:detach()
		
		self.gui:detach()
		self.clip_parent:detach()
		self.absolute_size:detach()
		self.absolute_position:detach()
		self.absolute_anchor:detach()
		self.absolute_rotation:detach()
		self.relative_position:detach()
		self.relative_rotation:detach()
		self.rendering:detach()
		self.targeted:detach()
		self.selected:detach()
		
		self.clicked:detach()
		self.pressed:detach()
		self.released:detach()
	end
	
	function element:update_geometry() --Probably should've used matrices...
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
		
		local geometry_changed=false
		
		if self.absolute_size.value.x~=abs_size_x or self.absolute_size.value.y~=abs_size_y then
			self.absolute_size.value.x=abs_size_x
			self.absolute_size.value.y=abs_size_y
			self.absolute_size(self.absolute_size.value)
			geometry_changed=true
		end
		if self.absolute_position.value.x~=abs_pos_x or self.absolute_position.value.y~=abs_pos_y then
			self.absolute_position.value.x=abs_pos_x
			self.absolute_position.value.y=abs_pos_y
			self.absolute_position(self.absolute_position.value)
			geometry_changed=true
		end
		if self.absolute_anchor.value.x~=abs_anchor_x or self.absolute_anchor.value.y~=abs_anchor_y then
			self.absolute_anchor.value.x=abs_anchor_x
			self.absolute_anchor.value.y=abs_anchor_y
			self.absolute_anchor(self.absolute_anchor.value)
			geometry_changed=true
		end
		if self.relative_position.value.x~=rel_pos_x or self.relative_position.value.y~=rel_pos_y then
			self.relative_position.value.x=rel_pos_x
			self.relative_position.value.y=rel_pos_y
			self.relative_position(self.relative_position.value)
			geometry_changed=true
		end
		if self.absolute_rotation.value~=abs_rot then
			self.absolute_rotation.value=abs_rot
			geometry_changed=true
		end
		if self.relative_rotation.value~=rel_rot then
			self.relative_rotation.value=rel_rot
			geometry_changed=true
		end
		
		if geometry_changed then
			for _,child in pairs(self.children) do
				if child.update_geometry then
					child:update_geometry()
				end
			end
		end
		
		return geometry_changed
	end
	
	function element:draw() end
	function element:draw_render() end
	function element:draw_buffer() end
	
	function element:render()
		if not self.visible.value then
			return
		end
		
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
	
	function element:append_cursor(x,y,button,id,state) --Mouse ID=1, Touch ID=2,3,4...
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
		
		local debounce=false
		
		self.targeted.value=in_bound
		
		if in_bound and self.gui.value then
			self.gui.value.targeted_elements[self]=self
			if button then
				if state then
					self.pressed(button,id,x,y)
				else
					self.released(button,id,x,y)
				end
				debounce=self.active.value
			end
		end
		
		if in_bound or not self.clip.value then
			for i=#self.children,1,-1 do
				local child=self.children[i]
				if child and child:is(element) then
					if child:append_cursor(x,y,button,id,state) then
						break
					end
				end
			end
		end
		
		return debounce
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
	
	------------------------------[image_element]------------------------------
	local image_element=frame:extend()
	
	function image_element:__tostring()
		return "image_element"
	end
	
	function image_element:new()
		image_element.super.new(self)
		
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
	
	function image_element:delete()
		image_element.super.delete(self)
		
		self.image:detach()
		self.image_opacity:detach()
		self.image_color:detach()
		self.scale_mode:detach()
		self.filter_mode:detach()
		self.slice_center:detach()
		self.tile_size:detach()
		self.rect_offset:detach()
	end
	
	------------------------------[text_element]------------------------------
	local text_element=frame:extend()
	
	function text_element:__tostring()
		return "text_element"
	end
	
	function text_element:new()
		text_element.super.new(self)
		
		self.font              = eztask.property.new()
		self.text              = eztask.property.new("")
		self.text_color        = eztask.property.new(lmath.color3.new(1,1,1))
		self.text_opacity      = eztask.property.new(0)
		self.text_size         = eztask.property.new(12)
		self.text_scaled       = eztask.property.new(false)
		self.text_wrapped      = eztask.property.new(false)
		self.multiline         = eztask.property.new(false)
		self.text_x_alignment  = eztask.property.new(gel.enum.alignment.x.center)
		self.text_y_alignment  = eztask.property.new(gel.enum.alignment.y.center)
		self.filter_mode       = eztask.property.new(gel.enum.filter_mode.nearest)
		self.focused           = eztask.property.new(false)
		self.selectable        = eztask.property.new(false)
		self.editable          = eztask.property.new(false)
		self.cursor_position   = eztask.property.new(0)
		self.highlight_opacity = eztask.property.new(0.5)
		self.highlight_color   = eztask.property.new(lmath.color3.new(0,0.2,1))
		self.highlight_start   = eztask.property.new(0)
		self.highlight_end     = eztask.property.new(0)
		
		self.font:attach(self._draw,true)
		self.text:attach(self._draw,true)
		self.text_color:attach(self._draw,true)
		self.text_opacity:attach(self._draw,true)
		self.text_size:attach(self._draw,true)
		self.text_scaled:attach(self._draw,true)
		self.text_wrapped:attach(self._draw,true)
		self.multiline:attach(self._draw,true)
		self.text_x_alignment:attach(self._draw,true)
		self.text_y_alignment:attach(self._draw,true)
		self.filter_mode:attach(self._draw,true)
		self.focused:attach(self._draw,true)
		self.cursor_position:attach(self._draw,true)
		self.highlight_opacity:attach(self._draw,true)
		self.highlight_color:attach(self._draw,true)
		self.highlight_start:attach(self._draw,true)
		self.highlight_end:attach(self._draw,true)
		
		self.gui:attach(function(_,new_gui,old_gui)
			if self.focused_text_event then
				self.focused_text_event:detach()
				self.focused_text_event=nil
			end
			if old_gui and old_gui.focused_text.value==self then
				old_gui.focused_text.value=nil
			end
			if new_gui then
				self.focused_text_event=new_gui.focused_text:attach(function(_,element)
					self.focused.value=(element==self)
				end,true)
			end
		end,true)
		
		self.focused:attach(function(_,focused)
			if self.gui.value then
				if focused then
					self.gui.value.focused_text.value=self
				elseif self.gui.value.focused_text.value==self then
					self.gui.value.focused_text.value=nil
				end
			end
		end,true)
		
		self.selected:attach(function(_,selected)
			if selected and self.selectable.value then
				self.focused.value=true
			end
		end,true)
	end
	
	function text_element:delete()
		text_element.super.delete(self)
		
		self.font:detach()
		self.text:detach()
		self.text_color:detach()
		self.text_opacity:detach()
		self.text_size:detach()
		self.text_scaled:detach()
		self.text_wrapped:detach()
		self.multiline:detach()
		self.text_x_alignment:detach()
		self.text_y_alignment:detach()
		self.filter_mode:detach()
		self.focused:detach()
		self.selectable:detach()
		self.editable:detach()
		self.cursor_position:detach()
		self.highlight_opacity:detach()
		self.highlight_color:detach()
		self.highlight_start:detach()
		self.highlight_end:detach()
		
		if self.focused_text_event then
			self.focused_text_event:detach()
			self.focused_text_event=nil
		end
		
		if self.gui.value and self.gui.value.focused_text.value==self then
			self.gui.value.focused_text.value=nil
		end
	end
	
	----------------------------------------------------------------------
	gel.class.gel_object    = gel_object
	gel.class.gui           = gui
	gel.class.element       = element
	gel.class.frame         = frame
	gel.class.image_element = image_element
	gel.class.text_element  = text_element
	
	return gel
end