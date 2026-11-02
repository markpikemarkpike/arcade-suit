-- copy the colors
local pads={
 {x1=11,y1=6,x2=20,y2=13,k=2,c=8,d=2},
 {x1=21,y1=14,x2=30,y2=21,k=1,c=10,d=4},
 {x1=11,y1=22,x2=20,y2=29,k=3,c=12,d=1},
 {x1=1,y1=14,x2=10,y2=21,k=0,c=11,d=3}
}
local seq,state,si,pos,timer,lit,litT,over,wait

function addstep()
 add(seq,flr(rnd(4))+1)
end

function _init()
 seq={}
 addstep()
 state="show" si=1 pos=1 timer=0 lit=0 litT=0 over=false wait=0
end

function _update()
 if litT>0 then
  litT=litT-1
  if litT==0 then lit=0 end
 end
 if over then
  wait=wait+1
  if wait>25 and (btnp(4) or btnp(5)) then _init() end
  return
 end
 timer=timer+1
 if state=="show" then
  lit=0
  if timer<12 and si<=#seq then lit=seq[si] end
  if timer>=20 then
   timer=0
   si=si+1
   if si>#seq then
    state="input"
    pos=1
    lit=0
   end
  end
 elseif state=="input" then
  for i=1,4 do
   if btnp(pads[i].k) then
    lit=i
    litT=8
    if seq[pos]==i then
     pos=pos+1
     if pos>#seq then
      state="win"
      timer=0
     end
    else
     over=true
     wait=0
    end
    break
   end
  end
 elseif state=="win" then
  lit=0
  if timer>30 then
   addstep()
   state="show"
   si=1
   timer=0
  end
 end
end

function _draw()
 cls(0)
 if over then
  print("SCORE",6,6,9)
  local s=#seq-1
  print(s,16-#tostring(s)*4,14,hsv(time()*0.5,1,1),2)
  return
 end
 for i=1,4 do
  local p=pads[i]
  local col=p.d
  if lit==i then col=p.c end
  if state=="win" then col=hsv(time()*0.8+i*0.2,1,1) end
  rectfill(p.x1,p.y1,p.x2,p.y2,col)
 end
 rectfill(0,0,15,5,0)
 print(#seq-1,1,1,7)
end
