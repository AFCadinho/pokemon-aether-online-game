const assert=require('node:assert/strict');
const {execFileSync}=require('node:child_process');
function validate(text) {
  assert.deepEqual(text.trim().split('\n'),[
    'pokeaether-slot-c|tmpfs','pokeaether-slot-c|','pokeaether-slot-c|'
  ],'Disposable slot-C runtime disappeared; stop all browser actions');
}
function attest() {
  const text=execFileSync('docker',['inspect','--format',
    '{{index .Config.Labels "com.docker.compose.project"}}|{{if index .HostConfig.Tmpfs "/var/lib/postgresql/data"}}tmpfs{{end}}',
    'pao-postgres','pao-account-service','pao-battle-orchestrator'],{encoding:'utf8',stdio:['ignore','pipe','ignore'],timeout:5000});
  validate(text);
}
module.exports={validate,attest};
