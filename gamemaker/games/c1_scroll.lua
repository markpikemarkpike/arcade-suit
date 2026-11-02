-- rainbow scroll
local msg="HAPPY HALLOWEEN!"
local letters={}
local stars={}
local x=32
local speed=1
local dir=1
local w=#msg*4
function _init()
 for i=1,#msg do letters[i]=string.sub(msg,i,i) end
 for i=1,10 do
  local y=flr(rnd(6))
  if i%2==0 then y=26+flr(rnd(6)) end
  stars[i]={x=flr(rnd(32)),y=y}
 end
 x=32 speed=1 dir=1
end
function _update()
 x=x+speed*dir
 if x<-w then x=32 end
 if x>32 then x=-w end
 if btn(2) then speed=min(2,speed+0.05) end
 if btn(3) then speed=max(0.5,speed-0.05) end
 if btnp(4) then dir=-dir end
 if btnp(5) then speed=1 end
end
function _draw()
 cls(0)
 local t=time()
 for i=1,#stars do
  local s=stars[i]
  local c=5
  if flr(t*3+i)%2==0 then c=7 end
  pset(s.x,s.y,c)
 end
 for i=1,#letters do
  local px=x+(i-1)*4
  print(letters[i],px+1,14,5)
  print(letters[i],px,13,hsv(t*0.2+i/16,1,1))
 end
end
