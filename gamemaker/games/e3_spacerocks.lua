-- space rocks
local ship={"..7..",".ccc.","ccccc","c.c.c"}
local rocks,bullets,sparks,stars,px,lives,score,over,wait,shake,spawnT
local rockcols={6,9,15}

function boom(x,y,c)
 for i=1,6 do
  if #sparks<24 then
   add(sparks,{x=x,y=y,dx=rnd(2)-1,dy=rnd(2)-1,n=10,c=c})
  end
 end
end

function _init()
 rocks={} bullets={} sparks={} stars={}
 for i=1,12 do add(stars,{x=rnd(32),y=rnd(26)}) end
 px=14 lives=3 score=0 over=false wait=0 shake=0 spawnT=0
end

function _update()
 for _,s in all(sparks) do
  s.x=s.x+s.dx
  s.y=s.y+s.dy
  s.n=s.n-1
  if s.n<=0 then del(sparks,s) end
 end
 if shake>0 then shake=shake-1 end
 if over then
  wait=wait+1
  if wait>25 and (btnp(4) or btnp(5)) then _init() end
  return
 end
 if btn(0) then px=mid(0,px-1.5,27) end
 if btn(1) then px=mid(0,px+1.5,27) end
 if (btnp(4) or btnp(5) or btnp(2)) and #bullets<6 then
  add(bullets,{x=px+2,y=26})
 end
 spawnT=spawnT+1
 if spawnT>max(12,40-score*0.8) and #rocks<8 then
  spawnT=0
  add(rocks,{x=rnd(30)+1,y=-4,r=flr(rnd(2))+2,dy=0.5+rnd(0.5)+min(score*0.03,1),dx=rnd(1)-0.5,c=rnd(rockcols)})
 end
 for _,b in all(bullets) do
  b.y=b.y-3
  if b.y<0 then del(bullets,b) end
 end
 for _,r in all(rocks) do
  r.y=r.y+r.dy
  r.x=r.x+r.dx
  if r.x<2 or r.x>29 then r.dx=-r.dx end
  local gone=false
  for _,b in all(bullets) do
   if not gone and abs(b.x-r.x)<r.r+1 and abs(b.y-r.y)<r.r+1 then
    del(bullets,b)
    gone=true
    score=score+1
    boom(r.x,r.y,r.c)
   end
  end
  if not gone and r.y>22 and r.y<31 and abs(r.x-px-2)<r.r+2 then
   gone=true
   lives=lives-1
   shake=8
   boom(r.x,r.y,8)
   if lives<=0 then over=true wait=0 end
  end
  if gone or r.y>33 then del(rocks,r) end
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
 for _,s in ipairs(stars) do pset(s.x,s.y,5) end
 for _,r in ipairs(rocks) do circfill(r.x,r.y,r.r,r.c) end
 for _,b in ipairs(bullets) do line(b.x,b.y,b.x,b.y+2,10) end
 spr(ship,px,27)
 for s in all(sparks) do pset(s.x,s.y,s.c) end
 camera()
 rectfill(0,0,15,5,0)
 print(score,1,1,7)
 for i=1,lives do pset(32-i*2,1,8) end
end
