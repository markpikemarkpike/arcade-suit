-- penalty kicks
local keeper={"..fff..","9999999","..999..","..999..",".99.99."}
local st,ax,ay,tx,ty,p,bx,by,gx,gt,msg,mt,score,lives,over,wait,sparks,shake,t
function _init()
 st=0 ax=16 ay=12 tx=16 ty=12 p=0 bx=16 by=26 gx=12 gt=15 msg="" mt=0
 score=0 lives=3 over=false wait=0 sparks={} shake=0 t=0
end
function _update()
 if over then
  wait=wait+1
  if wait>25 and (btnp(4) or btnp(5)) then _init() end
  return
 end
 t=t+1
 if st==0 then
  if btn(0) then ax=ax-1.5 end
  if btn(1) then ax=ax+1.5 end
  if btn(2) then ay=ay-1 end
  if btn(3) then ay=ay+1 end
  ax=mid(2,ax,29) ay=mid(7,ay,16)
  if btnp(4) or btnp(5) then
   st=1 p=0 tx=ax+rnd(2)-1 ty=ay+rnd(2)-1
   if rnd(1)<min(0.55,0.2+score*0.03) then gt=tx else gt=6+rnd(20) end
  end
 elseif st==1 then
  p=p+0.07
  bx=16+(tx-16)*p
  by=26+(ty-26)*p-sin(p*3.14)*4
  if p>=1 then
   bx=tx by=ty st=2 mt=40
   if tx<5 or tx>26 or ty<9 or ty>16.5 then
    msg="MISS" lives=lives-1
   elseif abs(gx+3-tx)<=4 then
    msg="SAVE" lives=lives-1 shake=6
   else
    msg="GOAL" score=score+1
    for i=1,14 do
     add(sparks,{x=tx,y=ty,dx=rnd(3)-1.5,dy=rnd(3)-1.5,n=14,c=hsv(i/14,1,1)})
    end
   end
  end
 else
  mt=mt-1
  if mt<=0 then
   if lives<=0 then
    over=true wait=0
   else
    st=0 bx=16 by=26 gt=15
   end
  end
 end
 gx=gx+mid(-1.3,gt-3-gx,1.3)
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
 for x=8,26,3 do line(x,9,x,16,5) end
 for y=10,16,3 do line(5,y,26,y,5) end
 line(4,8,4,17,7) line(27,8,27,17,7) line(4,8,27,8,7)
 line(0,18,31,18,3)
 spr(keeper,gx,11)
 if st==0 then
  circ(ax,ay,2,10)
  pset(ax,ay,10)
 end
 circfill(bx,by,1,7)
 for s in all(sparks) do pset(s.x,s.y,s.c) end
 if st==2 then
  print(msg,0,20,msg=="GOAL" and hsv(time()*2,1,1) or 8,2)
 end
 camera()
 rectfill(0,0,#tostring(score)*4,5,0)
 print(score,1,1,7)
 for i=1,lives do rectfill(32-i*3,1,33-i*3,2,8) end
 if score==0 and lives==3 and st==0 and t%30<20 then print("A=KICK",4,20,9) end
end
