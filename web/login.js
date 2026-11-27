'use strict';
const $=id=>document.getElementById(id);
let mode='login',config={},account=null,pending=false,showingRecovery=false;
async function api(path,body){
 const response=await fetch('/api/v1/auth/'+path+'/',{method:body===undefined?'GET':'POST',credentials:'same-origin',headers:{'Content-Type':'application/json','X-CP-Request':'1'},body:body===undefined?undefined:JSON.stringify(body)});
 const data=await response.json();if(!response.ok)throw new Error(data.error||'요청에 실패했어요. 잠시 후 다시 시도해 주세요.');return data;
}
function message(text){$('message').textContent=text;}
function renderAccount(){
 $('signed-in').hidden=!account||showingRecovery;$('signed-out').hidden=!!account||showingRecovery;
 if(account){$('welcome').textContent='다시 오셨네요, '+account.username+'님';$('link-box').hidden=account.google_linked;$('linked').hidden=!account.google_linked;}
}
function setMode(next){mode=next;for(const value of ['login','register','recover'])$(value+'-tab').classList.toggle('active',value===mode);$('recovery-field').hidden=mode!=='recover';$('recovery').required=mode==='recover';$('password').autocomplete=mode==='login'?'current-password':'new-password';$('password').minLength=mode==='login'?1:12;$('password-label').textContent=mode==='recover'?'새 비밀번호':'비밀번호';$('submit').firstChild.textContent=mode==='register'?'게스트 계정 만들기 ':mode==='recover'?'계정 복구하기 ':'캠프로 들어가기 ';message('');}
for(const value of ['login','register','recover'])$(value+'-tab').onclick=()=>setMode(value);
$('form').onsubmit=async event=>{
 event.preventDefault();if(pending)return;pending=true;$('submit').disabled=true;message('확인하고 있어요…');
 try{const body={username:$('username').value,password:$('password').value};if(mode==='recover')body.recovery_code=$('recovery').value;const data=await api(mode,body);$('password').value='';$('recovery').value='';account=data;
  if(data.recovery_code){showingRecovery=true;$('recovery-code').textContent=data.recovery_code;$('recovery-result').hidden=false;renderAccount();message('복구 코드를 비밀번호와 별도로 안전한 곳에 보관해 주세요.');}
  else location.assign('/play.html');
 }catch(e){message(e.message);}finally{pending=false;$('submit').disabled=false;}
};
$('saved-code').onclick=()=>{showingRecovery=false;$('recovery-code').textContent='';$('recovery-result').hidden=true;location.assign('/play.html');};
$('logout').onclick=async()=>{try{await api('logout',{});account=null;renderAccount();await setupGoogle();message('로그아웃했어요.');}catch(e){message(e.message);}};
$('time').onclick=()=>{const night=document.querySelector('.landscape').classList.toggle('night');$('time').textContent=night?'낮 풍경 보기':'밤 풍경 보기';};
function renderGoogleButtons(){
 if(!window.google?.accounts?.id||!config.google_client_id)return;
 for(const id of ['google-button','google-link-button']){
  if(!$(id).offsetWidth)continue;
  $(id).replaceChildren();google.accounts.id.renderButton($(id),{theme:'outline',size:'large',text:account?'continue_with':'signin_with',width:Math.max(200,Math.min(350,$(id).clientWidth)),locale:'ko'});
 }
}
let resizeTimer;window.addEventListener('resize',()=>{clearTimeout(resizeTimer);resizeTimer=setTimeout(renderGoogleButtons,150);});
async function setupGoogle(){
 config=await api('config');
 if(!config.google_client_id){$('google-status').textContent='Google 로그인은 설정 준비 중이에요. 게스트 계정을 이용해 주세요.';return;}
 let count=0;while(!window.google?.accounts?.id&&count++<60)await new Promise(resolve=>setTimeout(resolve,100));
 if(!window.google?.accounts?.id){$('google-status').textContent='Google 로그인 버튼을 불러오지 못했어요. 네트워크를 확인해 주세요.';return;}
 google.accounts.id.initialize({client_id:config.google_client_id,nonce:config.nonce,auto_select:false,callback:async response=>{
  if(pending)return;pending=true;message('Google 계정을 확인하고 있어요…');
  try{const linking=!!account;account=await api(linking?'google/link':'google',{credential:response.credential});renderAccount();if(!linking)location.assign('/play.html');else message('Google 계정이 연결됐어요.');}
  catch(e){message(e.message);}finally{pending=false;await setupGoogle();}
 }});
 renderGoogleButtons();
 $('google-status').textContent='Google 로그인 또는 게스트 계정 중 선택해 주세요.';
}
(async()=>{try{account=await api('me');}catch(e){}renderAccount();try{await setupGoogle();}catch(e){message('서버에 연결하지 못했어요. 새로고침해 주세요.');}})();

// 짧은 이동 체험은 선택 사항이며 시작 버튼을 잠그지 않는다.
if(new URLSearchParams(location.search).has('account'))document.body.classList.remove('intro-mode');
$('start-game').onclick=()=>{if(account){location.assign('/play.html');return;}document.body.classList.remove('intro-mode');requestAnimationFrame(renderGoogleButtons);};
$('back-intro').onclick=()=>{document.body.classList.add('intro-mode');};
const camper=$('intro-camper'),field=$('intro-field');
let camperX=.53,camperY=.66,targetX=camperX,targetY=camperY,lastFrame=0,walkClock=0;
const held=new Set();
field.onpointerup=event=>{const rect=field.getBoundingClientRect();targetX=Math.max(.18,Math.min(.82,(event.clientX-rect.left)/rect.width));targetY=Math.max(.55,Math.min(.73,(event.clientY-rect.top)/rect.height));field.focus();};
window.addEventListener('keydown',event=>{if(document.body.classList.contains('intro-mode')&&['ArrowLeft','ArrowRight','ArrowUp','ArrowDown','a','d','w','s'].includes(event.key)){held.add(event.key);event.preventDefault();}});
window.addEventListener('keyup',event=>held.delete(event.key));window.addEventListener('blur',()=>held.clear());
function introFrame(now){
 const delta=Math.min(.05,(now-lastFrame)/1000||0);lastFrame=now;
 if(document.body.classList.contains('intro-mode')&&!document.hidden&&document.hasFocus()){
  let dx=(held.has('d')||held.has('ArrowRight')?1:0)-(held.has('a')||held.has('ArrowLeft')?1:0),dy=(held.has('s')||held.has('ArrowDown')?1:0)-(held.has('w')||held.has('ArrowUp')?1:0);
  let pad=null;try{pad=Array.from(navigator.getGamepads?.()||[]).find(Boolean);}catch(e){}if(pad){if(Math.abs(pad.axes[0]||0)>.2)dx+=pad.axes[0];if(Math.abs(pad.axes[1]||0)>.2)dy+=pad.axes[1];if(pad.buttons[0]?.pressed&&!padStartHeld){padStartHeld=true;$('start-game').click();}if(!pad.buttons[0]?.pressed)padStartHeld=false;}
  if(dx||dy){targetX=Math.max(.18,Math.min(.82,camperX+dx*.15*delta));targetY=Math.max(.55,Math.min(.73,camperY+dy*.10*delta));}
  const distance=Math.hypot(targetX-camperX,targetY-camperY),moving=distance>.001,step=Math.min(distance,.12*delta);
  if(moving){const direction=targetX-camperX;camperX+=(targetX-camperX)/distance*step;camperY+=(targetY-camperY)/distance*step;camper.style.transform='translate(-50%,-100%) scaleX('+(direction<0?-1:1)+')';}
  walkClock+=delta;const frame=moving?Math.floor(walkClock*7)%4:(walkClock%3.4<2.5?0:walkClock%3.4<2.8?1:walkClock%3.4<3?2:3);
  camper.style.left=camperX*100+'%';camper.style.top=camperY*100+'%';camper.style.backgroundPosition=frame*100/3+'% '+(moving?100:0)+'%';
 }
 requestAnimationFrame(introFrame);
}
let padStartHeld=false;requestAnimationFrame(introFrame);
