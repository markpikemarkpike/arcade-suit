-- snow and snowman
local man={
 "...888...",
 "...888...",
 "..88888..",
 ".5555555.",
 "....9....",
 "..77777..",
 "..70770..",
 "..77977..",
 "...777...",
 "..77777..",
 ".7777777.",
 "77777777.",
 "7777777..",
 "..77777.."
}
local flakes,sparks,wind,amount,hi,t,sx,sy

function newflake(anywhere)
 return {x=rnd(32),y=anywhere and rnd(32) or -1,dy=0.3+rnd(0.5),c=rnd({7,7,13})}
end

function burst(x,y)
 for i=1,12 do
  if #sparks<30 then
   add(sparks,{x=x,y=y,dx=rnd(2)-1,dy=rnd(2)-1.5,n=16,c=rnd({7,10,12,13})})
  end
 end
end

function _init()
 flakes={}
 for i=1,25 do add(flakes,newflake(true)) end
 sparks={}
 wind=0 amount=25 hi=0 t=0 sx=11 sy=14
end

function _update()
 t=time()
 if btn(0) then wind=max(-1.5,wind-0.05) end
 if btn(1) then wind=min(1.5,wind+0.05) end
 if not btn(0) and not btn(1) then wind=wind*0.97 end
 if btnp(2) and amount<40 then amount=amount+5 end
 if btnp(3) and amount>5 then amount=amount-5 end
 if btnp(4) or btnp(5) then
  hi=40
  burst(sx+4,sy+4)
 end
 if hi>0 then hi=hi-1 end
 if #flakes<amount then add(flakes,newflake(false)) end
 if #flakes>amount then deli(flakes,#flakes) end
 for f in all(flakes) do
  f.x=f.x+wind+sin(t*2+f.y*0.2)*0.3
  f.y=f.y+f.dy
  if f.y>31 then
   f.y=-1
   f.x=rnd(32)
  end
  if f.x<0 then f.x=31 end
  if f.x>31 then f.x=0 end
 end
 for s in all(sparks) do
  s.x=s.x+s.dx
  s.y=s.y+s.dy
  s.n=s.n-1
  if s.n<=0 then del(sparks,s) end
 end
end

function _draw()
 cls(0)
 rectfill(0,28,31,31,6)
 for f in all(flakes) do pset(f.x,f.y,f.c) end
 spr(man,sx,sy)
 local wv=0
 if hi>0 then wv=sin(t*14)*2 end
 line(sx+1,sy+8,sx-2,sy+6,4)
 line(sx+8,sy+8,sx+11,sy+4+wv,4)
 circfill(sx+11,sy+4+wv,1,4)
 for s in all(sparks) do pset(s.x,s.y,s.c) end
end
