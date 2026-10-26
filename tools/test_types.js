// Type-code -> drawing-class regression test. Usage: node tools/test_types.js [overhead.html]
const fs=require('fs'), src=fs.readFileSync(process.argv[2]||__dirname+'/../overhead.html','utf8');
const grab=(a,b)=>{ const i=src.indexOf(a), j=src.indexOf(b,i); if(i<0||j<0) throw Error('missing '+a); return src.slice(i,j); };
const code=grab('const TYPES = [','function svg(')+'\n'+grab('const WIDE=','\n')+'\nmodule.exports=shapeFor;';
const m={exports:{}}; new Function('module',code)(m); const shapeFor=m.exports;
const want={GA8C:'bizjet',GA7C:'bizjet',GA6C:'bizjet',GA5C:'bizjet',GLF6:'bizjet',GLF5:'bizjet',GLF4:'bizjet',G800:'bizjet',G650:'bizjet',
  GLEX:'bizjet',GL5T:'bizjet',GL7T:'bizjet',FA7X:'bizjet',FA8X:'bizjet',F900:'bizjet',F2TH:'bizjet',CL60:'bizjet',CL35:'bizjet',
  LJ35:'bizjet-light',LJ45:'bizjet-light',LJ60:'bizjet-light',LJ75:'bizjet-light',C68A:'bizjet-light',E55P:'bizjet-light',
  B38M:'b737',A320:'a320',B789:'widebody',CRJ9:'regional',C172:'cessna',B52:'widebody'};
let bad=0;
for(const [t,c] of Object.entries(want)){ const g=shapeFor({t,category:'A3'}); console.log((g===c?'PASS':'FAIL')+'  '+t.padEnd(5)+' -> '+g); if(g!==c) bad++; }
const d=shapeFor({t:'ZZZZ',desc:'GULFSTREAM G-8 G800',category:'A3'}); console.log((d==='bizjet'?'PASS':'FAIL')+'  desc "GULFSTREAM G-8 G800" (unknown code) -> '+d); if(d!=='bizjet') bad++;
if(bad){ console.error(bad+' FAIL'); process.exit(1); } console.log('types OK');
