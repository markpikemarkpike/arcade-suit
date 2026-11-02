-- pumpkin paddles
local py,cy,bx,by,bvx,bvy,spd,ps,cs,over,wait,pause,flp,flc,aoff,sp,shake
local function burst(x,y,n)
 for i=1,n do add(sp,{x=x,y=y,dx=rnd(3)-1.5,dy=rnd(3)-1.5,n=10,c=hsv(rnd(1),1,1)}) end
end
local function serve()
 bx=14 by=17 spd=0.9 bvx=spd bvy=rnd(1.2)-0.6 pause=25
end
function _init()
 py=14 cy=14 ps=0 cs=0 over=false wait=0 aoff=0 sp={} shake=0 flp=0 flc=0
 serve()
end
function _update()
 if over then
  wait=wait+1
  if wait>25 and (btnp(4) or btnp(5)) then _init() end
  return
 end
 if btn(2) then py=py-1.6 end
 if btn(3) then py=py+1.6 end
 py=mid(7,py,24)
 local tgt=15
 if bvx>0 then tgt=by-2.5+aoff end
 local ai=min(0.9,0.45+ps*0.07)
 if cy<tgt-1 then cy=cy+ai elseif cy>tgt+1 then cy=cy-ai end
 cy=mid(7,cy,24)
 if pause>0 then
  pause=pause-1
 else
  bx=bx+bvx by=by+bvy
  if by<7 then by=7 bvy=abs(bvy) elseif by>29 then by=29 bvy=-abs(bvy) end
  if bvx<0 and bx<=4 and bx>=-1 and by+2>=py-1 and by<=py+8 then
   bx=4 spd=min(2,spd+0.07) bvx=spd bvy=mid(-1.4,(by-py-2.5)*0.22,1.4)
   flp=6 aoff=rnd(8)-4 burst(5,by+1,4)
  end
  if bvx>0 and bx+2>=28 and bx<=30 and by+2>=cy-1 and by<=cy+8 then
   bx=25 spd=min(2,spd+0.07) bvx=-spd bvy=mid(-1.4,(by-cy-2.5)*0.22,1.4)
   flc=6 burst(27,by+1,4)
  end
  if bx<-3 then
   cs=cs+1 shake=8 serve()
  elseif bx>31 then
   ps=ps+1 burst(28,by+1,10) serve()
  end
  if ps>=5 or cs>=5 then over=true wait=0 end
 end
 for s in all(sp) do
  s.x=s.x+s.dx s.y=s.y+s.dy s.n=s.n-1
  if s.n<=0 then del(sp,s) end
 end
 if flp>0 then flp=flp-1 end
 if flc>0 then flc=flc-1 end
 if shake>0 then shake=shake-1 end
end
function _draw()
 cls(0)
 if over then
  if ps>cs then print("YOU WIN!",0,8,hsv(time(),1,1)) else print("OH NO!",4,8,8) end
  local s=ps.."-"..cs
  print(s,16-#s*2,16,9)
  return
 end
 if shake>0 then camera(rnd(3)-1,rnd(3)-1) end
 line(0,6,31,6,1)
 for y=8,30,4 do
  pset(15,y,5) pset(16,y,5)
 end
 rectfill(1,py,3,py+7,flp>0 and 7 or 13)
 rectfill(28,cy,30,cy+7,flc>0 and 7 or 11)
 if pause<=0 or flr(time()*8)%2==0 then
  rectfill(bx,by,bx+2,by+2,9)
  pset(bx+1,by+1,10)
 end
 for s in all(sp) do pset(s.x,s.y,s.c) end
 camera()
 print(ps,1,1,7)
 print(cs,28,1,11)
end
