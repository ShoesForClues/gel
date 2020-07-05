return function(lumiere,gel)
	local eztask = lumiere:depend "eztask"
	local lmath  = lumiere:depend "lmath"
	local class  = lumiere:depend "class"
	
	local remove = table.remove
	local insert = table.insert
	
	local object=class:extend()
	
	function object:__tostring()
		return "object"
	end
	
	function object:new()
		self.children      = {}
		self.children_name = {}
		
		self.parent        = eztask.property.new()
		self.name          = eztask.property.new(tostring(self))
		self.index         = eztask.property.new()
		
		self.child_added   = eztask.signal.new()
		self.child_removed = eztask.signal.new()
		
		self.parent: attach(self.append_parent,self)
		self.name:   attach(self.append_name,self)
		self.index:  attach(self.append_index,self)
	end

	function object:delete()
		self.parent.value=nil
		for i=#self.children,1,-1 do
			self.children[i]:delete()
		end
		for _,atr in pairs(self) do
			if type(atr)=="table" then
				local mt=getmetatable(atr)
				if
					mt==eztask.callback
					or mt==eztask.signal
					or mt==eztask.property
				then
					atr:detach()
				end
			end
		end
	end

	function object:get_children(name)
		return self.children_name[name] or self.children
	end

	function object:get_child(name)
		if self.children_name[name] then
			return next(self.children_name[name])
		end
	end
	
	function object:set(property_name,value)
		self[property_name].value=value
		return self
	end
	
	function object:append_parent(new_parent,old_parent)
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
	end
	
	function object:append_name(new_name,old_name)
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
	end
	
	function object:append_index(new_index,old_index)
		if not self.parent.value then
			return
		end
		local children=self.parent.value.children
		if children[old_index]==self then
			remove(children,old_index)
		else
			for i,child in pairs(children) do
				if child==self then
					remove(children,i);break
				end
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
	end
	
	return object
end