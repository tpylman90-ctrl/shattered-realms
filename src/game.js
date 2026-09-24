const panels={world:document.querySelector('#worldView'),territory:document.querySelector('#territoryView'),dungeon:document.querySelector('#dungeonView')};
const backBtn=document.querySelector('#backBtn');
const board=document.querySelector('#territoryBoard');
const hero=document.querySelector('#hero');
const fog=document.querySelector('.fog-layer');
const city=document.querySelector('#city');
const dungeon=document.querySelector('#dungeon');
const beast=document.querySelector('#beast');
const control=document.querySelector('#controlValue');
let explored=0;

function show(name){
  Object.values(panels).forEach(p=>p.classList.remove('active'));
  panels[name].classList.add('active');
  backBtn.classList.toggle('hidden',name==='world');
}

document.querySelector('.r1').addEventListener('click',()=>show('territory'));
backBtn.addEventListener('click',()=>show('world'));
document.querySelector('#leaveDungeon').addEventListener('click',()=>show('territory'));
dungeon.addEventListener('click',()=>show('dungeon'));

board.addEventListener('click',e=>{
  if(e.target.closest('.poi')) return;
  const rect=board.getBoundingClientRect();
  const x=((e.clientX-rect.left)/rect.width)*100;
  const y=((e.clientY-rect.top)/rect.height)*100;
  hero.style.left=x+'%';
  hero.style.top=y+'%';
  fog.style.background=`radial-gradient(circle at ${x}% ${y}%, transparent 0 110px, #05090adf 190px, #020405f5 360px)`;
  explored=Math.min(100,explored+7);
  control.textContent=Math.floor(explored*.35)+'%';
  revealByDistance(x,y,city,68,27);
  revealByDistance(x,y,dungeon,44,60);
  revealByDistance(x,y,beast,76,72);
});

function revealByDistance(x,y,node,tx,ty){
  if(Math.hypot(x-tx,y-ty)<18) node.classList.add('revealed');
}
