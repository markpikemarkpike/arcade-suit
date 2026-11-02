-- cat fish
local cat={"9.....9","9999999","9b999b9","999e999","9999999",".99999."}
local fish={"..cc.c","c7cccc","..cc.c"}
local function mk(t,a,b)
 local o={}
 for i=1,#t do o[i]=string.gsub(t[i],a,b) end
 return o
end
local fishes={fish,mk(fish,"c","e"),mk(fish,"c","a")}
local px,score,lives,over,wait,drops,sparks,shake,hap
function _init()
 px=12 score=0 lives=3 over=false wait=0 drops={} sparks={} shake=0 hap=0
end
function _update()
 if over then
  wait=wait+1
  if wait>25 and (btnp(4) or btnp(5)) then _init() end
  return
 end
 if btn(0) then px=px-1.5 end
 if btn(1) then px=px+1.5 end
 px=mid(0,px,25)
 if rnd(1)<0.035+score*0.001 and #drops<7 then
  add(drops,{x=flr(rnd(26)),y=6,s=rnd(fishes)})
 end
 local v=min(1.1,0.45+score*0.01)
 for d in all(drops) do
  d.y=d.y+v
  if d.y>=22 and d.y<=28 and d.x+5>=px and d.x<=px+6 then
   score=score+1 hap=8 del(drops,d)
   for i=1,6 do add(sparks,{x=d.x+3,y=d.y,dx=rnd(2)-1,dy=-rnd(1.5),n=10,c=hsv(rnd(1),1,1)}) end
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
 if hap>0 then hap=hap-1 end
end
function _draw()
 cls(0)
 if over then
  print("SCORE",6,8,9)
  print(score,16-#tostring(score)*2,16,hsv(time(),1,1))
  return
 end
 if shake>0 then camera(rnd(3)-1,rnd(3)-1) end
 line(0,31,31,31,12)
 for d in all(drops) do spr(d.s,d.x,d.y) end
 for s in all(sparks) do pset(s.x,s.y,s.c) end
 spr(cat,px,hap>0 and 24 or 25)
 camera()
 print(score,1,1,7)
 for i=1,lives do rectfill(32-i*4,1,33-i*4,2,8) end
end
