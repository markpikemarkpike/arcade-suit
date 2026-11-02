-- fruit merge
local R={1.5,2.5,3.5,4.5,6,7.5}
local C={8,14,2,9,10,11}
local W=23
local fr,cx,cur,nxt,score,over,wait,cool,sp
function _init()
 fr={} sp={} cx=12 cur=1 nxt=flr(rnd(3))+1 score=0 over=false wait=0 cool=0
end
local function fruit(x,y,k,r)
 r=r or R[k]
 circfill(x,y,r,C[k])
 pset(x,y-r-1,3)
 if r>2 then pset(x-r/2,y-r/2,7) end
end
function _update()
 if over then
  wait=wait+1
  if wait>25 and (btnp(4) or btnp(5)) then _init() end
  return
 end
 if btn(0) then cx=cx-0.8 end
 if btn(1) then cx=cx+0.8 end
 cx=mid(R[cur],cx,W-R[cur])
 if cool>0 then cool=cool-1 end
 if cool==0 and (btnp(4) or btnp(5)) and #fr<22 then
  add(fr,{x=cx,y=4,vx=0,vy=0,k=cur,t=0})
  cur=nxt nxt=flr(rnd(3))+1 cool=12
 end
 for f in all(fr) do
  local r=R[f.k]
  f.vy=f.vy+0.08 f.x=f.x+f.vx f.y=f.y+f.vy f.t=f.t+1
  if f.x<r then f.x=r f.vx=-f.vx*0.3 end
  if f.x>W-r then f.x=W-r f.vx=-f.vx*0.3 end
  if f.y>31-r then f.y=31-r f.vy=-f.vy*0.2 f.vx=f.vx*0.9 end
 end
 for pass=1,2 do
  for i=1,#fr do
   local a=fr[i]
   for j=i+1,#fr do
    local b=fr[j]
    if not a.dead and not b.dead then
     local dx,dy=b.x-a.x,b.y-a.y
     local d,m=sqrt(dx*dx+dy*dy),R[a.k]+R[b.k]+0.5
     if d<m then
      if a.k==b.k and a.k<#R then
       a.dead=true b.k=b.k+1 b.x=(a.x+b.x)/2 b.y=(a.y+b.y)/2 b.vx=0 b.vy=0 b.t=0
       score=score+a.k
       for n=1,5 do if #sp<15 then add(sp,{x=b.x,y=b.y,dx=rnd(2)-1,dy=rnd(2)-1.5,n=8,c=C[b.k]}) end end
      else
       if d<0.01 then dx=0.1 dy=-0.1 d=0.14 end
       local p,nx,ny=(m-d)/2,dx/d,dy/d
       a.x=a.x-nx*p a.y=a.y-ny*p b.x=b.x+nx*p b.y=b.y+ny*p
       local rv=(b.vx-a.vx)*nx+(b.vy-a.vy)*ny
       if rv<0 then
        a.vx=a.vx+nx*rv*0.55 a.vy=a.vy+ny*rv*0.55
        b.vx=b.vx-nx*rv*0.55 b.vy=b.vy-ny*rv*0.55
       end
      end
     end
    end
   end
  end
 end
 for f in all(fr) do
  if f.dead then del(fr,f)
  elseif f.t>45 and f.y-R[f.k]<7 then over=true wait=0 end
 end
 for s in all(sp) do
  s.x=s.x+s.dx s.y=s.y+s.dy s.n=s.n-1
  if s.n<=0 then del(sp,s) end
 end
end
function _draw()
 cls(0)
 if over then
  print("SCORE",6,8,9)
  print(score,16-#tostring(score)*4,16,hsv(time(),1,1),2)
  return
 end
 line(W+1,6,W+1,31,5)
 for x=0,W,3 do pset(x,7,1) end
 for y=9,30,4 do pset(cx,y,5) end
 for f in all(fr) do fruit(f.x,f.y,f.k) end
 if cool==0 then fruit(cx,4,cur,min(R[cur],2.5)) end
 for s in all(sp) do pset(s.x,s.y,s.c) end
 rect(25,0,31,7,6)
 fruit(28,4,nxt,min(R[nxt],2))
 print(score,32-#tostring(score)*4,10,7)
end
