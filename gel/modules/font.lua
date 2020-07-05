return function(lumiere,gel)
	local font={loaded={}}
	
	function font.load(path_data)
		if not gel.backend then
			return
		end
		font.loaded[path_data]=(
			font.loaded[path_data]
			or gel.backend.font.load(path_data)
		)
		return path_data
	end
	
	function font.delete(path_data)
		if not gel.backend then
			return
		end
		gel.backend.font.delete(font.loaded[path_data])
		font.loaded[path_data]=nil
	end
	
	function font.get_font_height(font,font_size)
		if not gel.backend then
			return 0
		end
		return gel.backend.font.get_font_height(
			font.loaded[font],
			font_size
		)
	end
	
	function font.get_text_width(text,font,font_size)
		if not gel.backend then
			return 0
		end
		return gel.backend.font.get_text_width(
			text,
			font.loaded[font],
			font_size
		)
	end
	
	function font.get_text_wrap(text,font,font_size,wrap)
		if not gel.backend then
			return 0,0,{}
		end
		return gel.backend.font.get_text_wrap(
			text,
			font.loaded[font],
			font_size,wrap
		)
	end
	
	return font
end