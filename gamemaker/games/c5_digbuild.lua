-- dig and build
local W={}
local NX,NY=40,6
local oy=7
local cols={11,4,6,12}
local px,py,vy,face,mt,held,score,cam
local cnt={0,6,0,0}
local stars={}
local sp={}
function gen()
 for x=1,NX do
  W[x]={}
  local g=mid(2,flr(3.5+sin(x*0.4)*1.3+sin(x*0.17)),4)
  for y=1,NY do
   local t=0
   if y==g then t=1 elseif y>g and y<=g+2 then t=2 elseif y>g+2 then t=3 end
   if t==3 and (x*7+y*13)%11==0 then t=4 end
   W[x][y]=t
  end
 end
end
function tileAt(x,y)
 local tx=flr(x/4)+1
 local ty=flr((y-oy)/4)+1
 if tx<1 or tx>NX or ty<1 or ty>NY then return 9 end
 return W[tx][ty]
end
function setTile(x,y,v)
 W[flr(x/4)+1][flr((y-oy)/4)+1]=v
end
function blocked(x,y)
 return tileAt(x,y)~=0 or tileAt(x+2,y)~=0 or tileAt(x,y+2)~=0 or tileAt(x+2,y+2)~=0
end
function inbox(x,y)
 local ox=flr(x/4)*4
 local oyy=oy+flr((y-oy)/4)*4
 return ox<=px+2 and ox+3>=px and oyy<=py+2 and oyy+3>=py
end
function burst(x,y,c)
 for i=1,4 do
  if #sp<40 then add(sp,{x=x,y=y,dx=rnd(2)-1,dy=rnd(2)-1.5,n=10,c=c}) end
 end
end
function _init()
 gen()
 px=76 py=7 vy=0 face=1 mt=0 held=2 score=0 cam=62
 cnt={0,6,0,0} sp={} stars={}
 for i=1,8 do stars[i]={x=flr(rnd(32)),y=flr(rnd(6))} end
end
function _update()
 local dx=0
 if btn(0) then dx=-1 face=-1 end
 if btn(1) then dx=1 face=1 end
 if dx~=0 and not blocked(px+dx,py) then px=px+dx end
 if btnp(2) and blocked(px,py+1) then vy=-2.6 end
 vy=min(vy+0.25,3)
 local n=flr(vy+0.5)
 local s=1
 if n<0 then s=-1 end
 for i=1,abs(n) do
  if blocked(px,py+s) then vy=0 break end
  py=py+s
 end
 if mt>0 then mt=mt-1 end
 local bx=px+1+face*3
 local by=py+1
 if btn(3) then bx=px+1 by=py+4 end
 if btn(4) and mt<=0 then
  local t=tileAt(bx,by)
  if t>0 and t<9 then
   setTile(bx,by,0)
   cnt[t]=cnt[t]+1
   held=t score=score+1 mt=6
   burst(bx,by,cols[t])
  end
 end
 if btnp(5) and cnt[held]>0 and tileAt(bx,by)==0 and not inbox(bx,by) then
  setTile(bx,by,held)
  cnt[held]=cnt[held]-1
 end
 for p in all(sp) do
  p.x=p.x+p.dx p.y=p.y+p.dy p.dy=p.dy+0.15 p.n=p.n-1
  if p.n<=0 then del(sp,p) end
 end
 cam=mid(0,px-14,128)
end
function _draw()
 cls(0)
 for i=1,#stars do pset(stars[i].x,stars[i].y,5) end
 local c0=flr(cam)
 for x=1,NX do
  local sx=(x-1)*4-c0
  if sx>-4 and sx<32 then
   local col=W[x]
   for y=1,NY do
    local t=col[y]
    if t>0 then
     local sy=oy+(y-1)*4
     rectfill(sx,sy,sx+3,sy+3,cols[t])
    end
   end
  end
 end
 for i=1,#sp do pset(sp[i].x-c0,sp[i].y,sp[i].c) end
 local qx=flr(px-c0)
 local qy=flr(py)
 rectfill(qx,qy,qx+2,qy+2,15)
 pset(qx+1+face,qy,0)
 print(score,1,1,7)
 print(cnt[held],14,1,7)
 rectfill(28,1,31,4,cols[held])
end
