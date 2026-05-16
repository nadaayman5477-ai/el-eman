
const demo=document.getElementById('demoUsers');
EMPLOYEES.slice(0,8).forEach(e=>{const b=document.createElement('button');b.textContent=e[1];b.onclick=()=>{username.value=e[3];password.value=e[4]};demo.appendChild(b)});
loginForm.addEventListener('submit',e=>{e.preventDefault();const u=username.value.trim(),p=password.value;const emp=EMPLOYEES.find(x=>x[3]===u||x[2]===u);if(!emp||emp[4]!==p){alert('بيانات الدخول غير صحيحة');return}localStorage.setItem('aleman_user',JSON.stringify({role:emp[0],title:emp[1],name:emp[2],email:emp[3],permissions:emp[5]}));location.href='dashboard.html'});
