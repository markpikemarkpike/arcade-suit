// Drives the real phone page in a pretend iPhone against a pretend suit and a pretend Claude. node test/page.test.js
const {chromium,devices}=require('playwright'),mock=require('./mock.js'),fs=require('fs');
const good=fs.readFileSync(__dirname+'/../gamemaker/games/a4_jump.lua','utf8');
const reply=(c,pre='Jump with A!')=>({status:200,contentType:'application/json',headers:{'access-control-allow-origin':'*'},body:JSON.stringify({content:[{type:'text',text:pre+'\n```lua\n'+c+'\n```'}],stop_reason:'end_turn'})});
(async()=>{const srv=await mock.start(8099),b=await chromium.launch();let pass=0,fail=0;
 async function scene(name,replies,opt={}){const ctx=await b.newContext({...devices['iPhone 13']}),p=await ctx.newPage();let calls=[];mock.log.length=0;mock.st.state='idle';mock.st.error='';
  p.on('pageerror',e=>console.log('  PAGEERROR',e.message));
  await p.route('https://api.anthropic.com/**',r=>{if(r.request().method()=='OPTIONS')return r.fulfill({status:204,headers:{'access-control-allow-origin':'*','access-control-allow-headers':'*'}});calls.push(JSON.parse(r.request().postData()));const h=r.request().headers();if(!h['anthropic-dangerous-direct-browser-access']||h['anthropic-version']!='2023-06-01')console.log('  BAD HEADERS');const x=replies.shift();if(x=='net')return r.abort();r.fulfill(x)});
  await p.goto('http://127.0.0.1:8099/');
  if(!opt.nokey){await p.fill('#key','not-a-real-key');await p.dispatchEvent('#key','change');await p.evaluate(()=>document.getElementById('set').open=false)}
  if(opt.down)await p.route('**/127.0.0.1:8099/**',r=>r.abort());
  await p.fill('#ask',opt.ask||'jump over pumpkins');await p.click('#new');
  await p.waitForFunction(()=>!document.getElementById('new').disabled,null,{timeout:60000});
  if(opt.then)await opt.then(p,calls);
  const say=await p.textContent('#say'),ok=opt.expect.test(say);ok?pass++:fail++;
  console.log((ok?'PASS ':'FAIL ')+name+' | calls='+calls.length+' | say="'+say.slice(0,110)+'"');console.log('   '+mock.log.filter(l=>!/status/.test(l)).join(' ; ').slice(0,300));
  await p.screenshot({path:__dirname+'/out/page_'+name+'.png',fullPage:!!opt.full});await ctx.close();return calls}
 await scene('happy',[reply(good)],{expect:/Jump with A/});
 let c=await scene('repair_syntax',[reply('x=0 function _update() x += 1 end function _draw() cls() end'),reply(good,'Fixed! Jump with A.')],{expect:/Fixed/});
 console.log('   repair msg: '+c[1].messages[2].content.slice(0,120).replace(/\n/g,' '));
 c=await scene('repair_runtime',[reply('function _update() nope() end function _draw() cls() end'),reply(good,'Fixed it!')],{expect:/Fixed it/});
 console.log('   repair msg: '+c[1].messages[2].content.slice(0,140).replace(/\n/g,' '));
 await scene('gives_up',[reply('x +='),reply('x +='),reply('x +=')],{expect:/tried 3 times/});
 await scene('bad_key',[{status:401,contentType:'application/json',headers:{'access-control-allow-origin':'*'},body:'{"error":{"message":"invalid x-api-key"}}'}],{expect:/key is not right/});
 await scene('overloaded',[{status:529,contentType:'application/json',headers:{'access-control-allow-origin':'*'},body:'{"error":{"message":"Overloaded"}}'}],{expect:/very busy/});
 await scene('no_internet',['net'],{expect:/cannot reach Claude/});
 await scene('no_key',[],{nokey:true,expect:/API key first/,full:true});
 // Arcade asleep (big game, Wi-Fi off): Claude is still called, the page keeps knocking, then delivers when the arcade wakes.
 {const ctx=await b.newContext({...devices['iPhone 13']}),p=await ctx.newPage();mock.log.length=0;mock.st.state='idle';mock.st.error='';
  await p.route('https://api.anthropic.com/**',r=>r.fulfill(reply(good,'Woke up!')));
  await p.goto('http://127.0.0.1:8099/');await p.fill('#key','k');await p.dispatchEvent('#key','change');
  let down=true;await p.route('**/127.0.0.1:8099/**',r=>down?r.abort():r.continue());
  await p.fill('#ask','x');await p.click('#new');await p.waitForFunction(()=>/lost the suit/.test(document.getElementById('say').textContent),null,{timeout:20000});
  await p.screenshot({path:__dirname+'/out/page_select.png'});down=false;
  await p.waitForFunction(()=>!document.getElementById('new').disabled,null,{timeout:30000});const say=await p.textContent('#say');const ok=/Woke up/.test(say);ok?pass++:fail++;console.log((ok?'PASS ':'FAIL ')+'asleep_then_wakes | '+say);await ctx.close()}
 // A bug that shows up later is offered for fixing.
 {const ctx=await b.newContext({...devices['iPhone 13']}),p=await ctx.newPage();mock.st.state='idle';mock.st.error='';
  await p.route('https://api.anthropic.com/**',r=>r.fulfill(reply(good)));await p.goto('http://127.0.0.1:8099/');await p.fill('#key','k');await p.dispatchEvent('#key','change');
  await p.fill('#ask','x');await p.click('#new');await p.waitForFunction(()=>!document.getElementById('new').disabled,null,{timeout:30000});
  mock.st.state='error';mock.st.error="line:9: attempt to index a nil value (local 'q')";
  await p.waitForFunction(()=>/Fix this bug/.test(document.getElementById('ask').value),null,{timeout:12000});pass++;console.log('PASS late_bug | ask="'+await p.inputValue('#ask')+'"');await ctx.close()}
 await scene('no_fence',[{...reply(''),body:JSON.stringify({content:[{type:'text',text:'Sorry!'}],stop_reason:'end_turn'})},reply(good,'Here you go!')],{expect:/Here you go/});
 c=await scene('change',[reply(good),reply(good.replace('-- ','-- faster '),'Faster now!')],{expect:/Faster now/,full:true,then:async(p)=>{await p.fill('#ask','make it faster');await p.click('#chg');await p.waitForFunction(()=>!document.getElementById('new').disabled,null,{timeout:60000})}});
 console.log('   change msg starts: '+c[1].messages[0].content.slice(0,60).replace(/\n/g,' ')+' ... ends: '+c[1].messages[0].content.slice(-40).replace(/\n/g,' ')+' | system len '+c[1].system.length+' model '+c[1].model);
 // wifi settings
 {const ctx=await b.newContext({...devices['iPhone 13']}),p=await ctx.newPage();mock.log.length=0;await p.goto('http://127.0.0.1:8099/');await p.click('#scan');await p.waitForSelector('#nets:not([hidden])');await p.selectOption('#nets',{index:1});await p.fill('#pass','pa ss&word=1');await p.click('#join');await p.waitForTimeout(400);
  const w=mock.log.find(l=>l.startsWith('wifi '));console.log('WIFI '+decodeURIComponent(w.replace(/\+/g,' '))+' | '+(await p.textContent('#say')).slice(0,60));await p.screenshot({path:__dirname+'/out/page_wifi.png',fullPage:true});await ctx.close()}
 console.log(pass+' passed, '+fail+' failed');await b.close();srv.close()})();
