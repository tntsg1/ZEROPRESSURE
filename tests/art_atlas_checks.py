# Injects the tick-box UI into the atlas index.html (idempotent; replaces an older injection).
# Called by art_atlas_build.py.  Never touches 勾选.json (the user's ticks).
import os, re, sys
OUT = "E:/godot/zeropower/proofs/零件图鉴_20261111"
MARK = "<!--checks-->"
CSS = """<style>
figure{position:relative;user-select:none;-webkit-user-select:none;cursor:pointer}
.tk{position:absolute;top:6px;right:6px;width:30px;height:30px;background:#000a;border:2px solid #8a9096;border-radius:5px;display:flex;align-items:center;justify-content:center;z-index:2;pointer-events:none}
.tk:after{content:"";width:16px;height:9px;border-left:4px solid #111;border-bottom:4px solid #111;transform:rotate(-45deg) translate(1px,-2px);opacity:0}
.zm{position:absolute;top:6px;right:44px;width:30px;height:30px;background:#000a;border:2px solid #8a9096;border-radius:5px;color:#ddd;font-size:15px;line-height:26px;text-align:center;cursor:zoom-in;z-index:3}
.zm:hover{border-color:#fff;color:#fff}
figure:hover{border-color:#8a9096}
figure.wip:before{content:'返工中';position:absolute;left:6px;top:28px;z-index:3;background:#2a6fdb;color:#fff;font-size:12px;padding:1px 6px;border-radius:3px;pointer-events:none}
figure.ck{outline:3px solid #3ddc84;outline-offset:-3px;border-color:#3ddc84}figure.ck .tk{background:#3ddc84;border-color:#3ddc84}figure.ck .tk:after{opacity:1}
figure.pre{outline:3px dashed #ffd24a;outline-offset:-3px}body.dragging,body.dragging *{cursor:crosshair!important}
#sel{position:fixed;display:none;border:1px solid #ffd24a;background:#ffd24a22;z-index:20;pointer-events:none}
#bar{display:flex;flex-wrap:wrap;gap:8px 12px;align-items:center;width:100%;color:var(--dim)}#bar button{background:#16181b;border:1px solid var(--ln);color:var(--ink);padding:4px 10px;border-radius:4px;cursor:pointer}#bar b{color:#3ddc84}
#warn{display:none;width:100%;background:#4a2a10;color:#ffb070;padding:6px 10px;border-radius:4px}
</style>"""
JS = """<script>
(function(){
const LS='zp_atlas_checks',http=location.protocol.startsWith('http');let st={};
const figs=[...document.querySelectorAll('figure')];const idOf=f=>f.dataset.k,disp=f=>f.querySelector('figcaption b').textContent.trim();
const hd=document.querySelector('header');
hd.insertAdjacentHTML('beforeend','<div id="warn">请用 启动图鉴.bat 打开，勾选才能存到本地（当前只存在浏览器里）</div><div id="bar"><label><input id="ck_only" type="checkbox"> 只看已勾</label><span>已勾 <b id="ck_n">0</b> 个</span><button id="ck_clear">清空</button><button id="ck_exp">导出勾选</button><span id="ck_msg"></span><span>单击格子=勾选 · 双击或点放大镜=看大图 · Ctrl+拖动=框选勾上 · Ctrl+Shift+拖动=框选取消</span></div>');
document.body.insertAdjacentHTML('beforeend','<div id="sel"></div>');
const $=id=>document.getElementById(id);
if(!http)$('warn').style.display='block';
function clean(){const ok=new Set(figs.map(idOf));Object.keys(st).forEach(k=>{if(!ok.has(k))delete st[k]})}
function paint(){clean();figs.forEach(f=>f.classList.toggle('ck',!!st[idOf(f)]));$('ck_n').textContent=Object.keys(st).length;apply()}
function apply(){const v=document.getElementById('q').value.trim().toLowerCase(),o=document.getElementById('o').checked,k=$('ck_only').checked;
figs.forEach(f=>f.classList.toggle('hide',(v&&!f.dataset.s.includes(v))||(o&&!f.classList.contains('old'))||(k&&!f.classList.contains('ck'))))}
let pend=0,wip={};
function lsSave(){try{localStorage.setItem(LS,JSON.stringify(st))}catch(e){}}
function mark(){figs.forEach(f=>{const b=wip[idOf(f)];f.classList.toggle('wip',!!b);f.dataset.wip=b||''})}
function adopt(d){st=d.checks||{};wip=d['派工']||{};lsSave();paint();mark()}
function post(set,unset){lsSave();if(!http)return;pend++;
fetch('/checks',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({set,unset,ids:Object.fromEntries(set.map(k=>[k,idDisp[k]||'']))})}).then(r=>{if(!r.ok)throw 0;return r.json()}).then(d=>{pend--;$('ck_msg').textContent='已保存到 勾选.json';if(!pend)adopt(d)}).catch(()=>{pend--;$('ck_msg').textContent='服务器保存失败';$('warn').style.display='block'})}
const idDisp={};figs.forEach(f=>idDisp[idOf(f)]=disp(f));
const lb=document.getElementById('lb');
function big(f){document.getElementById('li').src=f.querySelector('img').src;document.getElementById('lc').innerHTML=f.querySelector('figcaption').innerHTML;lb.style.display='flex'}
let swallow=false;
figs.forEach(f=>{f.onclick=null;
const t=document.createElement('div');t.className='tk';f.appendChild(t);
const z=document.createElement('div');z.className='zm';z.textContent='\\u{1F50D}';z.title='看大图';z.onclick=e=>{e.stopPropagation();big(f)};z.onmousedown=e=>e.stopPropagation();f.appendChild(z);
f.addEventListener('click',e=>{if(swallow||e.ctrlKey)return;const i=idOf(f);if(st[i]){delete st[i];paint();post([],[i])}else{st[i]=true;paint();post([i],[])}});
f.addEventListener('dblclick',e=>{if(!e.ctrlKey)big(f)})});
// Ctrl+drag marquee: Ctrl = tick everything swept, Ctrl+Shift = untick
let drag=null,last={x:0,y:0},raf=0;
function rectNow(){const x0=drag.x0-scrollX,y0=drag.y0-scrollY;return{l:Math.min(x0,last.x),t:Math.min(y0,last.y),r:Math.max(x0,last.x),b:Math.max(y0,last.y)}}
function hits(){const r=rectNow();return figs.filter(f=>{if(f.classList.contains('hide'))return false;const b=f.getBoundingClientRect();return b.right>=r.l&&b.left<=r.r&&b.bottom>=r.t&&b.top<=r.b})}
function draw(){if(!drag)return;const r=rectNow(),s=$('sel');s.style.display='block';s.style.left=r.l+'px';s.style.top=r.t+'px';s.style.width=(r.r-r.l)+'px';s.style.height=(r.b-r.t)+'px';
const h=new Set(hits());figs.forEach(f=>f.classList.toggle('pre',h.has(f)))}
function tick(){if(!drag)return;const m=70;let d=0;if(last.y<m+60)d=-Math.ceil((m+60-last.y)/4);else if(last.y>innerHeight-m)d=Math.ceil((last.y-(innerHeight-m))/4);if(d)scrollBy(0,Math.max(-40,Math.min(40,d)));draw()}
document.addEventListener('mousedown',e=>{if(e.button!==0||!e.ctrlKey||lb.style.display==='flex'||e.target.closest('header'))return;e.preventDefault();
drag={x0:e.clientX+scrollX,y0:e.clientY+scrollY,untick:e.shiftKey};last={x:e.clientX,y:e.clientY};document.body.classList.add('dragging');draw();raf=setInterval(tick,16)},true);
document.addEventListener('mousemove',e=>{if(!drag)return;last={x:e.clientX,y:e.clientY};drag.untick=e.shiftKey;draw()});
window.addEventListener('mouseup',e=>{if(!drag)return;clearInterval(raf);const hs=hits(),u=drag.untick;drag=null;document.body.classList.remove('dragging');$('sel').style.display='none';figs.forEach(f=>f.classList.remove('pre'));
const ks=hs.map(idOf).filter(k=>u?st[k]:!st[k]);ks.forEach(k=>{if(u)delete st[k];else st[k]=true});paint();if(ks.length)u?post([],ks):post(ks,[]);swallow=true;setTimeout(()=>swallow=false,0)},true);
window.addEventListener('blur',()=>{if(drag){clearInterval(raf);drag=null;$('sel').style.display='none';figs.forEach(f=>f.classList.remove('pre'))}});
$('ck_only').onchange=apply;document.getElementById('q').addEventListener('input',apply);document.getElementById('o').addEventListener('change',apply);
$('ck_clear').onclick=()=>{if(Object.keys(st).length&&confirm('清空全部勾选？')){const ks=Object.keys(st);st={};paint();post([],ks)}};
$('ck_exp').onclick=()=>{const b=new Blob([JSON.stringify({checks:st,'显示编号':Object.fromEntries(figs.filter(f=>st[idOf(f)]).map(f=>[idOf(f),disp(f)])),'更新时间':new Date().toLocaleString()},null,1)],{type:'application/json'});const a=document.createElement('a');a.href=URL.createObjectURL(b);a.download='勾选.json';a.click()};
if(!http){try{st=JSON.parse(localStorage.getItem(LS)||'{}')}catch(e){st={}}}
paint();
if(http){const pull=()=>{if(pend)return;fetch('/checks',{cache:'no-store'}).then(r=>r.json()).then(d=>{if(pend)return;const a=JSON.stringify([d.checks,d['派工']]),b=JSON.stringify([st,wip]);if(a!==b)adopt(d);else mark()}).catch(()=>{$('warn').style.display='block'})};pull();setInterval(pull,5000)}
})();
</script>"""


def inject():
    p = OUT + "/index.html"
    s = open(p, encoding="utf8").read()
    if MARK in s:  # replace an older injection
        s = re.sub(re.escape(MARK) + r"<style>.*?</style>", "", s, flags=re.S)
        s = re.sub(r"<script>\n\(function\(\)\{\nconst LS=.*?</script>", "", s, flags=re.S)
    s = s.replace("</head>", MARK + CSS + "</head>", 1).replace("</body>", JS + "</body>", 1)
    open(p, "w", encoding="utf8").write(s)


if __name__ == "__main__":
    inject()
