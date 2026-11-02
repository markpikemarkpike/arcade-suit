-- fireworks
local rockets={}
local parts={}
local cols={8,9,10,11,12,13,14,7}
local cd=0
local cur=16
local shake=0
function boom(x,y,c)
 shake=3
 for i=1,14 do
  if #parts<60 then
   local a=i/14*6.283+rnd(0.3)
   local s=0.5+rnd(0.9)
   add(parts,{x=x,y=y,dx=cos(a)*s,dy=sin(a)*s,n=18+flr(rnd(12)),c=c})
  end
 end
end
function launch(x)
 if #rockets<6 then
  add(rockets,{x=x,y=31,vy=-(1.6+rnd(0.8)),ty=3+flr(rnd(12)),c=rnd(cols)})
 end
end
function _init()
 rockets={} parts={} cd=0 cur=16 shake=0
end
function _update()
 if btn(0) then cur=max(0,cur-1) end
 if btn(1) then cur=min(31,cur+1) end
 if btnp(4) or btnp(5) then launch(cur) end
 cd=cd-1
 if cd<=0 then
  launch(flr(rnd(32)))
  cd=10+flr(rnd(20))
 end
 for r in all(rockets) do
  r.y=r.y+r.vy
  if r.y<=r.ty then
   boom(r.x,r.y,r.c)
   del(rockets,r)
  end
 end
 for p in all(parts) do
  p.x=p.x+p.dx p.y=p.y+p.dy
  p.dx=p.dx*0.97 p.dy=p.dy*0.97+0.03
  p.n=p.n-1
  if p.n<=0 then del(parts,p) end
 end
 if shake>0 then shake=shake-1 end
end
function _draw()
 cls(0)
 if shake>0 then camera(flr(rnd(3))-1,flr(rnd(3))-1) end
 for r in all(rockets) do
  pset(r.x,r.y,7)
  pset(r.x,r.y+1,r.c)
  pset(r.x,r.y+2,r.c)
 end
 for p in all(parts) do
  rectfill(p.x,p.y,p.x+1,p.y+1,p.c)
 end
 camera()
 pset(cur,30,7)
 line(cur-1,31,cur+1,31,7)
end
