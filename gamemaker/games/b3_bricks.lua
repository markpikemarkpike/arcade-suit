-- brick smash
local rc={8,9,10,11,12}
local pw=9
local b,px,bx,by,vx,vy,score,lives,over,wait,sparks,shake,held,hold,broken
local function reset_bricks()
 b={} broken=0
 for i=1,25 do b[i]=rc[flr((i-1)/5)+1] end
end
local function brk(x,y)
 local c=flr((x-1)/6)
 local r=flr((y-9)/3)
 if c<0 or c>4 or r<0 or r>4 then return false end
 local i=r*5+c+1
 if b[i]==0 then return false end
 if #sparks<40 then
  for k=1,4 do
   add(sparks,{x=2+c*6,y=10+r*3,dx=rnd(2)-1,dy=rnd(2)-1,n=10,c=b[i]})
  end
 end
 b[i]=0 score=score+1 broken=broken+1
 return true
end
local function speed()
 return min(1.5,0.85+score*0.008)
end
function _init()
 px=11 score=0 lives=3 over=false wait=0 sparks={} shake=0
 held=true hold=0 bx=15 by=27 vx=0 vy=0
 reset_bricks()
end
function _update()
 if over then
  wait=wait+1
  if wait>25 and (btnp(4) or btnp(5)) then _init() end
  return
 end
 if btn(0) then px=px-2 end
 if btn(1) then px=px+2 end
 px=mid(0,px,32-pw)
 if held then
  bx=px+pw/2 by=27 hold=hold+1
  if btnp(4) or btnp(5) or btnp(2) or hold>50 then
   held=false
   local s=speed()
   vx=rnd({-0.4,0.4})*s
   vy=-sqrt(s*s-vx*vx)
  end
 else
  for i=1,2 do
   local nx=bx+vx*0.5
   local ny=by+vy*0.5
   if brk(nx+sgn(vx),by) then vx=-vx nx=bx end
   if brk(nx,ny+sgn(vy)) then vy=-vy ny=by end
   bx=nx by=ny
   if bx<2 then bx=2 vx=abs(vx) end
   if bx>29 then bx=29 vx=-abs(vx) end
   if by<8 then by=8 vy=abs(vy) end
   if vy>0 and by>=27.5 and by<=30 and bx>=px-1 and bx<=px+pw then
    local s=speed()
    vx=mid(-0.85,(bx-px-pw/2)/(pw/2)*0.9,0.85)*s
    vy=-sqrt(s*s-vx*vx)
    by=27
   end
  end
  if by>33 then
   lives=lives-1 shake=8 held=true hold=0
   if lives<=0 then over=true wait=0 end
  end
  if broken>=25 then
   reset_bricks() held=true hold=0
  end
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
 for i=1,25 do
  if b[i]>0 then
   local c=(i-1)%5
   local r=flr((i-1)/5)
   rectfill(1+c*6,9+r*3,5+c*6,10+r*3,b[i])
  end
 end
 for s in all(sparks) do pset(s.x,s.y,s.c) end
 rectfill(px,29,px+pw-1,30,hsv(time()*0.3,1,1))
 rectfill(bx-1,by-1,bx+1,by+1,7)
 camera()
 print(score,1,1,7)
 for i=1,lives do rectfill(32-i*3,1,33-i*3,2,8) end
end
