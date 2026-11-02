-- frog crossing
local frogsprite={"77..77","7bbbb7","bbbbbb","bbbbbb","b.bb.b","3....3"}
local lanes={
 {y=22,dir=1,spd=0.7,c=8,w=8},
 {y=18,dir=-1,spd=1.0,c=9,w=6},
 {y=14,dir=1,spd=0.6,c=12,w=10},
 {y=10,dir=-1,spd=1.2,c=10,w=7}
}
local cars,fx,fy,lives,score,over,wait,shake,sparks

function reset()
 fx=14 fy=26
end

function _init()
 cars={}
 for i=1,#lanes do
  add(cars,{l=i,x=rnd(32)})
  add(cars,{l=i,x=rnd(32)})
 end
 reset()
 lives=3 score=0 over=false wait=0 shake=0 sparks={}
end

function _update()
 for _,s in all(sparks) do
  s.x=s.x+s.dx
  s.y=s.y+s.dy
  s.n=s.n-1
  if s.n<=0 then del(sparks,s) end
 end
 if shake>0 then shake=shake-1 end
 if over then
  wait=wait+1
  if wait>25 and (btnp(4) or btnp(5)) then _init() end
  return
 end
 local mult=1+score*0.06
 for _,c in ipairs(cars) do
  local ln=lanes[c.l]
  c.x=c.x+ln.dir*ln.spd*mult
  if ln.dir>0 and c.x>32 then c.x=-ln.w end
  if ln.dir<0 and c.x<-ln.w then c.x=32 end
 end
 if btnp(0) then fx=mid(0,fx-4,26) end
 if btnp(1) then fx=mid(0,fx+4,26) end
 if btnp(2) or btnp(4) or btnp(5) then fy=fy-4 end
 if btnp(3) then fy=min(26,fy+4) end
 if fy<=6 then
  score=score+1
  for i=1,12 do
   if #sparks<24 then
    add(sparks,{x=fx+3,y=fy+3,dx=rnd(2)-1,dy=rnd(2)-1,n=14,c=rnd({8,10,11,12,14})})
   end
  end
  reset()
  return
 end
 for _,c in ipairs(cars) do
  local ln=lanes[c.l]
  if fx+5>c.x and fx+1<c.x+ln.w and fy+5>ln.y and fy+1<ln.y+3 then
   lives=lives-1
   shake=8
   for i=1,10 do
    if #sparks<24 then
     add(sparks,{x=fx+3,y=fy+3,dx=rnd(4)-2,dy=rnd(4)-2,n=10,c=8})
    end
   end
   reset()
   if lives<=0 then over=true wait=0 end
   return
  end
 end
end

function _draw()
 cls(0)
 if over then
  print("SCORE",6,6,9)
  print(score,16-#tostring(score)*4,14,hsv(time()*0.5,1,1),2)
  return
 end
 if shake>0 then camera(rnd(3)-1,rnd(3)-1) end
 rectfill(0,6,31,7,10)
 rectfill(0,8,31,25,5)
 rectfill(0,26,31,31,3)
 for _,c in ipairs(cars) do
  local ln=lanes[c.l]
  rectfill(c.x,ln.y,c.x+ln.w-1,ln.y+2,ln.c)
 end
 spr(frogsprite,fx,fy)
 for s in all(sparks) do pset(s.x,s.y,s.c) end
 camera()
 rectfill(0,0,15,5,0)
 print(score,1,1,7)
 for i=1,lives do pset(32-i*2,1,8) end
end
