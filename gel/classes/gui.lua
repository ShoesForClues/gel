return function(lumiere,gel)
	local eztask = lumiere:depend "eztask"
	local lmath  = lumiere:depend "lmath"
	local class  = lumiere:depend "class"
	
	local gui=gel.class.object:extend()
	
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
		end)
		self.cursor_pressed:attach(function(_,button,x,y)
			self.focused_text.value=nil
			self:append_cursor(x,y,button,1,true)
		end)
		self.cursor_released:attach(function(_,button,x,y)
			self:append_cursor(x,y,button,1,false)
		end)
		
		self.resolution:attach(function()
			for _,child in pairs(self.children) do
				if child.update_geometry then
					child:update_geometry()
				end
			end
		end)
		
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
		end)
		
		self.key_pressed:attach(function(_,key)
			local text_object=self.focused_text.value
			if not text_object or not text_object.editable.value then
				return
			end
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
		end)
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
			local relative_point=(
				element.cframe.value:inverse()
				*lmath.vector3.new(x,0,y)
			)
			local in_bound=(
				relative_point.x>=0
				and relative_point.z>=0
				and relative_point.x<element.absolute_size.value.x
				and relative_point.z<element.absolute_size.value.y
			)
			if not in_bound then
				element.targeted.value=false
				self.targeted_elements[element]=nil
			end
		end
		
		for _,child in pairs(self.children) do
			if child.append_cursor then
				if child:append_cursor(cursor_x,cursor_y,button,id,state) then
					break
				end
			end
		end
	end
	
	return gui
end