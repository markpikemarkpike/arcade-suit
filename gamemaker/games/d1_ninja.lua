-- ninja stars
local ninja={"88888","c7c7c","ccccc",".ccc.",".c.c.",".c.c."}
local robot={"..a..","66666","68686","66666","66666",".6.6."}
local bossp={"....a....",".ddddddd.","ddddddddd","dd88d88dd","ddddddddd","d7d7d7d7d",".ddddddd.",".d.....d."}
local ny,stars,bots,bullets,sparks,score,lives,over,wait,boss,kills,lvl,shake,cd,inv,t,warn
local function burst(x,y,c,n)
 for i=1,n do
  if #sparks<20 then add(sparks,{x=x,y=y,dx=rnd(3)-1.5,dy=rnd(3)-1.5,n=10,c=c}) end
 end
end
function _init()
 ny=13 stars={} bots={} bullets={} sparks={} score=0 lives=3 over=false wait=0
 boss=nil kills=0 lvl=0 shake=0 cd=0 inv=0 t=0 warn=0
end
function _update()
 if over then
  wait=wait+1
  if wait>25 and (btnp(4) or btnp(5)) then _init() end
  return
 end
 t=t+1
 if btn(2) then ny=ny-1.3 end
 if btn(3) then ny=ny+1.3 end
 ny=mid(7,ny,25)
 if cd>0 then cd=cd-1 end
 if (btnp(4) or btnp(5)) and cd==0 and #stars<6 then
  add(stars,{x=8,y=ny+2}) cd=5
 end
 if inv>0 then inv=inv-1 end
 if warn>0 then warn=warn-1 end
 if not boss and kills>=10 then
  boss={x=22,y=12,dy=0.5+lvl*0.1,hp=10+lvl*3,mx=10+lvl*3,fire=50,fl=0}
  warn=40
 end
 local rate=0.03+lvl*0.005
 if boss then rate=0.012 end
 if rnd(1)<rate and #bots<5 then
  add(bots,{x=32,y=7+flr(rnd(18)),sp=0.3+rnd(0.2)+min(lvl*0.1,0.4)})
 end
 for s in all(stars) do
  s.x=s.x+2.5
  local gone=s.x>32
  for b in all(bots) do
   if not gone and s.x>=b.x-1 and s.x<=b.x+5 and s.y>=b.y-1 and s.y<=b.y+6 then
    del(bots,b) gone=true score=score+1 kills=kills+1
    burst(b.x+2,b.y+3,9,5)
   end
  end
  if not gone and boss and s.x>=boss.x-1 and s.x<=boss.x+9 and s.y>=boss.y-1 and s.y<=boss.y+8 then
   gone=true boss.hp=boss.hp-1 boss.fl=3
   burst(s.x,s.y,10,3)
   if boss.hp<=0 then
    score=score+10
    burst(boss.x+4,boss.y+4,hsv(t*0.1,1,1),16)
    boss=nil kills=0 lvl=lvl+1 shake=10 bullets={}
   end
  end
  if gone then del(stars,s) end
 end
 for b in all(bots) do
  b.x=b.x-b.sp
  if b.x<8 then
   del(bots,b) lives=lives-1 shake=6
   burst(8,b.y+3,8,5)
   if lives<=0 then over=true wait=0 end
  end
 end
 if boss then
  boss.y=boss.y+boss.dy
  if boss.y<7 then boss.dy=abs(boss.dy) elseif boss.y>23 then boss.dy=-abs(boss.dy) end
  if boss.fl>0 then boss.fl=boss.fl-1 end
  boss.fire=boss.fire-1
  if boss.fire<=0 and #bullets<4 then
   add(bullets,{x=boss.x-2,y=boss.y+3})
   boss.fire=max(30,55-lvl*8)
  end
 end
 for u in all(bullets) do
  u.x=u.x-0.8
  if inv==0 and u.x<7 and u.x>0 and u.y>=ny-1 and u.y<=ny+6 then
   del(bullets,u) lives=lives-1 inv=40 shake=6
   burst(4,ny+3,8,5)
   if lives<=0 then over=true wait=0 end
  elseif u.x<-3 then
   del(bullets,u)
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
 for s in all(stars) do
  if t%4<2 then
   pset(s.x,s.y-1,7) pset(s.x,s.y+1,7) pset(s.x-1,s.y,7) pset(s.x+1,s.y,7)
  else
   pset(s.x-1,s.y-1,7) pset(s.x+1,s.y-1,7) pset(s.x-1,s.y+1,7) pset(s.x+1,s.y+1,7)
  end
  pset(s.x,s.y,10)
 end
 for b in all(bots) do spr(robot,b.x,b.y) end
 if boss then
  if boss.fl>0 then
   rectfill(boss.x,boss.y,boss.x+8,boss.y+7,7)
  else
   spr(bossp,boss.x,boss.y)
  end
  rectfill(0,31,flr(31*boss.hp/boss.mx),31,8)
 end
 for u in all(bullets) do
  rectfill(u.x,u.y,u.x+1,u.y+1,8)
  pset(u.x,u.y,10)
 end
 for s in all(sparks) do pset(s.x,s.y,s.c) end
 if inv==0 or t%4<2 then spr(ninja,2,ny) end
 camera()
 rectfill(0,0,#tostring(score)*4,5,0)
 print(score,1,1,7)
 for i=1,lives do rectfill(32-i*3,1,33-i*3,2,8) end
 if warn>0 and t%6<4 then print("BOSS!",6,14,8) end
end
