import io
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from PIL import Image

import import_mega_champions_sprite_assets as importer


class ImportMegaChampionsSpriteAssetsTest(unittest.TestCase):
    def test_mapping_set_covers_missing_and_corrected_forms(self) -> None:
        mappings = {
            mapping.catalog_entry_id: mapping.source_stem
            for mapping in importer.FORM_ASSET_MAPPINGS
        }

        self.assertEqual(len(mappings), 15)
        self.assertEqual(mappings["absol-mega-z"], "ABSOL_2")
        self.assertEqual(mappings["floette-mega"], "FLOETTE_6")
        self.assertEqual(mappings["greninja-mega"], "GRENINJA_3")
        self.assertEqual(mappings["magearna-mega"], "MAGEARNA_2")
        self.assertEqual(mappings["magearna-original-mega"], "MAGEARNA_3")
        self.assertEqual(mappings["meowstic-m-mega"], "MEOWSTIC_2")
        self.assertEqual(mappings["meowstic-f-mega"], "MEOWSTIC_3")
        self.assertEqual(mappings["zygarde-mega"], "ZYGARDE_4")

    def test_full_and_shiny_backfill_mappings_cover_all_catalog_forms(self) -> None:
        full_ids = {
            mapping.catalog_entry_id
            for mapping in importer.FORM_ASSET_MAPPINGS
        }
        backfill_ids = {
            mapping.catalog_entry_id
            for mapping in importer.SHINY_HOME_BACKFILL_MAPPINGS
        }
        catalog = json.loads(
            (importer.PROJECT_ROOT / "data" / "mega_champions_catalog.generated.json").read_text()
        )
        catalog_ids = {form["catalogEntryId"] for form in catalog["forms"]}

        self.assertEqual(len(backfill_ids), 34)
        self.assertFalse(full_ids & backfill_ids)
        self.assertEqual(full_ids | backfill_ids, catalog_ids)
        meganium = next(
            mapping
            for mapping in importer.SHINY_HOME_BACKFILL_MAPPINGS
            if mapping.catalog_entry_id == "meganium-mega"
        )
        self.assertEqual(meganium.source_stem, "MEGANIUM_1")

    def test_expected_outputs_use_one_battle_frame_and_first_icon_frame(self) -> None:
        with TemporaryDirectory() as source_dir, TemporaryDirectory() as project_dir:
            source_root = Path(source_dir)
            project_root = Path(project_dir)
            graphics_root = source_root / "Graphics" / "Pokemon"
            for mapping_index, mapping in enumerate(importer.FORM_ASSET_MAPPINGS):
                color = (mapping_index + 1, 20, 30, 255)
                for source_folder, _output_folder in importer.BATTLE_ASSETS:
                    path = graphics_root / source_folder / f"{mapping.source_stem}.png"
                    path.parent.mkdir(parents=True, exist_ok=True)
                    Image.new("RGBA", (12, 12), color).save(path)
                for source_folder, _output_folder in importer.ICON_ASSETS:
                    path = graphics_root / source_folder / f"{mapping.source_stem}.png"
                    path.parent.mkdir(parents=True, exist_ok=True)
                    icon = Image.new("RGBA", (24, 12), (0, 0, 0, 0))
                    icon.paste(color, (0, 0, 12, 12))
                    icon.paste((200, 210, 220, 255), (12, 0, 24, 12))
                    icon.save(path)

            for mapping_index, mapping in enumerate(importer.SHINY_HOME_BACKFILL_MAPPINGS):
                path = graphics_root / "Icons shiny" / f"{mapping.source_stem}.png"
                path.parent.mkdir(parents=True, exist_ok=True)
                color = (mapping_index + 101, 40, 50, 255)
                icon = Image.new("RGBA", (24, 12), (0, 0, 0, 0))
                icon.paste(color, (0, 0, 12, 12))
                icon.paste((210, 220, 230, 255), (12, 0, 24, 12))
                icon.save(path)

            outputs, manifest = importer.expected_outputs(source_root, project_root)
            self.assertEqual(manifest["mappingCount"], 15)
            self.assertEqual(manifest["shinyHomeBackfillCount"], 34)
            self.assertEqual(len(outputs), 185)

            absol = importer.FORM_ASSET_MAPPINGS[0]
            metadata_path = (
                project_root
                / "assets/sprites/pokemon/front"
                / absol.catalog_entry_id
                / "animation.json"
            )
            metadata = json.loads(outputs[metadata_path])
            self.assertEqual(metadata["source_frame_count"], 1)
            self.assertEqual(metadata["frame_width"], 12)
            self.assertEqual(metadata["frames"], [{
                "x": 0,
                "y": 0,
                "w": 12,
                "h": 12,
                "duration": 1.0,
            }])

            icon_path = (
                project_root
                / "assets/sprites/pokemon/pokemon_home"
                / f"{absol.showdown_species_name}.png"
            )
            with Image.open(io.BytesIO(outputs[icon_path])) as icon:
                self.assertEqual(icon.size, (12, 12))
                self.assertEqual(icon.getpixel((0, 0)), (1, 20, 30, 255))

            meganium_path = (
                project_root
                / "assets/sprites/pokemon/pokemon_home_shiny"
                / "Meganium-Mega.png"
            )
            with Image.open(io.BytesIO(outputs[meganium_path])) as icon:
                self.assertEqual(icon.size, (12, 12))
                self.assertEqual(icon.getpixel((0, 0)), (125, 40, 50, 255))

            for path, content in outputs.items():
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(content)
            importer.check_outputs(outputs)


if __name__ == "__main__":
    unittest.main()
