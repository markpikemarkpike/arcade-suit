-- road racer
local tpl={".XXX.","XcccX","6XXX6","XXXXX","6XXX6","XXXXX",".X.X."}
local function mk(ch)
 local t={}
 for i=1,7 do t[i]=(string.gsub(tpl[i],"X",ch)) end
 return t
end
local me=mk("a")
local es={mk("8"),mk("9"),mk("b"),mk("e"),mk("d")}
local px,score,lives,over,wait,cars,sparks,shake,inv,off,sc,sp,boost,t
function _init()
 px=14 score=0 lives=3 over=false wait=0 cars={} sparks={} shake=0
 inv=0 off=0 sc=10 sp=1 boost=false t=0
end
function _update()
 if over then
  wait=wait+1
  if wait>25 and (btnp(4) or btnp(5)) then _init() end
  return
 end
 t=t+1
 if btn(0) then px=px-1.5 end
 if btn(1) then px=px+1.5 end
 px=mid(4,px,23)
 boost=btn(4) or btn(5)
 sp=min(1.8,1+score*0.02)
 if boost then sp=sp*1.4 end
 off=(off+sp)%8
 sc=sc-sp
 if sc<=0 and #cars<8 then
  add(cars,{x=4+flr(rnd(20)),y=-8,m=0.5+rnd(0.3),s=rnd(es)})
  sc=13+rnd(10)
 end
 if inv>0 then inv=inv-1 end
 for c in all(cars) do
  c.y=c.y+sp*c.m
  if c.y>31 then
   del(cars,c) score=score+1
  elseif inv==0 and abs(c.x-px)<4 and abs(c.y-23)<6 then
   del(cars,c) lives=lives-1 shake=8 inv=40
   for i=1,8 do
    if #sparks<40 then add(sparks,{x=px+2,y=24,dx=rnd(3)-1.5,dy=rnd(3)-1.5,n=10,c=rnd({7,9,10})}) end
   end
   if lives<=0 then over=true wait=0 end
  end
 end
 if boost and #sparks<30 then
  add(sparks,{x=px+1+rnd(3),y=30,dx=rnd(1)-0.5,dy=0.8+rnd(0.5),n=8,c=hsv(t*0.05,1,1)})
 end
 for s in all(sparks) do
  s.x=s.x+s.dx s.y=s.y+s.dy s.n=s.n-1
  if s.n<=0 then del(sparks,s) end
 end
 if shake>0 then shake=shake-1 end
end
function _draw()
 cls(0)
 if over then
  print("SCORE",6,8,9)
  print(score,16-#tostring(score)*2,16,hsv(time(),1,1))
  return
 end
 if shake>0 then camera(rnd(3)-1,rnd(3)-1) end
 for y=0,31 do
  local k=flr(y-off)
  local cc=(flr(k/2)%2==0) and 8 or 7
  pset(3,y,cc) pset(28,y,cc)
  if k%8<4 then pset(12,y,6) pset(20,y,6) end
 end
 for c in all(cars) do spr(c.s,c.x,c.y) end
 if inv==0 or t%4<2 then spr(me,px,23) end
 for s in all(sparks) do pset(s.x,s.y,s.c) end
 camera()
 rectfill(0,0,#tostring(score)*4,5,0)
 print(score,1,1,7)
 for i=1,lives do rectfill(32-i*3,1,33-i*3,2,8) end
end
