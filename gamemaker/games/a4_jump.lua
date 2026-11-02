-- pumpkin hop
local ghost={".777.","77777","70707","77777","77777","7.7.7"}
local pump={"..33..",".9999.","909909","999999","990099",".9999."}
local gy,vy,score,lives,over,wait,ps,spd,dist,inv,shake,off,sp
function _init()
 gy=22 vy=0 score=0 lives=3 over=false wait=0 ps={} spd=0.9 dist=20 inv=0 shake=0 off=0 sp={}
end
function _update()
 if over then
  wait=wait+1
  if wait>25 and (btnp(4) or btnp(5)) then _init() end
  return
 end
 spd=min(2,0.9+score*0.03)
 if (btnp(4) or btnp(5) or btnp(2)) and gy>=22 then vy=-2.2 end
 vy=vy+0.2
 gy=gy+vy
 if gy>=22 then gy=22 vy=0 end
 off=(off+spd)%32
 dist=dist-spd
 if dist<=0 then
  add(ps,{x=32,s=false})
  dist=22+rnd(14)+spd*14
 end
 if inv>0 then inv=inv-1 end
 for p in all(ps) do
  p.x=p.x-spd
  if not p.s and p.x<0 then
   p.s=true
   score=score+1
   for i=1,4 do add(sp,{x=8,y=gy+2,dx=rnd(2)-1,dy=-rnd(1.5),n=10,c=10}) end
  end
  if p.x<-6 then
   del(ps,p)
  elseif inv<=0 and p.x+4>=7 and p.x+1<=9 and gy+5>=23 then
   del(ps,p)
   lives=lives-1 inv=40 shake=6
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
 circfill(26,12,3,10)
 circfill(27,11,2,0)
 rectfill(0,28,31,31,3)
 line(0,28,31,28,11)
 for i=0,3 do pset((i*8-off)%32,30,11) end
 for p in all(ps) do spr(pump,p.x,22) end
 if inv<=0 or flr(inv/3)%2==0 then spr(ghost,6,gy) end
 for s in all(sp) do pset(s.x,s.y,s.c) end
 camera()
 print(score,1,1,7)
 for i=1,lives do rectfill(32-i*4,1,33-i*4,2,8) end
end
