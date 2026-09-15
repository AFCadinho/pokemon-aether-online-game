const {test}=require('node:test'),assert=require('node:assert/strict');
const {validate}=require('./support/disposable_runtime_guard.cjs');
const valid='pokeaether-slot-c|tmpfs\npokeaether-slot-c|\npokeaether-slot-c|\n';
test('accept only the attested disposable services',()=>validate(valid));
test('reject normal stack, missing services and persistent database',()=>{
  for(const invalid of [valid.replaceAll('pokeaether-slot-c','pokemon-aether-backend'),
    valid.replace('tmpfs',''),valid.split('\n').slice(0,2).join('\n'),
    valid.replace('pokeaether-slot-c|\n','pokemon-aether-backend|\n')]) assert.throws(()=>validate(invalid));
});
