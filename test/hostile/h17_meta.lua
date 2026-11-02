function _draw() local t=setmetatable({},{__index=function(t,k) return t[k+1] end}) return t[1] end
