-- taco dino
local tacos={}
local chilis={}
local sp={}
local dx=12
local sz=3
local lives=3
local score=0
local over=false
local wait=0
local shake=0
local cd=20
function burst(x,y,c)
 for i=1,5 do
  if #sp<40 then add(sp,{x=x,y=y,dx=rnd(2)-1,dy=rnd(2)-1.5,n=10,c=c}) end
 end
end
function _init()
 tacos={} chilis={} sp={}
 dx=12 sz=3 lives=3 score=0 over=false wait=0 shake=0 cd=20
end
function _update()
 if over then
  wait=wait+1
  if wait>25 and (btnp(4) or btnp(5)) then _init() end
  return
 end
 if btn(0) then dx=dx-1.5 end
 if btn(1) then dx=dx+1.5 end
 dx=mid(0,dx,31-sz)
 if btnp(4) or btnp(5) then
  shake=4
  burst(dx+sz/2,28,rnd({8,9,10,11,12,14}))
 end
 cd=cd-1
 if cd<=0 and #tacos+#chilis<10 then
  cd=max(12,40-score*2)
  local x=flr(rnd(29))+2
  if rnd(1)<0.2 then add(chilis,{x=x,y=7}) else add(tacos,{x=x,y=7}) end
 end
 local fs=min(1.2,0.4+score*0.04)
 local cx=dx+sz/2
 for t in all(tacos) do
  t.y=t.y+fs
  if t.y>=30-sz and t.y<=31 and abs(t.x-cx)<sz/2+3 then
   del(tacos,t)
   score=score+1
   sz=min(20,sz+1)
   burst(t.x,30-sz,9)
  elseif t.y>31 then
   del(tacos,t)
   lives=lives-1
   shake=6
   if lives<=0 then over=true wait=0 end
  end
 end
 for c in all(chilis) do
  c.y=c.y+fs*0.8
  if c.y>=30-sz and c.y<=31 and abs(c.x-cx)<sz/2+3 then
   del(chilis,c)
   sz=max(3,sz-2)
   shake=3
   burst(c.x,30-sz,8)
  elseif c.y>31 then
   del(chilis,c)
  end
 end
 for s in all(sp) do
  s.x=s.x+s.dx s.y=s.y+s.dy s.dy=s.dy+0.15 s.n=s.n-1
  if s.n<=0 then del(sp,s) end
 end
 if shake>0 then shake=shake-1 end
end
function _draw()
 cls(0)
 if over then
  print("SCORE",6,8,10)
  local s=tostring(score)
  local x=16-#s*2
  for i=0,1 do
   for j=0,1 do print(s,x+i,15+j,hsv(time()*0.3,1,1)) end
  end
  return
 end
 if shake>0 then camera(flr(rnd(3))-1,flr(rnd(3))-1) end
 for t in all(tacos) do
  rectfill(t.x-3,t.y,t.x+3,t.y+2,9)
  line(t.x-2,t.y+1,t.x+2,t.y+1,10)
 end
 for c in all(chilis) do
  rectfill(c.x-1,c.y,c.x+1,c.y+2,8)
  pset(c.x,c.y-1,11)
 end
 local g=sz
 local x=flr(dx)
 local top=30-g
 rectfill(x,top,x+g-1,29,11)
 rectfill(x+g-2,top-2,x+g+1,top,11)
 pset(x+g-1,top-1,0)
 rectfill(x-2,26,x,27,11)
 for s in all(sp) do pset(s.x,s.y,s.c) end
 camera()
 print(score,1,1,7)
 for i=1,lives do rectfill(31-i*3,1,32-i*3,2,8) end
end
