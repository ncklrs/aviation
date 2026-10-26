// node tools/test_reveal.js [overhead.html] : checks revealPick() against tools/reveal_cases.json
const fs=require('fs'), path=require('path'), src=fs.readFileSync(process.argv[2]||path.join(__dirname,'../overhead.html'),'utf8');
const m=src.match(/function revealPick\([\s\S]*?\n}\n/); if(!m){ console.error('revealPick not found'); process.exit(1); }
const revealPick=new Function('RV_MAX_AGE','RV_BATCH',m[0]+'return revealPick;')(1800,3);
const C=JSON.parse(fs.readFileSync(path.join(__dirname,'reveal_cases.json'))).cases; let bad=0;
for(const c of C){ const seen=c.seen.slice(), got=revealPick(c.unlocks,seen,c.now).map(u=>u.t);
  const ok=JSON.stringify(got)===JSON.stringify(c.want); if(!ok) bad++; console.log((ok?'PASS ':'FAIL ')+c.name+(ok?'':` got ${got} want ${c.want}`)); }
// marking: a second call with the updated seen list returns nothing
const s=[], u=[{t:'V22',at:9400}]; revealPick(u,s,10000); if(revealPick(u,s,10000).length){ bad++; console.log('FAIL second call'); } else console.log('PASS second call is empty');
if(bad){ console.error(bad+' failed'); process.exit(1); } console.log('reveal OK');
