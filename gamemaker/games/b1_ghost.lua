-- ghost light
local gh={".777.","70707","77777","77777","7.7.7"}
local px,py,fx,fy,gx,gy,cx,cy,score,lives,over,wait,sparks,shake,flash,t,lit
local function newcandy()
 cx=flr(rnd(28)) cy=8+flr(rnd(20))
end
function _init()
 px=14 py=16 fx=1 fy=0 gx=1 gy=8 score=0 lives=3 over=false wait=0
 sparks={} shake=0 flash=0 t=0 lit=false
 newcandy()
end
function _update()
 if over then
  wait=wait+1
  if wait>25 and (btnp(4) or btnp(5)) then _init() end
  return
 end
 t=t+1
 local dx,dy=0,0
 if btn(0) then dx=-1 end
 if btn(1) then dx=1 end
 if btn(2) then dy=-1 end
 if btn(3) then dy=1 end
 if dx~=0 or dy~=0 then
  local l=sqrt(dx*dx+dy*dy)
  fx=dx/l fy=dy/l
  px=mid(0,px+fx*1.1,29) py=mid(7,py+fy*1.1,29)
 end
 local ex,ey=px+1-gx-2,py+1-gy-2
 local d=sqrt(ex*ex+ey*ey)+0.01
 lit=d<14 and (-ex*fx-ey*fy)/d>0.75
 if lit then
  gx=gx-ex/d*0.9 gy=gy-ey/d*0.9
  if #sparks<40 and rnd(1)<0.5 then
   add(sparks,{x=gx+2,y=gy+2,dx=rnd(2)-1,dy=rnd(2)-1,n=8,c=7})
  end
 else
  local sp=0.3+min(score,20)*0.02
  gx=gx+ex/d*sp gy=gy+ey/d*sp
 end
 gx=mid(0,gx,27) gy=mid(7,gy,27)
 if not lit and d<3.5 then
  lives=lives-1 shake=6 flash=6
  gx=px<14 and 26 or 1
  gy=py<16 and 26 or 8
  if lives<=0 then over=true wait=0 end
 end
 if abs(px-cx)<3 and abs(py-cy)<3 then
  score=score+1
  for i=1,6 do
   if #sparks<40 then add(sparks,{x=cx+1,y=cy+1,dx=rnd(3)-1.5,dy=rnd(3)-1.5,n=10,c=rnd({10,14,9})}) end
  end
  newcandy()
 end
 for s in all(sparks) do
  s.x=s.x+s.dx s.y=s.y+s.dy s.n=s.n-1
  if s.n<=0 then del(sparks,s) end
 end
 if shake>0 then shake=shake-1 end
 if flash>0 then flash=flash-1 end
end
function _draw()
 cls(0)
 if over then
  print("SCORE",6,8,9)
  print(score,16-#tostring(score)*2,16,hsv(time(),1,1))
  return
 end
 if shake>0 then camera(rnd(3)-1,rnd(3)-1) end
 for y=6,31 do
  for x=0,31 do
   local dx,dy=x-px-1,y-py-1
   local d=dx*dx+dy*dy
   if d<196 and d>0 and (dx*fx+dy*fy)/sqrt(d)>0.82 then
    pset(x,y,d<49 and 5 or 1)
   end
  end
 end
 rectfill(cx,cy,cx+1,cy+1,10)
 if t%12<6 then pset(cx,cy,7) end
 if lit then
  spr(gh,gx,gy)
 else
  rectfill(gx+1,gy+1,gx+1,gy+2,8)
  rectfill(gx+3,gy+1,gx+3,gy+2,8)
 end
 for s in all(sparks) do pset(s.x,s.y,s.c) end
 rectfill(px,py,px+2,py+2,12)
 pset(px+1,py+1,7)
 pset(px+1+fx*2,py+1+fy*2,10)
 camera()
 if flash>0 then rect(0,0,31,31,8) end
 print(score,1,1,7)
 for i=1,lives do rectfill(32-i*3,1,33-i*3,2,8) end
end
