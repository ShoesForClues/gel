return function(lumiere,gel)
	local eztask = lumiere:depend "eztask"
	local lmath  = lumiere:depend "lmath"
	local class  = lumiere:depend "class"
	
	local text=gel.class.frame:extend()
	
	function text:__tostring()
		return "text"
	end
	
	function text:new()
		text.super.new(self)
		
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
		self.filter_mode       = eztask.property.new(gel.enum.filter_mode.linear)
		self.focused           = eztask.property.new(false)
		self.selectable        = eztask.property.new(false)
		self.editable          = eztask.property.new(false)
		self.cursor_position   = eztask.property.new(0)
		self.highlight_opacity = eztask.property.new(0.5)
		self.highlight_color   = eztask.property.new(lmath.color3.new(0,0.2,1))
		self.highlight_start   = eztask.property.new(0)
		self.highlight_end     = eztask.property.new(0)
		
		self.font:              attach(self.append_draw,self)
		self.text:              attach(self.append_draw,self)
		self.text_color:        attach(self.append_draw,self)
		self.text_opacity:      attach(self.append_draw,self)
		self.text_size:         attach(self.append_draw,self)
		self.text_scaled:       attach(self.append_draw,self)
		self.text_wrapped:      attach(self.append_draw,self)
		self.multiline:         attach(self.append_draw,self)
		self.text_x_alignment:  attach(self.append_draw,self)
		self.text_y_alignment:  attach(self.append_draw,self)
		self.filter_mode:       attach(self.append_draw,self)
		self.focused:           attach(self.append_draw,self)
		self.cursor_position:   attach(self.append_draw,self)
		self.highlight_opacity: attach(self.append_draw,self)
		self.highlight_color:   attach(self.append_draw,self)
		self.highlight_start:   attach(self.append_draw,self)
		self.highlight_end:     attach(self.append_draw,self)
		
		self.selected:          attach(self.append_text_focused,self)
		self.gui:               attach(self.append_gui_focused_event,self)
		self.focused:           attach(self.append_gui_focused,self)
	end
	
	function text:delete()
		text.super.delete(self)
		
		if self.focused_text_event then
			self.focused_text_event:detach()
			self.focused_text_event=nil
		end
		
		if
			self.gui.value
			and self.gui.value.focused_text.value==self
		then
			self.gui.value.focused_text.value=nil
		end
	end
	
	function text:draw()
		text.super.draw(self)
	end
	
	function text:append_text_focused(selected)
		if selected and self.selectable.value then
			self.focused.value=true
		end
	end
	
	function text:append_gui_focused_event(new_gui,old_gui)
		if self.focused_text_event then
			self.focused_text_event:detach()
			self.focused_text_event=nil
		end
		if
			old_gui
			and old_gui.focused_text.value==self
		then
			old_gui.focused_text.value=nil
		end
		if new_gui then
			self.focused_text_event=new_gui.focused_text:attach(function(_,element)
				self.focused.value=(element==self)
			end)
		end
	end
	
	function text:append_gui_focused(focused)
		if not self.gui.value then
			return
		end
		if focused then
			self.gui.value.focused_text.value=self
		elseif self.gui.value.focused_text.value==self then
			self.gui.value.focused_text.value=nil
		end
	end
	
	return text
end