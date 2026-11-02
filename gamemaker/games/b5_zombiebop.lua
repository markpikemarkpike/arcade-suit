-- zombie bop
local zr={".bbbbb.","b8bbb8b","bbbbbbb","bb000bb","b22222b","2222222"}
local zf={}
for h=1,6 do
 local q={}
 for k=1,h do q[k]=zr[k] end
 zf[h]=q
end
local st,hh,tm,cur,score,lives,over,wait,sparks,shake,nt,hm,hc
function _init()
 st={} hh={} tm={}
 for i=1,9 do st[i]=0 hh[i]=0 tm[i]=0 end
 cur=5 score=0 lives=3 over=false wait=0 sparks={} shake=0 nt=20 hm=0 hc=5
end
function _update()
 if over then
  wait=wait+1
  if wait>25 and (btnp(4) or btnp(5)) then _init() end
  return
 end
 local col=(cur-1)%3
 local row=flr((cur-1)/3)
 if btnp(0) and col>0 then cur=cur-1 end
 if btnp(1) and col<2 then cur=cur+1 end
 if btnp(2) and row>0 then cur=cur-3 end
 if btnp(3) and row<2 then cur=cur+3 end
 if hm>0 then hm=hm-1 end
 if btnp(4) or btnp(5) then
  hm=4 hc=cur
  if st[cur]>=1 and st[cur]<=3 then
   st[cur]=4 score=score+1 shake=3
   local x=1+((cur-1)%3)*10+5
   local y=8+flr((cur-1)/3)*8+2
   for k=1,6 do
    if #sparks<40 then add(sparks,{x=x,y=y,dx=rnd(3)-1.5,dy=rnd(3)-1.5,n=8,c=rnd({7,10,11})}) end
   end
  end
 end
 for i=1,9 do
  if st[i]==1 then
   hh[i]=hh[i]+0.5
   if hh[i]>=6 then
    hh[i]=6 st[i]=2 tm[i]=max(18,45-score*0.7)
   end
  elseif st[i]==2 then
   tm[i]=tm[i]-1
   if tm[i]<=0 then st[i]=3 end
  elseif st[i]==3 then
   hh[i]=hh[i]-0.6
   if hh[i]<=0 then
    hh[i]=0 st[i]=0 lives=lives-1 shake=6
    if lives<=0 then over=true wait=0 end
   end
  elseif st[i]==4 then
   hh[i]=hh[i]-1
   if hh[i]<=0 then hh[i]=0 st[i]=0 end
  end
 end
 nt=nt-1
 if nt<=0 then
  local i=flr(rnd(9))+1
  if st[i]==0 then
   st[i]=1 hh[i]=0
   nt=max(10,38-score*0.8)+flr(rnd(10))
  else
   nt=2
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
 for i=1,9 do
  local cx=1+((i-1)%3)*10
  local ry=8+flr((i-1)/3)*8
  local h=min(6,flr(hh[i]))
  if h>=1 then spr(zf[h],cx+1,ry+6-h) end
  rectfill(cx,ry+6,cx+9,ry+6,9)
  rectfill(cx,ry+7,cx+9,ry+7,4)
 end
 for s in all(sparks) do pset(s.x,s.y,s.c) end
 if hm>0 then
  local hx=1+((hc-1)%3)*10
  local hy=8+flr((hc-1)/3)*8
  rectfill(hx+1,hy+1,hx+8,hy+4,9)
  rect(hx+1,hy+1,hx+8,hy+4,4)
 end
 local qx=1+((cur-1)%3)*10
 local qy=8+flr((cur-1)/3)*8
 rect(qx,qy,qx+9,qy+7,(flr(time()*6)%2==0) and 10 or 7)
 camera()
 print(score,1,1,7)
 for i=1,lives do rectfill(32-i*3,1,33-i*3,2,8) end
end
