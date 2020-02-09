--[[
 _______________________________________
|Graphic_Elements_Library_________[-][x]|
|     ______    ______    __            |
|    /\  ___\  /\  ___\  /\ \           |
|    \ \ \__ \ \ \  __\  \ \ \____      |
|     \ \_____\ \ \_____\ \ \_____\     |
|      \/_____/  \/_____/  \/_____/     |
|                                       |
| GEL created by ShoesForClues (c) 2020 |
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
	local remove = table.remove
	local insert = table.insert
	
	local gel={
		_version = {0,5,1},
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
	
	--Classes
	local gel_object  = class:extend()
	local gui_object  = gel_object:extend()
	local frame       = gui_object:extend()
	local image_label = frame:extend()
	local text_label  = frame:extend()
	
	--Functions
	function gel.wrap(element,wrap)
		local _new=element.new
		element.new=function(...) _new(...);wrap(...) end
		return element
	end
	
	function gel.rotate_point(x1,y1,x2,y2,angle) --Point, Origin, Radians
		local s=sin(angle)
		local c=cos(angle)
		x1=x1-x2
		y1=y1-y2
		return (x1*c-y1*s)+x2,(x1*s+y1*c)+y2
	end
	
	------------------------------[gel_object]------------------------------
	function gel_object:__tostring()
		return "gel_object"
	end
	
	function gel_object:init(properties,children)
		if children~=nil then
			for i,child in pairs(children) do
				child.name.value=child.name.value or tostring(i)
				child.index.value=child.index.value or #self.children_i+1
				child.parent.value=self
			end
		end
		if properties~=nil then
			self.parent.value=properties.parent
		end
	end
	
	function gel_object:new(properties,children)
		self.children_n = {}
		self.children_i = {}
		
		self.parent = eztask.property.new()
		self.name   = eztask.property.new(properties.name)
		self.index  = eztask.property.new(properties.index)
		
		self.child_added   = eztask.signal.new()
		self.child_removed = eztask.signal.new()
		
		self.parent:attach(function(new_parent,old_parent)
			if old_parent then
				old_parent.children_n[self.name.value]=nil
				if old_parent.children_i[self.index.value]==self then
					remove(old_parent.children_i,self.index.value)
				else
					for i=1,#old_parent.children_i do
						if old_parent.children_i[i]==self then
							remove(old_parent.children_i,i)
							break
						end
					end
				end
				old_parent.child_removed:invoke(self)
			end
			if new_parent then
				rawset(self.index,"_value",self.index.value or #new_parent.children_i+1)
				rawset(self.name,"_value",self.name.value or tostring(self.index.value))
				new_parent.children_n[self.name.value]=self
				insert(new_parent.children_i,lmath.clamp(self.index.value,1,#new_parent.children_i+1),self)
				new_parent.child_added:invoke(self)
			end
		end)
		
		self.name:attach(function(new_name,old_name)
			if not self.parent.value then
				return
			end
			if old_name then
				self.parent.value[old_name]=nil
			end
			if new_name then
				self.parent.value[new_name]=self
			end
		end)
		
		self.index:attach(function(new_index,old_index)
			local parent=self.parent.value
			if not parent then
				return
			end
			if old_index then
				if parent.children_i[old_index]==self then
					remove(parent.children_i,old_index)
				else
					for i=1,#parent.children_i do
						if parent.children_i[i]==self then
							remove(parent.children_i,i)
							break
						end
					end
				end
			end
			if new_index then
				insert(parent.children_i,new_index,self)
			end
		end)
		
		if getmetatable(self)==gel_object then
			self:init(properties,children)
		end
	end
	
	function gel_object:delete()
		for _,child in pairs(self.children_i) do
			child:delete()
		end
		
		self.parent.value=nil
		
		self.parent:detach()
		self.name:detach()
		self.index:detach()
		
		self.child_added:detach()
		self.child_removed:detach()
	end
	
	------------------------------[gui_object]------------------------------
	function gui_object:__tostring()
		return "gui_object"
	end
	
	function gui_object:new(properties,children)
		gui_object.super.new(self,properties,children)
		
		self.redraw = true
		
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
		self.visible      = eztask.property.new(properties.visible or false)
		self.position     = eztask.property.new(properties.position or lmath.udim2.new(0,0,0,0))
		self.size         = eztask.property.new(properties.size or lmath.udim2.new(0,0,0,0))
		self.rotation     = eztask.property.new(properties.rotation or 0)
		self.anchor_point = eztask.property.new(properties.anchor_point or lmath.vector2.new(0,0))
		self.clip         = eztask.property.new(properties.clip or false)
		
		self.absolute_size     = eztask.property.new(lmath.vector2.new(0,0))
		self.absolute_position = eztask.property.new(lmath.vector2.new(0,0))
		self.absolute_anchor   = eztask.property.new(lmath.vector2.new(0,0))
		self.absolute_rotation = eztask.property.new(self.rotation.value)
		self.relative_position = eztask.property.new(lmath.vector2.new(0,0))
		self.relative_rotation = eztask.property.new(self.rotation.value)
		
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
		
		if getmetatable(self)==gui_object then
			self:init(properties,children)
		end
	end
	
	function gui_object:delete()
		gui_object.super.delete(self)
		
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
	
	function gui_object:update_geometry() --This was a huge pain
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
			
			abs_size_x=parent_abs_size.x*size.x.scale+size.x.offset
			abs_size_y=parent_abs_size.y*size.y.scale+size.y.offset
			
			abs_rot=parent.absolute_rotation.value+self.rotation.value
			
			local anchor_size_x=abs_size_x*self.anchor_point.value.x
			local anchor_size_y=abs_size_y*self.anchor_point.value.y
			
			local anchor_offset_x,anchor_offset_y=gel.rotate_point(
				parent_abs_size.x*position.x.scale+position.x.offset,
				parent_abs_size.y*position.y.scale+position.y.offset,
				0,
				0,
				parent.absolute_rotation.value
			)
			
			local abs_offset_x,abs_offset_y=gel.rotate_point(
				parent_abs_size.x*position.x.scale+position.x.offset-anchor_size_x,
				parent_abs_size.y*position.y.scale+position.y.offset-anchor_size_y,
				0,
				0,
				parent.absolute_rotation.value
			)
			
			abs_anchor_x=parent_abs_pos.x+anchor_offset_x
			abs_anchor_y=parent_abs_pos.y+anchor_offset_y
			
			abs_pos_x,abs_pos_y=gel.rotate_point(
				parent_abs_pos.x+abs_offset_x,
				parent_abs_pos.y+abs_offset_y,
				abs_anchor_x,
				abs_anchor_y,
				self.rotation.value
			)
			
			local n_top_parent_abs_pos_x,n_top_parent_abs_pos_y=gel.rotate_point(
				top_parent.absolute_position.value.x,
				top_parent.absolute_position.value.y,
				top_parent.absolute_anchor.value.x,
				top_parent.absolute_anchor.value.y,
				-top_parent.absolute_rotation.value
			)
			
			local n_abs_pos_x,n_abs_pos_y=gel.rotate_point(
				abs_pos_x,
				abs_pos_y,
				top_parent.absolute_anchor.value.x,
				top_parent.absolute_anchor.value.y,
				-top_parent.absolute_rotation.value
			)
			
			rel_pos_x=n_abs_pos_x-n_top_parent_abs_pos_x
			rel_pos_y=n_abs_pos_y-n_top_parent_abs_pos_y
			
			rel_rot=abs_rot-top_parent.absolute_rotation.value
		else
			abs_size_x=size.x.offset
			abs_size_y=size.y.offset
			
			abs_rot=self.rotation.value
			
			local anchor_size_x=abs_size_x*self.anchor_point.value.x
			local anchor_size_y=abs_size_y*self.anchor_point.value.y
			
			abs_anchor_x=position.x.offset
			abs_anchor_y=position.y.offset
			
			abs_pos_x,abs_pos_y=gel.rotate_point(
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
			self.absolute_size.value=lmath.vector2.new(abs_size_x,abs_size_y)
		end
		if self.absolute_position.value.x~=abs_pos_x or self.absolute_position.value.y~=abs_pos_y then
			self.absolute_position.value=lmath.vector2.new(abs_pos_x,abs_pos_y)
		end
		if self.absolute_anchor.value.x~=abs_anchor_x or self.absolute_anchor.value.y~=abs_anchor_y then
			self.absolute_anchor.value=lmath.vector2.new(abs_anchor_x,abs_anchor_y)
		end
		if self.relative_position.value.x~=rel_pos_x or self.relative_position.value.y~=rel_pos_y then
			self.relative_position.value=lmath.vector2.new(rel_pos_x,rel_pos_y)
		end
		if self.absolute_rotation.value~=abs_rot then
			self.absolute_rotation.value=abs_rot
		end
		if self.relative_rotation.value~=rel_rot then
			self.relative_rotation.value=rel_rot
		end
	end
	
	function gui_object:draw() end
	function gui_object:draw_render() end
	function gui_object:draw_buffer() end
	
	function gui_object:render()
		if not self.visible.value then
			return
		end
		
		self:update_geometry()
		self:draw()
		
		if self.redraw or not self.clip.value or not self.top_parent.value then
			if self.clip.value then
				for _,child in pairs(self.children_i) do
					child.top_parent.value=self
					child:render()
				end
			else
				for _,child in pairs(self.children_i) do
					child.top_parent.value=self.top_parent.value
					child:render()
				end
			end
			self.redraw=false
		end
		
		self:draw_buffer()
	end
	
	------------------------------[frame]------------------------------
	function frame:__tostring()
		return "frame"
	end
	
	function frame:new(properties,children)
		frame.super.new(self,properties,children)
		
		self.background_color   = eztask.property.new(properties.background_color or lmath.color3.new(1,1,1))
		self.background_opacity = eztask.property.new(properties.background_opacity or 1)
		
		self.background_color:attach(self._draw,true)
		self.background_opacity:attach(self._draw,true)
		
		if getmetatable(self)==frame then
			self:init(properties,children)
		end
	end
	
	function frame:delete()
		frame.super.delete(self)
		
		self.background_color:detach()
		self.background_opacity:detach()
	end
	
	------------------------------[image_label]------------------------------
	function image_label:__tostring()
		return "image_label"
	end
	
	function image_label:new(properties,children)
		image_label.super.new(self,properties,children)
		
		self.image             = eztask.property.new(properties.image)
		self.image_opacity     = eztask.property.new(properties.image_opacity or 1)
		self.scale_mode        = eztask.property.new(properties.scale_mode or gel.enum.scale_mode.stretch)
		self.filter_mode       = eztask.property.new(properties.filter_mode or gel.enum.filter_mode.nearest)
		self.slice_center      = eztask.property.new(properties.slice_center or lmath.rect.new(0,0,0,0))
		self.image_color       = eztask.property.new(properties.image_color or lmath.color3.new(1,1,1))
		self.image_rect_offset = eztask.property.new(properties.image_rect_offset or lmath.vector2.new(0,0))
		self.image_size_offset = eztask.property.new(properties.image_size_offset or lmath.vector2.new(1,1))
		
		self.image:attach(self._draw,true)
		self.image_opacity:attach(self._draw,true)
		self.scale_mode:attach(self._draw,true)
		self.filter_mode:attach(self._draw,true)
		self.slice_center:attach(self._draw,true)
		self.image_color:attach(self._draw,true)
		self.image_rect_offset:attach(self._draw,true)
		self.image_size_offset:attach(self._draw,true)
		
		if getmetatable(self)==image_label then
			self:init(properties,children)
		end
	end
	
	function image_label:delete()
		image_label.super.delete(self)
		
		self.image:detach()
		self.image_opacity:detach()
		self.scale_mode:detach()
		self.filter_mode:detach()
		self.slice_center:detach()
		self.image_color:detach()
		self.image_rect_offset:detach()
		self.image_size_offset:detach()
	end
	
	------------------------------[text_label]------------------------------
	function text_label:__tostring()
		return "text_label"
	end
	
	function text_label:new(properties,children)
		text_label.super.new(self,properties,children)
		
		self.font             = eztask.property.new(properties.font)
		self.text             = eztask.property.new(properties.text or "")
		self.text_color       = eztask.property.new(properties.text_color or lmath.color3.new(1,1,1))
		self.text_opacity     = eztask.property.new(properties.text_opacity or 0)
		self.text_size        = eztask.property.new(properties.text_size or 12)
		self.text_scaled      = eztask.property.new(properties.text_scaled or false)
		self.text_wrapped     = eztask.property.new(properties.text_wrapped or false)
		self.text_x_alignment = eztask.property.new(properties.text_x_alignment or gel.enum.alignment.x.center)
		self.text_y_alignment = eztask.property.new(properties.text_y_alignment or gel.enum.alignment.y.center)
		self.filter_mode      = eztask.property.new(properties.filter_mode or gel.enum.filter_mode.nearest)
		self.selectable       = eztask.property.new(properties.selectable or false)

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
		
		if getmetatable(self)==text_label then
			self:init(properties,children)
		end
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
	
	gel.gel_object  = gel_object
	gel.gui_object  = gui_object
	gel.frame       = frame
	gel.image_label = image_label
	gel.text_label  = text_label
	
	return gel
end