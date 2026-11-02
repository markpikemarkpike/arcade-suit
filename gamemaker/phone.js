// The phone's side of Magic mode. Claude is reached straight from this browser. The suit is reached at this page's own address.
var GM_ADAPTER=(function(){
var $=function(i){return document.getElementById(i)};
function ls(k){try{return localStorage.getItem(k)||''}catch(e){return''}}
function put(k,v){try{localStorage.setItem(k,v)}catch(e){}}
function tf(u,o,ms){var c=new AbortController(),t=setTimeout(function(){c.abort()},ms);o=o||{};o.signal=c.signal;return fetch(u,o).finally(function(){clearTimeout(t)})}
function post(u,b,ms){return tf(u,{method:'POST',body:b},ms||4000)}
function wait(ms){return new Promise(function(r){setTimeout(r,ms)})}
async function status(){return(await tf('/status',{},2500)).json()}
$('key').value=ls('key');$('model').value=ls('model')||'claude-sonnet-5-5';if(!$('model').value)$('model').value='claude-sonnet-5-5';$('model2').value=ls('model2');
$('key').onchange=function(){put('key',this.value.trim())};$('model').onchange=function(){put('model',this.value)};$('model2').onchange=function(){put('model2',this.value.trim())};
if(!$('key').value)$('set').open=true;
async function send(code){var f=new FormData();f.append('f',new Blob([code],{type:'text/plain'}),'game.lua');
 var r;try{r=await post('/game',f,15000)}catch(e){throw{arcade:1}}
 if(!r.ok)return await r.text();
 for(var i=0,m=0;i<7&&m<2;i++){await wait(700);var s;try{s=await status()}catch(e){m++;continue}if(s.state=='error')return s.error||'it stopped'}
 return''}
$('scan').onclick=async function(){this.textContent='Looking...';try{var l=await(await tf('/scan',{},12000)).json(),s=$('nets');s.textContent='';var o=document.createElement('option');o.value='';o.textContent='Pick one...';s.appendChild(o);
 l.forEach(function(n){var o=document.createElement('option');o.value=o.textContent=n;s.appendChild(o)});s.hidden=false}catch(e){}this.textContent='Look again'};
$('nets').onchange=function(){$('ssid').value=this.value};
$('join').onclick=async function(){var b=new URLSearchParams();b.set('ssid',$('ssid').value);b.set('pass',$('pass').value);
 try{var r=await post('/wifi',b);GM.say(r.ok?'Saved! Keep Settings > Personal Hotspot open on the iPhone. When the suit joins, scan the new code on the M5Stack screen.':'That name or password does not look right.',r.ok?'':'err')}catch(e){GM.say('I cannot reach the suit.','err')}};
return{
 keyboardMic:true,slowMirror:true,every:4000,
 ready:function(){if($('key').value.trim())return'';$('set').open=true;return'A grown-up needs to add the API key first.'},
 busy:async function(){try{await post('/busy')}catch(e){}},
 idle:async function(){try{await post('/idle')}catch(e){}},
 ask:async function(msgs){var c=new AbortController(),t=setTimeout(function(){c.abort()},150000);
  try{var r;try{r=await fetch('https://api.anthropic.com/v1/messages',{method:'POST',signal:c.signal,headers:{'content-type':'application/json','x-api-key':$('key').value.trim(),'anthropic-version':'2023-06-01','anthropic-dangerous-direct-browser-access':'true'},body:JSON.stringify({model:$('model2').value.trim()||$('model').value,max_tokens:6000,system:GM_PROMPT,messages:msgs})})}
   catch(e){throw{msg:'I cannot reach Claude. Is the phone online? If the phone joined the ArcadeSuit Wi-Fi, set up the hotspot in Grown-up settings.'}}
   if(!r.ok){var d='';try{d=(await r.json()).error.message}catch(e){}
    throw{msg:r.status==401?'The API key is not right. Check it in Grown-up settings.':r.status==429||r.status==529?'Claude is very busy. Wait a moment and try again.':'Claude said no ('+r.status+'): '+d}}
   var j;try{j=await r.json()}catch(e){throw{msg:'The answer from Claude got cut off. Try again.'}}
   var x='';(j.content||[]).forEach(function(b){if(b.type=='text')x+=b.text});
   return{text:x,cut:j.stop_reason=='max_tokens'}}finally{clearTimeout(t)}},
 // The link to the suit drops now and then. The game is already written, so keep knocking for two minutes.
 run:async function(code,note){var end=Date.now()+120000,n=0;
  while(Date.now()<end){try{return await send(code)}catch(e){note('Your game is ready, but I lost the suit. '+(++n>2?'Open Settings > Personal Hotspot on the iPhone and stay there. If the suit says PRESS START, wake the controller.':'Trying again...'));await wait(3000)}}
  throw{arcade:1}},
 shot:async function(){var b=await(await tf('/screen',{},2500)).arrayBuffer();return b.byteLength==4096?new Uint32Array(b):null},
 poll:async function(){try{var s=await status();$('diag').textContent=JSON.stringify(s,null,1);
   return{ok:true,text:'Suit connected'+(s.pad?'':', controller off'),error:s.state=='error'?s.error:''}}
  catch(e){return{ok:false,text:'The suit is off, or resting its Wi-Fi for a big game. SELECT on the controller wakes it.'}}},
 saved:async function(){var r=await tf('/code',{},4000);return r.ok?r.text():''},
 onDraw:function(code){$('code').textContent=code}
}})();
