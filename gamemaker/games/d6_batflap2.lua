-- bat flap
local up={{1,0,0,0,1},{1,1,0,1,1},{1,2,1,2,1},{0,1,1,1,0}}
local dn={{0,1,1,1,0},{1,2,1,2,1},{1,1,0,1,1},{1,0,0,0,1}}
local bx=6
local by,vy,score,passed,lives,over,wait,pipes,candies,sparks,shake,inv,started,t,popx,popy,popt
local function newpipe(x)
 local gap=max(9,13-flr(passed/5))
 add(pipes,{x=x,g=8+flr(rnd(31-gap-10)),gap=gap,done=false})
 if rnd(1)<0.7 and #candies<4 then
  add(candies,{x=x+11,y=8+flr(rnd(16)),c=rnd({8,14,10,9,12})})
 end
end
function _init()
 by=14 vy=0 score=0 passed=0 lives=3 over=false wait=0 pipes={} candies={} sparks={}
 shake=0 inv=0 started=false t=0 popt=0 popx=0 popy=0
 newpipe(32)
end
function _update()
 if over then
  wait=wait+1
  if wait>25 and (btnp(4) or btnp(5)) then _init() end
  return
 end
 t=t+1
 local flap=btnp(4) or btnp(5) or btnp(2)
 if not started then
  by=14+sin(t*0.15)*2
  if flap then started=true vy=-1.6 end
  return
 end
 if flap then
  vy=-1.6
  if #sparks<24 then
   for i=1,3 do
    add(sparks,{x=bx+2,y=by+3,dx=-rnd(1),dy=rnd(1),n=10,c=hsv(t*0.05+i*0.1,1,1)})
   end
  end
 end
 vy=min(vy+0.15,2)
 by=by+vy
 if by<0 then by=0 vy=0 end
 local sp=min(1,0.6+passed*0.01)
 if inv>0 then inv=inv-1 end
 local hit=false
 if by>28 then
  by=28 vy=-1.2
  if inv==0 then hit=true end
 end
 for p in all(pipes) do
  p.x=p.x-sp
  if inv==0 and p.x<bx+4 and p.x+4>bx and (by+1<p.g or by+3>p.g+p.gap) then hit=true end
  if not p.done and p.x+4<bx then
   p.done=true score=score+1 passed=passed+1
   for i=1,4 do
    if #sparks<24 then add(sparks,{x=bx+2,y=by+1,dx=rnd(2)-1,dy=rnd(2)-1,n=8,c=10}) end
   end
  end
  if p.x<-6 then del(pipes,p) end
 end
 for c in all(candies) do
  c.x=c.x-sp
  if c.x+2>bx-1 and c.x<bx+6 and c.y+2>by-1 and c.y<by+5 then
   del(candies,c)
   score=score+5 popx=min(bx,22) popy=by popt=20
   for i=1,6 do
    if #sparks<24 then add(sparks,{x=c.x+1,y=c.y+1,dx=rnd(3)-1.5,dy=rnd(3)-1.5,n=10,c=c.c}) end
   end
  elseif c.x<-5 then
   del(candies,c)
  end
 end
 local last=pipes[#pipes]
 if not last or last.x<10 then newpipe(32) end
 if hit then
  lives=lives-1 shake=8 inv=50 vy=0
  local n=nil
  for p in all(pipes) do
   if p.x+4>=bx and not n then n=p end
  end
  if n then by=n.g+n.gap/2-2 else by=14 end
  if lives<=0 then over=true wait=0 end
 end
 for s in all(sparks) do
  s.x=s.x+s.dx s.y=s.y+s.dy s.n=s.n-1
  if s.n<=0 then del(sparks,s) end
 end
 if popt>0 then popt=popt-1 popy=popy-0.5 end
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
 for p in all(pipes) do
  rectfill(p.x,0,p.x+4,p.g-1,3)
  rectfill(p.x-1,p.g-3,p.x+5,p.g-1,11)
  rectfill(p.x,p.g+p.gap,p.x+4,31,3)
  rectfill(p.x-1,p.g+p.gap,p.x+5,p.g+p.gap+2,11)
 end
 for c in all(candies) do
  rectfill(c.x,c.y,c.x+2,c.y+2,c.c)
  pset(c.x-1,c.y+1,c.c) pset(c.x+3,c.y+1,c.c)
  if t%8<4 then pset(c.x+1,c.y+1,7) end
 end
 for s in all(sparks) do pset(s.x,s.y,s.c) end
 if inv==0 or t%4<2 then
  local f=dn
  if vy<0 then f=up end
  for j=1,4 do
   local r=f[j]
   for i=1,5 do
    local v=r[i]
    if v==1 then
     pset(bx+i-1,by+j-1,hsv(t*0.04+(i+j)*0.12,1,1))
    elseif v==2 then
     pset(bx+i-1,by+j-1,7)
    end
   end
  end
 end
 camera()
 rectfill(0,0,#tostring(score)*4,5,0)
 print(score,1,1,7)
 for i=1,lives do rectfill(32-i*3,1,33-i*3,2,8) end
 if popt>0 then print("+5",popx,popy,10) end
 if not started and t%20<12 then print("PRESS A",2,22,9) end
end
