-- candy catch
local pumpkin={".3..3.",".9999.","909909","999999","990099",".9999."}
local px,score,lives,over,wait,drops,sparks,shake
function _init()
 px=13 score=0 lives=3 over=false wait=0 drops={} sparks={} shake=0
end
function _update()
 if over then
  wait=wait+1
  if wait>25 and (btnp(4) or btnp(5)) then _init() end
  return
 end
 if btn(0) then px=px-1.5 end
 if btn(1) then px=px+1.5 end
 px=mid(0,px,26)
 if rnd(1)<0.04+score*0.002 and #drops<8 then add(drops,{x=flr(rnd(29)),y=6,c=rnd({8,11,12,14})}) end
 for d in all(drops) do
  d.y=d.y+0.4+score*0.01
  if d.y>=23 and d.y<30 and d.x>px-3 and d.x<px+6 then
   score=score+1 del(drops,d)
   for i=1,5 do add(sparks,{x=d.x+1,y=d.y,dx=rnd(2)-1,dy=-rnd(1.5),n=10,c=d.c}) end
  elseif d.y>31 then
   del(drops,d) lives=lives-1 shake=6
   if lives<=0 then over=true wait=0 end
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
 for d in all(drops) do rectfill(d.x,d.y,d.x+2,d.y+2,d.c) pset(d.x+1,d.y+1,7) end
 for s in all(sparks) do pset(s.x,s.y,s.c) end
 spr(pumpkin,px,26)
 camera()
 print(score,1,1,7)
 for i=1,lives do pset(32-i*2,1,8) end
end
