-- shark eats fish
local fish,sparks,sx,sy,facing,dash,lives,score,over,wait,shake,inv

function touching(f)
 local nx=mid(f.x,sx,f.x+f.w-1)
 local ny=mid(f.y,sy,f.y+f.h-1)
 local dx,dy=sx-nx,sy-ny
 local r=3+min(flr(score/5),2)
 return dx*dx+dy*dy<r*r
end

function spawnfish()
 local dir=1
 if rnd(1)<0.5 then dir=-1 end
 local big=rnd(1)<min(0.1+score*0.01,0.3)
 local f={dx=dir*(0.5+rnd(0.7)),big=big,y=8+flr(rnd(22))}
 if big then
  f.w=7 f.h=5 f.c=9
 else
  f.w=3 f.h=3 f.c=rnd({10,11,14})
 end
 f.x=dir>0 and -f.w or 32
 add(fish,f)
end

function bub(x,y,c)
 for i=1,6 do
  if #sparks<30 then
   add(sparks,{x=x+rnd(4)-2,y=y+rnd(4)-2,dx=0,dy=-0.4-rnd(0.6),n=18,c=c})
  end
 end
end

function _init()
 fish={} sparks={}
 sx=16 sy=18 facing=1 dash=0
 lives=3 score=0 over=false wait=0 shake=0 inv=0
end

function _update()
 for _,s in all(sparks) do
  s.x=s.x+s.dx
  s.y=s.y+s.dy
  s.n=s.n-1
  if s.n<=0 then del(sparks,s) end
 end
 if shake>0 then shake=shake-1 end
 if inv>0 then inv=inv-1 end
 if over then
  wait=wait+1
  if wait>25 and (btnp(4) or btnp(5)) then _init() end
  return
 end
 local r=3+min(flr(score/5),2)
 if btnp(4) or btnp(5) then dash=12 end
 local spd=1.5
 if dash>0 then
  spd=3
  dash=dash-1
 end
 if btn(0) then sx=sx-spd facing=-1 end
 if btn(1) then sx=sx+spd facing=1 end
 if btn(2) then sy=sy-spd end
 if btn(3) then sy=sy+spd end
 sx=mid(r,sx,31-r)
 sy=mid(8+r,sy,31-r)
 if #fish<10 and rnd(1)<0.04+score*0.002 then spawnfish() end
 for _,f in all(fish) do
  f.x=f.x+f.dx
  if (f.dx>0 and f.x>33) or (f.dx<0 and f.x<-9) then
   del(fish,f)
  elseif touching(f) then
   if f.big then
    if inv<=0 then
     lives=lives-1
     inv=40
     shake=8
     bub(sx,sy,8)
     if lives<=0 then over=true wait=0 end
    end
   else
    del(fish,f)
    score=score+1
    bub(sx,sy,12)
   end
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
 for _,f in ipairs(fish) do
  rectfill(f.x,f.y,f.x+f.w-1,f.y+f.h-1,f.c)
  local ex=f.x+1
  if f.dx>0 then ex=f.x+f.w-2 end
  pset(ex,f.y+1,0)
 end
 local r=3+min(flr(score/5),2)
 if inv<=0 or inv%6<3 then
  line(sx-facing*r,sy,sx-facing*(r+3),sy-2,12)
  line(sx-facing*r,sy,sx-facing*(r+3),sy+2,12)
  circfill(sx,sy,r,12)
  circfill(sx,sy+1,r-1,7)
  line(sx,sy-r,sx-facing,sy-r-2,12)
  pset(sx+facing*(r-1),sy-1,0)
 end
 for s in all(sparks) do pset(s.x,s.y,s.c) end
 camera()
 rectfill(0,0,15,5,0)
 print(score,1,1,7)
 for i=1,lives do pset(32-i*2,1,8) end
end
