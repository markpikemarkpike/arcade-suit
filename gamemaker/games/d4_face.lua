-- pumpkin face
local m,mt,lx,ly,tx,ty,t,nt
local function eye(cx,cy,r,wc,ox,oy,pr)
 circfill(cx,cy,r,wc)
 circfill(cx+ox,cy+oy,pr,0)
end
function _init()
 m=0 mt=0 lx=0 ly=0 tx=0 ty=0 t=0 nt=20
end
function _update()
 t=t+1
 local nm=nil
 if btnp(4) then nm=1
 elseif btnp(5) then nm=2
 elseif btnp(0) then nm=3
 elseif btnp(1) then nm=4
 elseif btnp(2) then nm=5
 elseif btnp(3) then nm=6 end
 if nm then m=nm mt=50 end
 if mt>0 then
  mt=mt-1
  if mt==0 then m=0 end
 end
 nt=nt-1
 if nt<=0 then
  tx=flr(rnd(5))-2 ty=flr(rnd(5))-2 nt=15+flr(rnd(35))
 end
 lx=lx+(tx-lx)*0.25
 ly=ly+(ty-ly)*0.25
end
function _draw()
 cls(0)
 camera(sin(time()*1.5)*1.5,sin(time()*3))
 local bc=9
 if m==3 then bc=8 elseif m==4 then bc=10 elseif m==6 then bc=hsv(time()*0.7,1,1) end
 circfill(16,19,12,bc)
 circfill(8,19,8,bc)
 circfill(24,19,8,bc)
 rectfill(14,3,17,8,11)
 pset(18,3,11) pset(19,2,11)
 line(5,14,5,25,4) line(27,14,27,25,4)
 if m==0 then
  if t%90<4 then
   line(6,15,14,15,0) line(18,15,26,15,0)
  else
   eye(10,15,4,7,lx,ly,2) eye(22,15,4,7,lx,ly,2)
  end
 elseif m==1 then
  eye(10,15,4,7,lx,ly,2) eye(22,15,4,7,lx,ly,2)
 elseif m==2 then
  local a=time()*10
  eye(10,15,4,7,cos(a)*2,sin(a)*2,2) eye(22,15,4,7,cos(a)*2,sin(a)*2,2)
 elseif m==3 then
  eye(10,15,4,7,2,1,2) eye(22,15,4,7,-2,1,2)
  line(5,9,14,13,0) line(5,10,14,14,0) line(26,9,18,13,0) line(26,10,18,14,0)
 elseif m==4 then
  eye(10,15,5,7,0,0,1) eye(22,15,5,7,0,0,1)
 elseif m==5 then
  line(6,16,10,14,0) line(10,14,14,16,0) line(6,17,10,15,0) line(10,15,14,17,0)
  eye(22,15,4,7,lx,ly,2)
 else
  local w=sin(time()*9)*1.5
  eye(10,15,4,7,2,w,2) eye(22,15,5,7,-2,-w,2)
 end
 pset(16,18,0) rectfill(15,19,17,19,0)
 if m==0 then
  for x=-5,5 do
   local y=25-flr(x*x/10)
   pset(16+x,y,0) pset(16+x,y+1,0)
  end
 elseif m==1 then
  rectfill(7,21,26,27,0)
  for x=8,24,4 do rectfill(x,21,x+1,23,7) end
  for x=10,22,4 do rectfill(x,25,x+1,27,7) end
 elseif m==2 then
  local sw=sin(time()*10)*2
  rectfill(10,22,22,25,0)
  rectfill(13+sw,24,19+sw,29,14)
  line(16+sw,25,16+sw,28,8)
 elseif m==3 then
  for x=-6,6 do
   local y=22+flr(x*x/10)
   pset(16+x,y,0) pset(16+x,y+1,0)
  end
 elseif m==4 then
  circfill(16,24,4,0)
 elseif m==5 then
  for x=-7,7 do
   local y=26-flr(x*x/14)
   pset(16+x,y,0) pset(16+x,y+1,0) pset(16+x,y+2,0)
  end
 else
  for x=-7,7 do
   local y=25+flr(sin(x*0.8+time()*9)*2)
   pset(16+x,y,0) pset(16+x,y+1,0)
  end
  rectfill(19,26,22,30,14)
 end
end
