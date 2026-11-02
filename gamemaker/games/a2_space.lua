-- space zap
local ship={"...7...","..c7c..",".ccccc.","cc8c8cc","..898.."}
local alien={"b....b",".bbbb.","b7bb7b","bbbbbb","b.bb.b"}
local function mk(t,a,b)
 local o={}
 for i=1,#t do o[i]=string.gsub(t[i],a,b) end
 return o
end
local kinds={alien,mk(alien,"b","e"),mk(alien,"b","a")}
local px,score,lives,over,wait,cool,bul,al,sp,stars,shake
function _init()
 px=12 score=0 lives=3 over=false wait=0 cool=0 bul={} al={} sp={} shake=0 stars={}
 for i=1,12 do add(stars,{x=flr(rnd(32)),y=7+flr(rnd(24)),c=rnd({1,5})}) end
end
function _update()
 if over then
  wait=wait+1
  if wait>25 and (btnp(4) or btnp(5)) then _init() end
  return
 end
 if btn(0) then px=px-1.5 end
 if btn(1) then px=px+1.5 end
 px=mid(0,px,25)
 cool=cool-1
 if (btn(4) or btn(5)) and cool<=0 then
  add(bul,{x=px+3,y=24})
  cool=7
 end
 for b in all(bul) do
  b.y=b.y-2.5
  if b.y<4 then del(bul,b) end
 end
 if rnd(1)<0.025+score*0.0008 and #al<6 then
  add(al,{bx=3+flr(rnd(20)),x=0,y=6,t=rnd(6),s=rnd(kinds)})
 end
 local v=min(0.7,0.2+score*0.005)
 for a in all(al) do
  a.t=a.t+0.07
  a.y=a.y+v
  a.x=a.bx+sin(a.t)*3
  for b in all(bul) do
   if not a.dead and b.x>=a.x-1 and b.x<=a.x+6 and b.y>=a.y-1 and b.y<=a.y+5 then
    a.dead=true
    del(al,a) del(bul,b)
    score=score+1
    for i=1,8 do add(sp,{x=a.x+3,y=a.y+2,dx=rnd(3)-1.5,dy=rnd(3)-1.5,n=10,c=hsv(rnd(1),1,1)}) end
   end
  end
  if not a.dead and a.y>=26 then
   del(al,a)
   lives=lives-1 shake=6
   if lives<=0 then over=true wait=0 end
  end
 end
 for s in all(sp) do
  s.x=s.x+s.dx s.y=s.y+s.dy s.n=s.n-1
  if s.n<=0 then del(sp,s) end
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
 for s in all(stars) do pset(s.x,s.y,s.c) end
 for b in all(bul) do
  rectfill(b.x,b.y,b.x,b.y+3,10)
  pset(b.x,b.y,7)
 end
 for a in all(al) do spr(a.s,a.x,a.y) end
 for s in all(sp) do pset(s.x,s.y,s.c) end
 spr(ship,px,26)
 camera()
 print(score,1,1,7)
 for i=1,lives do rectfill(32-i*4,1,33-i*4,2,8) end
end
