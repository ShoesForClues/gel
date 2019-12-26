--[[
Graphic Elements Library

MIT License

Copyright (c) 2019 Jason Lee

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

return function(thread)
	local eztask = thread:depend "eztask"
	local class  = thread:depend "class"
	local lmath  = thread:depend "lmath"

	local min    = math.min
	local max    = math.max
	local remove = table.remove
	local insert = table.insert
	
	local gel={
		_version = {0,4,2}; --The answer is 42.
		enum     = {};
		elements = {};
	}

	--Enums
	gel.enum.clip_mode={
		none    = "none",
		scissor = "scissor",
		buffer  = "buffer", --Recommended for static elements
		default = "none"
	}
	gel.enum.scale_type={
		stretch = "stretch",
		slice   = "slice",
		default = "stretch"
	}
	gel.enum.blend_type={
		nearest = "nearest",
		linear  = "linear",
		default = "linear"
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
	
	--Wrapped
	gel.get_resolution = function() return lmath.vector2.new(0,0) end
	
	function gel.wrap_element(element,wrap)
		local _new=element.new
		element.new=function(...) _new(...);wrap(...) end
		return element
	end
	
	------------------------------[GEL Object]------------------------------
	local gel_object=class:extend()
	
	function gel_object:__tostring() return "gel_object" end
	
	function gel_object:__call(properties,children,...)
		local new_object=setmetatable({},self)
		new_object:new(properties,children,...)
		if children~=nil then
			for i,child in pairs(children) do
				child.name.value=i
				child.parent.value=new_object
			end
		end
		if properties~=nil then
			new_object.parent.value=properties.parent
		end
		return new_object
	end
	
	function gel_object:new(properties,children)
		self.children        = {}
		self.children_sorted = {}
		
		self.name   = eztask.new_property(properties.name or tostring(self))
		self.index  = eztask.new_property()
		self.parent = eztask.new_property()
		
		self.child_added   = eztask.new_signal()
		self.child_removed = eztask.new_signal()

		self.name:attach(function(new_name,old_name)
			print(new_name)
			if self.parent.value~=nil then
				self.parent.value.children[old_name]=nil
				self.parent.value.children[new_name]=self
			end
		end,true)
		
		self.parent:attach(function(new_parent,old_parent)
			if old_parent~=nil then
				old_parent.children[self.name.value]=nil
				if self.index.value~=nil then
					if old_parent.children_sorted[self.index.value]==self then
						remove(old_parent.children_sorted,self.index.value)
					else
						for i=1,#old_parent.children_sorted do
							if old_parent.children_sorted[i]==self then
								remove(old_parent.children_sorted,i);break
							end
						end
					end
				end
				old_parent.child_removed:invoke(self)
			end
			if new_parent~=nil then
				new_parent.children[self.name.value]=self
				rawset(self.index,"_value",nil)
				self.index.value=#new_parent.children_sorted+1
				new_parent.child_added:invoke(self)
			end
		end,true)
		
		self.index:attach(function(new_index,old_index)
			if self.parent.value~=nil then
				local _children_sorted=self.parent.value.children_sorted
				if old_index~=nil then
					if _children_sorted[old_index]==self then
						remove(_children_sorted,old_index)
					else
						for i=1,#_children_sorted do
							if _children_sorted[i]==self then
								remove(_children_sorted,i);break
							end
						end
					end
				end
				if new_index~=nil then
					insert(_children_sorted,new_index,self)
				end
			end
		end,true)
		
		thread.killed:attach(function()
			self:delete()
		end)
	end
	
	function gel_object:delete()
		self.parent.value=nil
		for _,child in pairs(self.children) do
			child:delete()
		end
	end

	------------------------------[GUI Object]------------------------------
	local gui_object=gel_object:extend()
	
	function gui_object:new(properties,children)
		gui_object.super.new(self,properties,children)
		
		self.redraw=true
		
		self._draw=function()
			if self.parent.value~=nil and self.parent.value._redraw then
				self.parent.value._redraw()
			end
		end
		self._redraw=function()
			self.redraw=true
			self._draw()
		end
		
		self.visible      = eztask.new_property(properties.visible or false)
		self.position     = eztask.new_property(properties.position or lmath.udim2.new(0,0,0,0))
		self.size         = eztask.new_property(properties.size or lmath.udim2.new(0,0,0,0))
		self.rotation     = eztask.new_property(properties.rotation or 0)
		self.anchor_point = eztask.new_property(properties.anchor_point or lmath.vector2.new(0,0))
		self.clip_mode    = eztask.new_property(properties.clip_mode or gel.enum.clip_mode.default)
		
		--Read only
		self.absolute_position = eztask.new_property(lmath.vector2.new(0,0))
		self.absolute_size     = eztask.new_property(lmath.vector2.new(0,0))
		self.absolute_clip     = eztask.new_property(lmath.rect.new(0,0,0,0))
		
		self.drawing           = eztask.new_signal()
		self.drawn             = eztask.new_signal()
		
		--Ugly callbacks
		self.parent:attach(self._redraw,true)
		self.visible:attach(self._draw,true)
		self.position:attach(self._draw,true)
		self.rotation:attach(self._draw,true)
		self.anchor_point:attach(self._draw,true)
		self.size:attach(self._redraw,true)
		self.clip_mode:attach(self._redraw,true)
		self.child_removed:attach(self._redraw,true)
		self.child_added:attach(self._redraw,true)
	end
	
	function gui_object:update_absolute()
		local parent_size,parent_position
		
		if self.parent.value~=nil then
			parent_size=self.parent.value.absolute_size.value
			parent_position=self.parent.value.absolute_position.value
		else
			parent_size=lmath.vector2.new(self.size.value.x.offset,self.size.value.y.offset)
			parent_position=lmath.vector2.new(0,0)
		end
		
		self.absolute_size.value=lmath.vector2.new(
			self.size.value.x.offset+parent_size.x*self.size.value.x.scale,
			self.size.value.y.offset+parent_size.y*self.size.value.y.scale
		)
		self.absolute_position.value=parent_position+lmath.vector2.new(
			self.position.value.x.offset+parent_size.x*self.position.value.x.scale-self.absolute_size.value.x*self.anchor_point.value.x,
			self.position.value.y.offset+parent_size.y*self.position.value.y.scale-self.absolute_size.value.y*self.anchor_point.value.y
		)
		
		if self.parent.value==nil then
			if self.clip_mode.value~=gel.enum.clip_mode.none then
				self.absolute_clip.value=lmath.rect.new(
					self.absolute_position.value.x,
					self.absolute_position.value.y,
					self.absolute_position.value.x+self.absolute_size.value.x,
					self.absolute_position.value.y+self.absolute_size.value.y
				)
			else
				self.absolute_clip.value=lmath.rect.new(0,0,parent_size.x,parent_size.y)
			end
		else
			if self.clip_mode.value~=gel.enum.clip_mode.none then
				self.absolute_clip.value=lmath.rect.new(
					lmath.clamp(
						self.absolute_position.value.x,
						self.parent.value.absolute_clip.value.min_x,
						self.parent.value.absolute_clip.value.max_x
					),
					lmath.clamp(
						self.absolute_position.value.y,
						self.parent.value.absolute_clip.value.min_y,
						self.parent.value.absolute_clip.value.max_y
					),
					lmath.clamp(
						self.absolute_position.value.x+self.absolute_size.value.x,
						self.parent.value.absolute_clip.value.min_x,
						self.parent.value.absolute_clip.value.max_x
					),
					lmath.clamp(
						self.absolute_position.value.y+self.absolute_size.value.y,
						self.parent.value.absolute_clip.value.min_y,
						self.parent.value.absolute_clip.value.max_y
					)
				)
			else
				self.absolute_clip.value=self.parent.value.absolute_clip.value
			end
		end
	end
	
	function gui_object:draw(top_parent,clip_parent)
		if not self.visible.value then
			return
		end
		local old_absolute_size=self.absolute_size.value
		self:update_absolute()
		top_parent=top_parent or self
		self.drawing:invoke(top_parent,clip_parent)
		if self.clip_mode.value==gel.enum.clip_mode.buffer then
			if self.redraw or self.absolute_size.value~=old_absolute_size then
				for _,child in pairs(self.children_sorted) do
					if child.draw then
						child:draw(top_parent,self)
					end
				end
			end
		else
			for _,child in pairs(self.children_sorted) do
				if child.draw then
					child:draw(top_parent,clip_parent)
				end
			end
		end
		self.drawn:invoke(top_parent,clip_parent)
		self.redraw=false
	end
	
	------------------------------[Frame]------------------------------
	local frame=gui_object:extend()
	
	function frame:new(properties,children)
		frame.super.new(self,properties,children)
		
		self.background_transparency = eztask.new_property(properties.background_transparency or 0)
		self.background_color        = eztask.new_property(properties.background_color or lmath.color3.new(1,1,1))
		
		self.background_transparency:attach(self._draw,true)
		self.background_color:attach(self._draw,true)
	end
	
	------------------------------[Image Label]------------------------------
	local image_label=frame:extend()
	
	function image_label:new(properties,children)
		image_label.super.new(self,properties,children)
		
		self.image              = eztask.new_property(properties.image)
		self.image_transparency = eztask.new_property(properties.image_transparency or 0)
		self.scale_type         = eztask.new_property(properties.scale_type or gel.enum.scale_type.default)
		self.blend_type         = eztask.new_property(properties.blend_type or gel.enum.blend_type.default)
		self.slice_center       = eztask.new_property(properties.slice_center or lmath.rect.new(0,0,0,0))
		self.image_color        = eztask.new_property(properties.image_color or lmath.color3.new(1,1,1))
		self.image_rect_offset  = eztask.new_property(properties.image_rect_offset or lmath.vector2.new(0,0))
		self.image_size_offset  = eztask.new_property(properties.image_size_offset or lmath.vector2.new(1,1))
		
		self.image:attach(self._draw,true)
		self.image_transparency:attach(self._draw,true)
		self.scale_type:attach(self._draw,true)
		self.blend_type:attach(self._draw,true)
		self.slice_center:attach(self._draw,true)
		self.image_color:attach(self._draw,true)
		self.image_rect_offset:attach(self._draw,true)
		self.image_size_offset:attach(self._draw,true)
	end
	
	------------------------------[Text Label]------------------------------
	local text_label=frame:extend()
	
	function text_label:new(properties,children)
		text_label.super.new(self,properties,children)
		
		self.font              = eztask.new_property(properties.font)
		self.text              = eztask.new_property(properties.text or "")
		self.text_color        = eztask.new_property(properties.text_color or lmath.color3.new(1,1,1))
		self.text_transparency = eztask.new_property(properties.text_transparency or 0)
		self.text_size         = eztask.new_property(properties.text_size or 12)
		self.text_scaled       = eztask.new_property(properties.text_scaled or false)
		self.text_wrapped      = eztask.new_property(properties.text_wrapped or false)
		self.text_x_alignment  = eztask.new_property(properties.text_x_alignment or gel.enum.alignment.x.center)
		self.text_y_alignment  = eztask.new_property(properties.text_y_alignment or gel.enum.alignment.y.center)
		self.highlightable     = eztask.new_property(properties.highlightable or false)

		--Read only
		self.highlighted = eztask.new_property()
		
		self.font:attach(self._draw,true)
		self.text:attach(self._draw,true)
		self.text_color:attach(self._draw,true)
		self.text_transparency:attach(self._draw,true)
		self.text_size:attach(self._draw,true)
		self.text_scaled:attach(self._draw,true)
		self.text_wrapped:attach(self._draw,true)
		self.text_x_alignment:attach(self._draw,true)
		self.text_y_alignment:attach(self._draw,true)
		self.highlightable:attach(self._draw,true)
	end
	
	gel.elements.gel_object  = gel_object
	gel.elements.gui_object  = gui_object
	gel.elements.frame       = frame
	gel.elements.image_label = image_label
	gel.elements.text_label  = text_label

	return gel
end