--[[
 _______________________________________
|Graphic_Elements_Library_________[-][x]|
|     ______    ______    __            |
|    /\  ___\  /\  ___\  /\ \           |
|    \ \ \__ \ \ \  __\  \ \ \____      |
|     \ \_____\ \ \_____\ \ \_____\     |
|      \/_____/  \/_____/  \/_____/     |
|                                       |
|   Created by ShoesForClues (c) 2020   |
|_______________________________________|

MIT License

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
	local sin    = math.sin
	local cos    = math.cos
	local floor  = math.floor
	local ceil   = math.ceil
	local remove = table.remove
	local insert = table.insert
	
	local gel={
		_version = {0,5,3},
		enum     = {},
		elements = {}
	}
	
	--Enums
	gel.enum.scale_mode={
		stretch = "stretch",
		slice   = "slice",
		tile    = "tile"
	}
	gel.enum.filter_mode={
		nearest  = "nearest",
		bilinear = "bilinear"
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
	function gel.wrap(element,method,wrap)
		assert(element[method],("Method %s does not exist in %s"):format(method,element))
		assert(wrap,"Cannot wrap method with nil")
		
		local _method=element[method]
		element[method]=function(...) _method(...);wrap(...) end
		
		return element
	end
	
	------------------------------[gel_object]------------------------------
	local gel_object=class:extend()
	
	function gel_object:__tostring()
		return "gel_object"
	end
	
	function gel_object:new()
		self.children = {}
		
		self.parent = eztask.property.new()
		self.index  = eztask.property.new()
		
		self.child_added   = eztask.signal.new()
		self.child_removed = eztask.signal.new()
		
		self.parent:attach(function(new_parent,old_parent)
			if old_parent then
				if old_parent.children[self.index.value]==self then
					remove(old_parent.children,self.index.value)
				else
					for i=1,#old_parent.children do
						if old_parent.children[i]==self then
							remove(old_parent.children,i)
							break
						end
					end
				end
				old_parent.child_removed:invoke(self)
			end
			if new_parent then
				self.index._value=#new_parent.children+1
				insert(new_parent.children,self.index.value,self)
				new_parent.child_added:invoke(self)
			end
		end)
		
		self.index:attach(function(new_index,old_index)
			local parent=self.parent.value
			if not parent then
				return
			end
			if old_index then
				if parent.children[old_index]==self then
					remove(parent.children,old_index)
				else
					for i=1,#parent.children do
						if parent.children[i]==self then
							remove(parent.children,i)
							break
						end
					end
				end
			end
			if new_index then
				insert(parent.children,lmath.clamp(new_index,1,#parent.children),self)
			end
		end)
	end
	
	function gel_object:delete()
		for _,child in pairs(self.children) do
			child:delete()
		end
		
		self.parent.value=nil
		
		self.parent:detach()
		self.index:detach()
		
		self.child_added:detach()
		self.child_removed:detach()
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
		
		self.top_parent   = eztask.property.new()
		self.visible      = eztask.property.new(false)
		self.position     = eztask.property.new(lmath.udim2.new(0,0,0,0))
		self.size         = eztask.property.new(lmath.udim2.new(0,0,0,0))
		self.rotation     = eztask.property.new(0)
		self.anchor_point = eztask.property.new(lmath.vector2.new(0,0))
		self.clip         = eztask.property.new(false)
		
		--Read only
		self.absolute_size     = eztask.property.new(lmath.vector2.new(0,0))
		self.absolute_position = eztask.property.new(lmath.vector2.new(0,0))
		self.absolute_anchor   = eztask.property.new(lmath.vector2.new(0,0))
		self.absolute_rotation = eztask.property.new(self.rotation.value)
		self.relative_position = eztask.property.new(lmath.vector2.new(0,0))
		self.relative_rotation = eztask.property.new(self.rotation.value)
		self.rendering         = eztask.property.new()
		
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
	end
	
	function element:delete()
		element.super.delete(self)
		
		self.visible:detach()
		self.position:detach()
		self.size:detach()
		size.rotation:detach()
		self.anchor_point:detach()
		self.clip:detach()
		
		self.absolute_size:detach()
		self.absolute_position:detach()
		self.absolute_anchor:detach()
		self.absolute_rotation:detach()
		self.relative_position:detach()
		self.relative_rotation:detach()
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
		
		if parent then
			local top_parent=self.top_parent.value or parent
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
			
			local n_top_parent_abs_pos_x,n_top_parent_abs_pos_y=lmath.rotate_point(
				top_parent.absolute_position.value.x,
				top_parent.absolute_position.value.y,
				top_parent.absolute_anchor.value.x,
				top_parent.absolute_anchor.value.y,
				-top_parent.absolute_rotation.value
			)
			
			local n_abs_pos_x,n_abs_pos_y=lmath.rotate_point(
				abs_pos_x,
				abs_pos_y,
				top_parent.absolute_anchor.value.x,
				top_parent.absolute_anchor.value.y,
				-top_parent.absolute_rotation.value
			)
			
			rel_pos_x=floor(n_abs_pos_x-n_top_parent_abs_pos_x)
			rel_pos_y=floor(n_abs_pos_y-n_top_parent_abs_pos_y)
			
			rel_rot=abs_rot-top_parent.absolute_rotation.value
		else
			abs_size_x=size.x.offset
			abs_size_y=size.y.offset
			
			abs_rot=self.rotation.value
			
			local anchor_size_x=abs_size_x*self.anchor_point.value.x
			local anchor_size_y=abs_size_y*self.anchor_point.value.y
			
			abs_anchor_x=position.x.offset
			abs_anchor_y=position.y.offset
			
			abs_pos_x,abs_pos_y=lmath.rotate_point(
				abs_anchor_x-anchor_size_x,
				abs_anchor_y-anchor_size_y,
				abs_anchor_x,
				abs_anchor_y,
				self.rotation.value
			)
			
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
					child.top_parent.value=self
					child:render()
				end
			else
				for _,child in pairs(self.children) do
					child.top_parent.value=self.top_parent.value
					child:render()
				end
			end
			self.redraw=false
		end
		
		self:draw_buffer()
		self.rendering.value=nil
	end
	
	------------------------------[gui]------------------------------
	local gui=element:extend()
	
	function gui:__tostring()
		return "gui"
	end
	
	function gui:new()
		gui.super.new(self)
		
		self.focused_elements={}
		
		self.cursor_position = eztask.property.new(lmath.vector2.new(0,0))
		
		self.cursor_position:attach(function(position)
			
			
			for _,element in pairs(self.focused_elements) do
				local abs_pos=element.absolute_position.value
				local abs_size=element.absolute_size.value
				
				local in_bound=(
					position.x>=abs_pos.x and 
					position.y>=abs_pos.x and 
					position.x<=abs_pos.x+abs_size.x and 
					position.y<=abs_pos.y+abs_size.y
				)
				
				if not in_bound then
					element.interact.focused.value=false
					element.interact.selected.value=false
					self.focused_elements[element]=nil
				end
			end
		end,true)
	end
	
	function gui:delete()
		gui.super.delete(self)
		
		self.cursor_position:detach()
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
	
	----------------------------------------------------------------------
	gel.elements.gel_object  = gel_object
	gel.elements.element     = element
	gel.elements.gui         = gui
	gel.elements.frame       = frame
	gel.elements.image_label = image_label
	gel.elements.text_label  = text_label
	
	return gel
end