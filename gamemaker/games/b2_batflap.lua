-- bat flap
local up={"d...d","dd.dd","d8d8d",".ddd."}
local dn={".ddd.","d8d8d","dd.dd","d...d"}
local bx=6
local by,vy,score,lives,over,wait,pipes,sparks,shake,inv,started,t
local function newpipe(x)
 local gap=max(9,13-flr(score/5))
 add(pipes,{x=x,g=8+flr(rnd(31-gap-10)),gap=gap,done=false})
end
function _init()
 by=14 vy=0 score=0 lives=3 over=false wait=0 pipes={} sparks={}
 shake=0 inv=0 started=false t=0
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
  if #sparks<30 then
   for i=1,3 do
    add(sparks,{x=bx+2,y=by+3,dx=-rnd(1),dy=rnd(1),n=10,c=hsv(t*0.05+i*0.1,1,1)})
   end
  end
 end
 vy=min(vy+0.15,2)
 by=by+vy
 if by<0 then by=0 vy=0 end
 local sp=min(1,0.6+score*0.01)
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
   p.done=true score=score+1
   for i=1,4 do
    if #sparks<30 then add(sparks,{x=bx+2,y=by+1,dx=rnd(2)-1,dy=rnd(2)-1,n=8,c=10}) end
   end
  end
  if p.x<-6 then del(pipes,p) end
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
 for s in all(sparks) do pset(s.x,s.y,s.c) end
 if inv==0 or t%4<2 then
  spr(vy<0 and up or dn,bx,by)
 end
 camera()
 rectfill(0,0,#tostring(score)*4,5,0)
 print(score,1,1,7)
 for i=1,lives do rectfill(32-i*3,1,33-i*3,2,8) end
 if not started and t%20<12 then print("PRESS A",2,22,9) end
end
