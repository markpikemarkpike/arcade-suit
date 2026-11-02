-- tower defense skeletons
local skel={".777.","70.07",".777.","77777",".7.7.",".7.7."}
local pump={"..b..","99999","99999","99999",".999."}
local wp={{-2,10},{26,10},{26,22},{4,22},{4,28}}
local segs,total,skels,towers,beams,cx,cy,coins,lives,wave,spawning,spawnT,betweenT,over,wait,shake,tk

function onpath(x,y)
 for _,s in ipairs(segs) do
  if s.y1==s.y2 then
   if abs(y-s.y1)<4 and x>=min(s.x1,s.x2)-3 and x<=max(s.x1,s.x2)+3 then return true end
  else
   if abs(x-s.x1)<4 and y>=min(s.y1,s.y2)-3 and y<=max(s.y1,s.y2)+3 then return true end
  end
 end
 return false
end

function at(d)
 for _,s in ipairs(segs) do
  if d<=s.len then
   local f=d/s.len
   return s.x1+(s.x2-s.x1)*f,s.y1+(s.y2-s.y1)*f
  end
  d=d-s.len
 end
 local s=segs[#segs]
 return s.x2,s.y2
end

function spawnskel()
 add(skels,{d=0,hp=1+flr(wave/3),sp=0.25+wave*0.02})
end

function _init()
 segs={} total=0
 for i=1,#wp-1 do
  local a,b=wp[i],wp[i+1]
  local len=abs(b[1]-a[1])+abs(b[2]-a[2])
  add(segs,{x1=a[1],y1=a[2],x2=b[1],y2=b[2],len=len})
  total=total+len
 end
 skels={} towers={} beams={}
 cx=14 cy=16 coins=25 lives=3 wave=1 spawning=6 spawnT=0 betweenT=0
 over=false wait=0 shake=0 tk=0
end

function _update()
 tk=tk+1
 for _,b in all(beams) do
  b.t=b.t-1
  if b.t<=0 then del(beams,b) end
 end
 if shake>0 then shake=shake-1 end
 if over then
  wait=wait+1
  if wait>25 and (btnp(4) or btnp(5)) then _init() end
  return
 end
 if btnp(0) or (btn(0) and tk%3==0) then cx=max(2,cx-2) end
 if btnp(1) or (btn(1) and tk%3==0) then cx=min(28,cx+2) end
 if btnp(2) or (btn(2) and tk%3==0) then cy=max(8,cy-2) end
 if btnp(3) or (btn(3) and tk%3==0) then cy=min(28,cy+2) end
 if (btnp(4) or btnp(5)) and #towers<10 and coins>=10 and not onpath(cx,cy) then
  local ok=true
  for _,t in ipairs(towers) do
   if abs(t.x-cx)<5 and abs(t.y-cy)<5 then ok=false end
  end
  if ok then
   add(towers,{x=cx,y=cy,cool=0})
   coins=coins-10
  end
 end
 if spawning>0 then
  spawnT=spawnT+1
  if spawnT>=max(18,40-wave*2) then
   spawnT=0
   spawning=spawning-1
   spawnskel()
  end
 elseif #skels==0 then
  betweenT=betweenT+1
  if betweenT>=90 then
   betweenT=0
   wave=wave+1
   spawning=4+wave*2
   coins=coins+5
  end
 end
 for _,s in all(skels) do
  s.d=s.d+s.sp
  if s.d>=total then
   del(skels,s)
   lives=lives-1
   shake=8
   if lives<=0 then over=true wait=0 end
  end
 end
 for _,t in ipairs(towers) do
  t.cool=t.cool-1
  if t.cool<=0 then
   local best,bd=nil,101
   for _,s in ipairs(skels) do
    local sx,sy=at(s.d)
    local dd=(sx-t.x)*(sx-t.x)+(sy-t.y)*(sy-t.y)
    if dd<bd then
     best=s
     bd=dd
    end
   end
   if best then
    t.cool=24
    local bx,by=at(best.d)
    add(beams,{x1=t.x,y1=t.y,x2=bx,y2=by,t=4})
    best.hp=best.hp-1
    if best.hp<=0 then
     del(skels,best)
     coins=coins+2
    end
   end
  end
 end
end

function _draw()
 cls(0)
 if over then
  print("WAVE",6,6,9)
  local w=wave-1
  print(w,16-#tostring(w)*4,14,hsv(time()*0.5,1,1),2)
  return
 end
 if shake>0 then camera(rnd(3)-1,rnd(3)-1) end
 for _,s in ipairs(segs) do
  if s.y1==s.y2 then
   rectfill(min(s.x1,s.x2),s.y1-2,max(s.x1,s.x2),s.y1+2,4)
  else
   rectfill(s.x1-2,min(s.y1,s.y2),s.x1+2,max(s.y1,s.y2),4)
  end
 end
 rectfill(1,25,7,31,6)
 rectfill(3,22,5,24,6)
 for _,t in ipairs(towers) do spr(pump,t.x-2,t.y-2) end
 for _,s in ipairs(skels) do
  local x,y=at(s.d)
  spr(skel,x-2,y-3)
 end
 for _,b in ipairs(beams) do line(b.x1,b.y1,b.x2,b.y2,10) end
 local ok=not onpath(cx,cy) and coins>=10 and #towers<10
 rect(cx-3,cy-3,cx+3,cy+3,ok and 11 or 8)
 camera()
 rectfill(0,0,31,5,0)
 print(coins,1,1,10)
 print("W"..wave,14,1,7)
 for i=1,lives do pset(32-i*2,1,8) end
end
