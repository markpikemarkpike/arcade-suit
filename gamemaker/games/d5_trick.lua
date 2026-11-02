-- trick or treat
local up={"d...d","dd.dd","d8d8d",".ddd."}
local dn={".ddd.","d8d8d","dd.dd","d...d"}
local chars,bats,pos,t,nb,cm
function _init()
 local msg="TRICK OR TREAT"
 chars={}
 for i=1,#msg do chars[i]=string.sub(msg,i,i) end
 bats={}
 for i=1,10 do
  local k=i%3
  add(bats,{x=rnd(32),y=k==0 and 14 or (k==1 and 2 or 26),a=k==0 and 8 or 1,sp=(0.3+rnd(0.5))*(i%2==0 and 1 or -1),ph=rnd(6)})
 end
 pos=0 t=0 nb=5 cm=0
end
function _update()
 t=t+1
 local s=1
 if btn(1) then s=2.5 elseif btn(0) then s=0.3 end
 pos=pos+s
 if pos>200 then pos=0 end
 if btnp(4) or btnp(5) then cm=(cm+1)%3 end
 if btnp(2) then nb=min(nb+1,10) end
 if btnp(3) then nb=max(nb-1,1) end
 for i=1,nb do
  local b=bats[i]
  b.x=b.x+b.sp
  if b.x>34 then b.x=-6 elseif b.x<-6 then b.x=34 end
 end
end
function _draw()
 cls(0)
 for i=1,#chars do
  local cx=32-pos+(i-1)*12
  if cx>-12 and cx<32 then
   local cy=8+sin(pos*0.06+i*0.7)*2
   local c=0
   if cm==0 then
    c=hsv(time()*0.3+i*0.07,1,1)
   elseif cm==1 then
    c=(i%2==0) and 9 or 10
   else
    c=(i%2==0) and 11 or 13
   end
   print(chars[i],cx+1,cy+1,2,3)
   print(chars[i],cx,cy,c,3)
  end
 end
 for i=1,nb do
  local b=bats[i]
  local f=up
  if (t+i*3)%8>=4 then f=dn end
  spr(f,b.x,b.y+sin(t*0.1+b.ph)*b.a)
 end
end
