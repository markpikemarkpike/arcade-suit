-- beating heart
local L={"..XXXX..",".XXXXXX.","XXXXXXXX","XXXXXXXX","XXXXXXXX",".XXXXXXX","..XXXXXX","...XXXXX","....XXXX",".....XXX","......XX",".......X"}
local H={}
local parts={}
local hide=0
local grow=30
local shake=0
local rb=false
function _init()
 for r=1,12 do
  local row=L[r]..string.reverse(L[r])
  H[r]={}
  for c=1,16 do
   local ch=string.sub(row,c,c)
   if ch=="X" then H[r][c]=8 else H[r][c]=0 end
  end
 end
 H[3][4]=14 H[3][5]=14 H[4][4]=14
 parts={} hide=0 grow=30 shake=0
end
function explode()
 hide=100 shake=8 parts={}
 for r=1,12 do
  for c=1,16 do
   if H[r][c]>0 and (r*c)%3==0 then
    local x=16+(c-8.5)*2
    local y=16+(r-6.5)*2
    add(parts,{x=x,y=y,dx=(x-16)*0.1+rnd(0.8)-0.4,dy=(y-16)*0.1+rnd(0.8)-0.4,n=30+flr(rnd(20)),c=rnd({7,10,14,12,11,8})})
   end
  end
 end
 for i=1,20 do
  local a=rnd(6.283)
  local spd=0.5+rnd(1.2)
  add(parts,{x=16,y=16,dx=cos(a)*spd,dy=sin(a)*spd,n=30+flr(rnd(20)),c=rnd({7,10,14,12,11})})
 end
end
function _update()
 if btnp(5) then rb=not rb end
 if btnp(4) and hide==0 and grow>=30 then explode() end
 if hide>0 then
  hide=hide-1
  if hide==0 then grow=0 end
 elseif grow<30 then
  grow=grow+1
 end
 for p in all(parts) do
  p.x=p.x+p.dx p.y=p.y+p.dy
  p.dx=p.dx*0.98 p.dy=p.dy+0.03
  p.n=p.n-1
  if p.n<=0 then del(parts,p) end
 end
 if shake>0 then shake=shake-1 end
end
function _draw()
 cls(0)
 if shake>0 then camera(flr(rnd(3))-1,flr(rnd(3))-1) end
 if hide==0 then
  local b=0.5+0.5*sin(time()*7)
  b=b*b
  local g=min(1,grow/30)
  local s=(1.8+0.2*b)*max(0.1,g)
  for r=1,12 do
   for c=1,16 do
    local v=H[r][c]
    if v>0 then
     local col=v
     if rb then col=hsv(time()*0.3+c/24,1,1) end
     local x0=16-8*s+(c-1)*s
     local y0=16-6*s+(r-1)*s
     local xl=flr(x0+0.5)
     local yt=flr(y0+0.5)
     local xr=flr(x0+s+0.5)-1
     local yb=flr(y0+s+0.5)-1
     if xr<xl then xr=xl end
     if yb<yt then yb=yt end
     rectfill(xl,yt,xr,yb,col)
    end
   end
  end
 end
 for p in all(parts) do
  local x=flr(p.x) local y=flr(p.y)
  pset(x,y,p.c)
  if p.n%4<2 then
   pset(x-1,y,p.c) pset(x+1,y,p.c) pset(x,y-1,p.c) pset(x,y+1,p.c)
  end
 end
 camera()
end
