// Pure text helpers: no Godot/resource loads or browser actions.
function variant(gameScene,originalTileSet) {
  return gameScene.includes('res://generated/tiled_visuals/pallet_town_compact/pallet_town_compact.visual.tscn') ||
    originalTileSet.includes('metadata/tiled_compact_atlas_version = 1') ? 'compact' : 'original';
}
function paths(sceneText,tileSetText,scenePath) {
  const embedded=text=>[...text.matchAll(/^\[sub_resource type="PortableCompressedTexture2D" id="([a-zA-Z0-9_]+)"\]$/gm)].map(x=>x[1]);
  const inline=embedded(sceneText);
  if(inline.length) return inline.map(id=>'res://'+scenePath+'::'+id);
  const external=[...tileSetText.matchAll(/^\[ext_resource type="(?:Texture2D|PortableCompressedTexture2D)" path="([^"]+\.texture\.res)"/gm)].map(x=>x[1]);
  if(external.length) return [...new Set(external)];
  return embedded(tileSetText).map(id=>'res://'+scenePath.replace(/\.tscn$/,'.tileset.tres')+'::'+id);
}
module.exports={variant,paths};
