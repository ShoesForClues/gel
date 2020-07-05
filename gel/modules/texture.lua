return function(lumiere,gel)
	local texture={loaded={}}
	
	function texture.load(path_data)
		if not gel.backend then
			return
		end
		texture.loaded[path_data]=(
			texture.loaded[path_data]
			or gel.backend.texture.load(path_data)
		)
		return path_data
	end
	
	function texture.delete(path_data)
		if not gel.backend then
			return
		end
		gel.backend.texture.delete(texture.loaded[path_data])
		texture.loaded[path_data]=nil
	end
	
	function texture.get_texture_size(path_data)
		if not gel.backend then
			return 0,0
		end
		return gel.backend.texture.get_texture_size(
			texture.loaded[path_data]
		)
	end
	
	return texture
end