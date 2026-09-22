const {test}=require('node:test'),assert=require('node:assert/strict');
const {variant,paths}=require('./support/pallet_atlas_provenance.cjs');
test('variant follows the actual compact contract, not the archived directory name',()=>{
  assert.equal(variant('pallet_town',''),'original');
  assert.equal(variant('pallet_town','metadata/tiled_compact_atlas_version = 1'),'compact');
  assert.equal(variant('res://generated/tiled_visuals/pallet_town_compact/pallet_town_compact.visual.tscn',''),'compact');
});
test('cached-only atlas paths follow saved ownership for embedded and external textures',()=>{
  const scene='generated/visual.tscn',inline='[sub_resource type="PortableCompressedTexture2D" id="Atlas"]';
  const external='[ext_resource type="Texture2D" path="res://generated/assets/new.texture.res" id="1"]';
  assert.deepEqual(paths(inline,external,scene),['res://generated/visual.tscn::Atlas']);
  assert.deepEqual(paths('',external,scene),['res://generated/assets/new.texture.res']);
  assert.deepEqual(paths('',inline,scene),['res://generated/visual.tileset.tres::Atlas']);
});
