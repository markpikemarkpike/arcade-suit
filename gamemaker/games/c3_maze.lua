-- key maze chase
local maps={{"########","#k....e#","###.####","#.....k#","#.####.#","#.....k#"},{"########","#k#k...#","#.#.#.##","#...#.k#","#.###.e#","#......#"}}
local W={} local K={} local D={}
local DC={0,0,1,-1} local DR={-1,1,0,0}
local oy=7
local lvl,score,lives,keysLeft,ex,er
local px,py,mx,my,mc,mr,tc,tr,spd
local inv,shake,wait,over,sp
function loadlvl()
 local m=maps[(lvl-1)%2+1]
 keysLeft=0
 for r=1,6 do
  W[r]={} K[r]={} D[r]={}
  for c=1,8 do
   local ch=string.sub(m[r],c,c)
   W[r][c]=0 K[r][c]=0 D[r][c]=99
   if ch=="#" then W[r][c]=1 end
   if ch=="k" then K[r][c]=1 keysLeft=keysLeft+1 end
   if ch=="e" then ex=c er=r end
  end
 end
 px=4 py=oy+20
 mc=6 mr=2 tc=6 tr=2
 mx=20 my=oy+4
 spd=min(0.9,0.3+lvl*0.1)
 inv=0
end
function start()
 lvl=1 score=0 lives=3 over=false wait=0 sp={} shake=0
 loadlvl()
end
function solid(x,y)
 local c=flr(x/4)+1
 local r=flr((y-oy)/4)+1
 if c<1 or c>8 or r<1 or r>6 then return true end
 return W[r][c]==1
end
function blocked(x,y)
 return solid(x,y) or solid(x+2,y) or solid(x,y+2) or solid(x+2,y+2)
end
function bfs()
 local sc=flr((px+1)/4)+1
 local sr=flr((py+1-oy)/4)+1
 local qc={} local qr={}
 for r=1,6 do
  for c=1,8 do D[r][c]=99 end
 end
 D[sr][sc]=0 qc[1]=sc qr[1]=sr
 local h=1 local t=1
 for k=1,48 do
  if h>t then break end
  local c=qc[h] local r=qr[h] h=h+1
  for d=1,4 do
   local nc=c+DC[d] local nr=r+DR[d]
   if nc>=1 and nc<=8 and nr>=1 and nr<=6 and W[nr][nc]==0 and D[nr][nc]==99 then
    D[nr][nc]=D[r][c]+1
    t=t+1 qc[t]=nc qr[t]=nr
   end
  end
 end
end
function _init()
 start()
end
function _update()
 if over then
  wait=wait+1
  if wait>25 and (btnp(4) or btnp(5)) then start() end
  return
 end
 local dx=0 local dy=0
 if btn(0) then dx=-1 end
 if btn(1) then dx=1 end
 if btn(2) then dy=-1 end
 if btn(3) then dy=1 end
 if not blocked(px+dx,py) then px=px+dx end
 if not blocked(px,py+dy) then py=py+dy end
 local pc=flr((px+1)/4)+1
 local pr=flr((py+1-oy)/4)+1
 if K[pr][pc]==1 then
  K[pr][pc]=0 keysLeft=keysLeft-1 score=score+10
  for i=1,6 do add(sp,{x=px+1,y=py+1,dx=rnd(2)-1,dy=rnd(2)-1,n=12}) end
 end
 if keysLeft==0 and pc==ex and pr==er then
  lvl=lvl+1 score=score+50 sp={} loadlvl()
  return
 end
 local tx=(tc-1)*4 local ty=oy+(tr-1)*4
 local ddx=tx-mx local ddy=ty-my
 if abs(ddx)<0.05 and abs(ddy)<0.05 then
  mx=tx my=ty mc=tc mr=tr
  bfs()
  tc=mc tr=mr
  local best=D[mr][mc]
  for d=1,4 do
   local nc=mc+DC[d] local nr=mr+DR[d]
   if nc>=1 and nc<=8 and nr>=1 and nr<=6 and W[nr][nc]==0 and D[nr][nc]<best then
    best=D[nr][nc] tc=nc tr=nr
   end
  end
 else
  mx=mx+mid(-spd,ddx,spd) my=my+mid(-spd,ddy,spd)
 end
 if inv>0 then inv=inv-1 end
 if inv<=0 and abs(px-mx)<2 and abs(py-my)<2 then
  lives=lives-1 shake=6 inv=50
  px=4 py=oy+20 mc=6 mr=2 tc=6 tr=2 mx=20 my=oy+4
  if lives<=0 then over=true wait=0 end
 end
 for s in all(sp) do
  s.x=s.x+s.dx s.y=s.y+s.dy s.n=s.n-1
  if s.n<=0 then del(sp,s) end
 end
 if shake>0 then shake=shake-1 end
end
function _draw()
 cls(0)
 if over then
  print("SCORE",6,8,10)
  local s=tostring(score)
  local x=16-#s*2
  for i=0,1 do
   for j=0,1 do print(s,x+i,15+j,hsv(time()*0.3,1,1)) end
  end
  return
 end
 if shake>0 then camera(flr(rnd(3))-1,flr(rnd(3))-1) end
 for r=1,6 do
  for c=1,8 do
   local x=(c-1)*4 local y=oy+(r-1)*4
   if W[r][c]==1 then
    rectfill(x,y,x+3,y+3,12)
   elseif K[r][c]==1 then
    rectfill(x,y,x+2,y+2,flr(time()*6)%2==0 and 10 or 9)
   elseif r==er and c==ex then
    rectfill(x,y,x+2,y+2,keysLeft==0 and 11 or 5)
   end
  end
 end
 for s in all(sp) do pset(s.x,s.y,10) end
 rectfill(mx,my,mx+2,my+2,8)
 pset(mx,my,7) pset(mx+2,my,7)
 if inv<=0 or flr(time()*10)%2==0 then rectfill(px,py,px+2,py+2,7) end
 camera()
 print(score,1,1,7)
 print(keysLeft,18,1,10)
 for i=1,lives do rectfill(31-i*3,1,32-i*3,2,8) end
end
