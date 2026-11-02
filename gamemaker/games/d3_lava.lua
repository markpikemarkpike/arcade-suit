-- lava climb
local kid={"..b..","99999","9a9a9","99999",".999."}
local px,py,vy,camy,lv,plats,sparks,score,lives,over,wait,shake,inv,cy,jb,t
local function addp()
 local top=plats[#plats]
 local w=max(8,13-flr(score/20))
 add(plats,{x=flr(rnd(33-w)),y=top.y-8-flr(rnd(3))-min(2,flr(score/50)),w=w})
end
function _init()
 px=13 py=23 vy=0 camy=0 lv=46 plats={{x=0,y=28,w=32}} sparks={}
 score=0 lives=3 over=false wait=0 shake=0 inv=0 cy=0 jb=0 t=0
 for i=1,5 do addp() end
end
function _update()
 if over then
  wait=wait+1
  if wait>25 and (btnp(4) or btnp(5)) then _init() end
  return
 end
 t=t+1
 if btn(0) then px=px-1.3 end
 if btn(1) then px=px+1.3 end
 if px<-4 then px=31 elseif px>31 then px=-4 end
 if btnp(4) or btnp(5) or btnp(2) then jb=6 end
 if jb>0 then jb=jb-1 end
 if cy>0 then cy=cy-1 end
 if jb>0 and cy>0 then
  vy=-2.5 jb=0 cy=0
  for i=1,3 do
   if #sparks<20 then add(sparks,{x=px+2,y=py+5,dx=rnd(2)-1,dy=rnd(1),n=8,c=rnd({9,10,6})}) end
  end
 end
 local ob=py+5
 vy=min(vy+0.2,3)
 py=py+vy
 if vy>=0 then
  for p in all(plats) do
   if px+4>=p.x and px<=p.x+p.w-1 and ob<=p.y+1 and py+5>=p.y then
    py=p.y-5 vy=0 cy=5
   end
  end
 end
 score=max(score,flr((23-py)/2))
 local tg=py-14
 if tg<camy then camy=camy+(tg-camy)*0.25 end
 lv=lv-(0.1+min(0.2,score*0.0015))
 lv=min(lv,camy+45)
 if inv>0 then inv=inv-1 end
 if py+5>lv and inv==0 then
  lives=lives-1 shake=8 vy=-3 inv=50 lv=lv+14
  for i=1,6 do
   if #sparks<20 then add(sparks,{x=px+2,y=py+5,dx=rnd(3)-1.5,dy=-rnd(2),n=10,c=rnd({8,9,10})}) end
  end
  if lives<=0 then over=true wait=0 end
 end
 local top=plats[#plats]
 if top.y>camy-6 then addp() end
 for p in all(plats) do
  if p.y-camy>36 then del(plats,p) end
 end
 for s in all(sparks) do
  s.x=s.x+s.dx s.y=s.y+s.dy s.dy=s.dy+0.1 s.n=s.n-1
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
 for p in all(plats) do
  local y=p.y-camy
  rectfill(p.x,y,p.x+p.w-1,y,6)
  rectfill(p.x,y+1,p.x+p.w-1,y+1,5)
 end
 for s in all(sparks) do pset(s.x,s.y-camy,s.c) end
 if inv==0 or t%4<2 then
  spr(kid,px,py-camy)
  if px<0 then spr(kid,px+32,py-camy) elseif px>27 then spr(kid,px-32,py-camy) end
 end
 local ly=lv-camy
 if ly<32 then
  rectfill(0,ly,31,31,8)
  rectfill(0,ly,31,ly+1,9)
  for x=1,31,5 do pset(x,ly-1-(time()*5+x)%3,10) end
 end
 camera()
 rectfill(0,0,#tostring(score)*4,5,0)
 print(score,1,1,7)
 for i=1,lives do rectfill(32-i*3,1,33-i*3,2,10) end
 if score==0 and t<75 and t%20<14 then print("A=JUMP",4,12,10) end
end
