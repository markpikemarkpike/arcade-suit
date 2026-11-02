// Game Maker: everything the page does except talking to Claude and to the screen.
// Those two jobs belong to GM_ADAPTER (phone.js on the suit, the demo's own adapter in a browser).
var GM=(function(){
var A=GM_ADAPTER,$=function(i){return document.getElementById(i)};
var LS={get:function(k){try{return localStorage.getItem(k)}catch(e){return null}},set:function(k,v){try{localStorage.setItem(k,v)}catch(e){}}};
var cur=LS.get('cur')||'',curName=LS.get('curName')||'',busy=false,games=[],seen='',clock=0,t0=0,words='';
try{games=JSON.parse(LS.get('games')||'[]')}catch(e){}
if(!LS.get('seeded')){games=games.concat(GM_STARTERS);LS.set('seeded','1')}
var IDEAS=['mix small fruits to make big ones','pumpkin catches candy','a bat flapping through gaps','ghost tag','rainbow snake','say HAPPY HALLOWEEN','fireworks'];
var MORE=['a cat that jumps over pumpkins','space ship dodging candy corn','a witch flying through clouds','bop the zombies as they pop up','a spider climbing its web','a big beating heart','soccer against a skeleton','a frog crossing a spooky road','lava floor with jumping','a dancing robot','catch falling stars','a maze with a friendly monster'];

function log(t){if(A.log)A.log(t)}
function show(){$('said').textContent=words+(clock?' '+Math.round((Date.now()-t0)/1000)+' s':'')}
function say(t,kind){words=t;$('say').className='gm-say'+(kind=='err'?' err':'');show()}
function step(n){var l=$('steps');l.hidden=!n;for(var i=0;i<4;i++)l.children[i].className=i+1<n?'done':i+1==n?(n==4?'done':'now'):''}
function timer(on){clearInterval(clock);clock=0;if(on){t0=Date.now();clock=setInterval(show,1000)}}
function lock(b){busy=b;$('new').disabled=$('chg').disabled=b}
function keep(){games=games.slice(0,18);LS.set('games',JSON.stringify(games));LS.set('cur',cur);LS.set('curName',curName)}
function wait(ms){return new Promise(function(r){setTimeout(r,ms)})}
function pull(t){var m=t.match(/```(?:lua)?[ \t]*\r?\n([\s\S]*?)```/);return m?m[1]:''}

// ---- pictures: a 32x32 canvas is the whole screen
function paint(cv,px){var g=cv.getContext('2d'),im=g.createImageData(32,32),d=im.data;
 for(var i=0;i<1024;i++){var p=px[i];d[i*4]=lift(p>>16&255);d[i*4+1]=lift(p>>8&255);d[i*4+2]=lift(p&255);d[i*4+3]=255}g.putImageData(im,0,0)}
function lift(v){return v?Math.round(255*Math.pow(v/255,.6)):0} // LEDs look brighter than the numbers say
function badge(cv,name){var h=7,i,g=cv.getContext('2d');for(i=0;i<name.length;i++)h=(h*31+name.charCodeAt(i))>>>0;
 g.fillStyle='#000';g.fillRect(0,0,32,32);g.fillStyle='hsl('+h%360+',95%,60%)';
 for(var y=0;y<6;y++)for(var x=0;x<3;x++)if(h>>(y*3+x)&1||(x==2&&y%2==h%2)){g.fillRect(4+x*4,4+y*4,4,4);g.fillRect(24-x*4,4+y*4,4,4)}}
function mirror(px){if(px)paint($('mini'),px)}
async function snap(name){await wait(2600);var px=null;try{px=await A.shot()}catch(e){}
 if(!px)return;var lit=0;for(var i=0;i<1024;i++)if(px[i])lit++;if(lit<8)return;
 var c=document.createElement('canvas');c.width=c.height=32;paint(c,px);
 games.forEach(function(g){if(g.n==name)g.t=c.toDataURL('image/png')});keep();draw()}

function draw(){$('chg').hidden=!cur;$('chg').textContent=curName?'Change "'+curName+'"':'Change this game';
 $('shelf').hidden=!games.length;var m=$('mine');m.textContent='';
 games.forEach(function(g,i){var c=document.createElement('div');c.className='gm-card'+(g.c==cur?' cur':'');
  var p=document.createElement('button');p.type='button';p.className='play';var pic;
  if(g.t){pic=document.createElement('img');pic.src=g.t;pic.alt=''}else{pic=document.createElement('canvas');pic.width=pic.height=32;badge(pic,g.n)}
  var s=document.createElement('span');s.textContent=g.n;p.appendChild(pic);p.appendChild(s);p.onclick=function(){if(!busy)replay(i)};
  var x=document.createElement('button');x.type='button';x.className='x';x.textContent='×';x.setAttribute('aria-label','Delete '+g.n);
  x.onclick=function(){if(x.className=='x'){x.className='x sure';x.textContent='Delete?';setTimeout(function(){x.className='x';x.textContent='×'},2500)}else{games.splice(i,1);keep();draw()}};
  c.appendChild(p);c.appendChild(x);m.appendChild(c)});
 if(A.onDraw)A.onDraw(cur,curName)}

async function make(change){var q=$('ask').value.trim();if(busy)return;
 if(!q){say('First tell me what to make!','err');$('ask').focus();return}
 var no=A.ready();if(no){say(no,'err');return}
 lock(true);$('ask').blur();step(1);say('Got it! Watch the screen.');timer(true);log('heard: "'+q+'"');
 try{await A.busy();
  var msgs=[{role:'user',content:change&&cur?'Here is the game running right now:\n```lua\n'+cur+'\n```\nChange it like this: '+q:q}];
  for(var round=0;;round++){step(2);say(round?'Oops, a little bug. Fixing it...':'Claude is writing your game...');
   var a=await A.ask(msgs),code=pull(a.text),bad='';
   if(!code)bad=a.cut?'Your program was cut off because it was too long. Write a much shorter one.':'I could not find a ```lua code block in your reply.';
   else{step(3);say('Sending it to the suit...');log('got '+code.length+' characters of game code');bad=await A.run(code,function(t){say(t)})}
   if(!bad){cur=code;curName=((code.match(/^--\s*(.+)/)||[])[1]||q).trim().slice(0,40);seen='';
    games=games.filter(function(g){return g.n!=curName});games.unshift({n:curName,c:code});keep();draw();
    timer(false);step(4);say(a.text.split('```')[0].trim()||'Playing!');$('ask').value='';log('playing "'+curName+'" after '+Math.round((Date.now()-t0)/1000)+' s');snap(curName);break}
   log('the suit said: '+bad);
   if(round>=2)throw{msg:'I tried 3 times but it kept breaking ('+bad+'). Try saying it a different way.'};
   await A.busy();
   msgs.push({role:'assistant',content:a.text||'(nothing)'},{role:'user',content:'That did not work. The arcade reported: '+bad+'\nFix it and send the whole program again.'})}
 }catch(e){timer(false);step(0);say(e.arcade?'I cannot reach the suit. Is it in Magic mode and on the same Wi-Fi?':e.msg||('Something went wrong: '+e),'err');log('gave up');await A.idle()}
 lock(false);tick()}

async function replay(i){var g=games[i];lock(true);step(3);say('Loading '+g.n+'...');await A.busy();
 try{var b=await A.run(g.c,function(t){say(t)});
  if(b){step(0);say('That one broke: '+b,'err')}else{cur=g.c;curName=g.n;seen='';keep();draw();step(4);say('Playing '+g.n+'!');log('playing "'+g.n+'"');if(!g.t)snap(g.n)}}
 catch(e){step(0);say('I cannot reach the suit.','err')}
 lock(false)}

// A game that breaks while it is being played: offer to mend it.
function broke(err){if(!err||err==seen||!cur||busy)return;seen=err;step(0);say('Oops, the game hit a bug. Tap Change to fix it.','err');if(!$('ask').value)$('ask').value='Fix this bug: '+err;log('the game stopped: '+err)}
async function tick(){if(busy)return;var s;try{s=await A.poll()}catch(e){s={ok:false,text:'I cannot see the suit.'}}
 $('pill').className='gm-pill '+(s.ok?'ok':'bad');$('pill').textContent=s.text;if(s.error)broke(s.error);
 if(s.ok&&A.slowMirror)try{mirror(await A.shot())}catch(e){}}

IDEAS.forEach(function(t){var b=document.createElement('button');b.type='button';b.textContent=t;b.onclick=function(){$('ask').value=t};$('ideas').appendChild(b)});
(function(){var b=document.createElement('button');b.type='button';b.className='dice';b.textContent='Surprise me';b.onclick=function(){$('ask').value=MORE[Math.floor(Math.random()*MORE.length)]};$('ideas').insertBefore(b,$('ideas').firstChild)})();
$('form').onsubmit=function(e){e.preventDefault();make(false)};$('chg').onclick=function(){make(true)};
$('ask').onkeydown=function(e){if(e.key=='Enter'&&!e.shiftKey){e.preventDefault();make(false)}};
function mic(m){ // m = {start(onText,onState), stop()}. Only some browsers have one.
 var on=false,base='';$('mic').hidden=false;$('box').className='gm-box mic';$('hint').hidden=true;
 $('mic').onclick=function(){if(on){m.stop();return}base=$('ask').value?$('ask').value+' ':'';
  m.start(function(t,fin){$('ask').value=base+t;if(fin)base=$('ask').value+' '},function(l){on=l;$('mic').className='gm-mic'+(l?' on':'')})}}
if(A.keyboardMic)$('hint').hidden=false;
if(!cur&&A.saved)A.saved().then(function(t){if(t&&!cur){cur=t;draw()}}).catch(function(){});
setInterval(tick,A.every||4000);tick();draw();
return{say:say,step:step,mirror:mirror,broke:broke,mic:mic,tick:tick,draw:draw,busy:function(){return busy},play:function(n){for(var i=0;i<games.length;i++)if(games[i].n==n)return replay(i)}};
})();
