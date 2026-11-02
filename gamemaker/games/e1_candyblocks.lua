-- candy blocks
local shapes={
 {{0,0},{1,0},{2,0},{3,0}},
 {{0,0},{1,0},{0,1},{1,1}},
 {{0,0},{1,0},{2,0},{1,1}},
 {{0,0},{1,0},{1,1},{2,1}},
 {{1,0},{2,0},{0,1},{1,1}},
 {{0,0},{0,1},{1,1},{2,1}},
 {{2,0},{0,1},{1,1},{2,1}}
}
local cols={8,9,10,11,12,13,14}
local W,H=10,12
local OX,OY=6,7
local board,shape,cur,nk,px,py
local score,over,wait,timer,sparks,tk

function emptyrow()
 local r={}
 for x=0,W-1 do r[x]=0 end
 return r
end

function fits(s,ax,ay)
 for _,c in ipairs(s) do
  local x,y=ax+c[1],ay+c[2]
  if x<0 or x>=W or y>=H then return false end
  if y>=0 and board[y][x]>0 then return false end
 end
 return true
end

function rot(s)
 local r,mx,my={},99,99
 for i,c in ipairs(s) do
  r[i]={-c[2],c[1]}
  mx=min(mx,-c[2])
  my=min(my,c[1])
 end
 for _,c in ipairs(r) do
  c[1]=c[1]-mx
  c[2]=c[2]-my
 end
 return r
end

function spawn()
 cur=nk
 nk=flr(rnd(7))+1
 shape=shapes[cur]
 px=3 py=0
 if not fits(shape,px,py) then over=true wait=0 end
end

function lock()
 for _,c in ipairs(shape) do
  local x,y=px+c[1],py+c[2]
  if y>=0 then board[y][x]=cols[cur] end
 end
 local keep={}
 for y=0,H-1 do
  local full=true
  for x=0,W-1 do
   if board[y][x]==0 then full=false break end
  end
  if not full then keep[#keep+1]=board[y] end
 end
 local n=H-#keep
 if n>0 then
  score=score+n*10
  for i=1,n*6 do
   if #sparks<30 then
    add(sparks,{x=OX+rnd(W*2),y=OY+rnd(H*2),dx=rnd(2)-1,dy=rnd(2)-1.5,n=12,c=rnd(cols)})
   end
  end
 end
 local nb={}
 for y=0,H-1 do nb[y]=emptyrow() end
 local t=H-1
 for i=#keep,1,-1 do
  nb[t]=keep[i]
  t=t-1
 end
 board=nb
 spawn()
end

function _init()
 board={}
 for y=0,H-1 do board[y]=emptyrow() end
 score=0 over=false wait=0 timer=0 sparks={} tk=0
 nk=flr(rnd(7))+1
 spawn()
end

function _update()
 tk=tk+1
 for _,s in all(sparks) do
  s.x=s.x+s.dx
  s.y=s.y+s.dy
  s.n=s.n-1
  if s.n<=0 then del(sparks,s) end
 end
 if over then
  wait=wait+1
  if wait>25 and (btnp(4) or btnp(5)) then _init() end
  return
 end
 if btnp(0) or (btn(0) and tk%4==0) then
  if fits(shape,px-1,py) then px=px-1 end
 end
 if btnp(1) or (btn(1) and tk%4==0) then
  if fits(shape,px+1,py) then px=px+1 end
 end
 if btnp(2) or btnp(4) or btnp(5) then
  local r=rot(shape)
  if fits(r,px,py) then shape=r
  elseif fits(r,px-1,py) then shape=r px=px-1
  elseif fits(r,px+1,py) then shape=r px=px+1 end
 end
 timer=timer+1
 local sp=max(4,20-flr(score/15))
 if btn(3) then sp=2 end
 if timer>=sp then
  timer=0
  if fits(shape,px,py+1) then py=py+1 else lock() end
 end
end

function candy(x,y,c)
 rectfill(x,y,x+1,y+1,c)
 pset(x,y,7)
end

function _draw()
 cls(0)
 if over then
  print("SCORE",6,6,9)
  print(score,16-#tostring(score)*4,14,hsv(time()*0.5,1,1),2)
  return
 end
 rect(OX-1,OY-1,OX+W*2,OY+H*2,5)
 for y=0,H-1 do
  for x=0,W-1 do
   local c=board[y][x]
   if c>0 then candy(OX+x*2,OY+y*2,c) end
  end
 end
 for _,c in ipairs(shape) do
  candy(OX+(px+c[1])*2,OY+(py+c[2])*2,cols[cur])
 end
 for s in all(sparks) do pset(s.x,s.y,s.c) end
 rectfill(28,9,30,11,cols[nk])
 print(score,1,1,7)
end
