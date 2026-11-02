-- rainbow snake
local sn,dx,dy,ndx,ndy,ap,score,over,wait,tick,sp
local function place()
 for i=1,30 do
  local x,y=flr(rnd(16)),flr(rnd(12))
  local ok=true
  for s in all(sn) do
   if s.x==x and s.y==y then ok=false end
  end
  if ok then
   ap={x=x,y=y}
   return
  end
 end
 ap={x=flr(rnd(16)),y=flr(rnd(12))}
end
function _init()
 sn={{x=8,y=6},{x=7,y=6},{x=6,y=6},{x=5,y=6}}
 dx=1 dy=0 ndx=1 ndy=0 score=0 over=false wait=0 tick=0 sp={}
 place()
end
function _update()
 if over then
  wait=wait+1
  if wait>25 and (btnp(4) or btnp(5)) then _init() end
  return
 end
 if btn(0) and dx==0 then ndx=-1 ndy=0 end
 if btn(1) and dx==0 then ndx=1 ndy=0 end
 if btn(2) and dy==0 then ndx=0 ndy=-1 end
 if btn(3) and dy==0 then ndx=0 ndy=1 end
 tick=tick+1
 if tick>=max(3,7-flr(score/4)) then
  tick=0
  dx=ndx dy=ndy
  local hx=(sn[1].x+dx)%16
  local hy=(sn[1].y+dy)%12
  for i=1,#sn-1 do
   if sn[i].x==hx and sn[i].y==hy then over=true wait=0 end
  end
  if not over then
   table.insert(sn,1,{x=hx,y=hy})
   if hx==ap.x and hy==ap.y then
    score=score+1
    for i=1,8 do add(sp,{x=hx*2+1,y=8+hy*2,dx=rnd(3)-1.5,dy=rnd(3)-1.5,n=10,c=hsv(rnd(1),1,1)}) end
    place()
   else
    deli(sn,#sn)
   end
  end
 end
 for s in all(sp) do
  s.x=s.x+s.dx s.y=s.y+s.dy s.n=s.n-1
  if s.n<=0 then del(sp,s) end
 end
end
function _draw()
 cls(0)
 if over then
  print("SCORE",6,8,9)
  print(score,16-#tostring(score)*2,16,hsv(time(),1,1))
  return
 end
 line(0,6,31,6,1)
 rectfill(ap.x*2,7+ap.y*2,ap.x*2+1,8+ap.y*2,flr(time()*6)%2==0 and 8 or 10)
 for i=1,#sn do
  local s=sn[i]
  rectfill(s.x*2,7+s.y*2,s.x*2+1,8+s.y*2,hsv((time()*0.6-i*0.05)%1,1,1))
 end
 pset(sn[1].x*2+max(dx,0),7+sn[1].y*2,7)
 for s in all(sp) do pset(s.x,s.y,s.c) end
 print(score,1,1,7)
end
