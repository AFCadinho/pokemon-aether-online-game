"""Reject mistaken species/gender mappings before an alternate-ID Mega import."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import catalog_mega_3d_production as production


class SourceMappingTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.icon = self.root / "pm0722/pm0722_51_00/icon/normal.png"
        self.icon.parent.mkdir(parents=True)
        self.icon.write_bytes(b"hash-bound identity evidence")
        self.audit = self.root / "catalog_mega_25_source_audit.json"
        self.intake = self.root / "intake.json"
        self.intake.write_text(json.dumps({"mega_model_source_archive_sha256": "archive"}))
        self.audit.write_text(json.dumps({
            "source_archive": {"sha256": "archive"},
            "entries": [{"showdown_id": "chesnaughtmega", "species": "chesnaught-mega",
                "pokedex_number": 652, "source_resource_id": "pm0722_51_00",
                "source_mapping_status": "candidate_identity_match",
                "dev_number_mapping_evidence": {"developer_number": 722}}],
            "source_resources": {"pm0722_51_00": {"normal_and_shiny_icon_evidence": [
                {"archive_member": str(self.icon.relative_to(self.root)),
                 "sha256": production.sha(self.icon)}]}}}))
        self.row = {"showdown_id": "chesnaughtmega", "name": "chesnaught-mega",
                    "pokedex_number": 652, "source_resource_id": "pm0722_51_00",
                    "source_mapping_audit": {"path": self.audit.name,
                                             "sha256": production.sha(self.audit)}}
        self.addCleanup(patch.stopall)
        patch.object(production, "HERE", self.root).start()
        patch.object(production, "INTAKE", self.intake).start()

    def test_audited_developer_number_stays_separate_from_dex(self):
        self.assertEqual(production.source_number(self.row, self.root), 722)
        self.assertEqual(self.row["pokedex_number"], 652)

    def test_legacy_matching_dex_requires_no_alternate_audit(self):
        row = {"pokedex_number": 3, "source_resource_id": "pm0003_51_00"}
        self.assertEqual(production.source_number(row, self.root), 3)

    def test_wrong_form_species_resource_or_missing_audit_rejected(self):
        changes = [{"showdown_id": "meowsticfmega"}, {"name": "delphox-mega"},
                   {"pokedex_number": 655}, {"source_resource_id": "pm0719_51_00"},
                   {"source_mapping_audit": None}, {"source_resource_id": "../pm0722_51_00"}]
        for change in changes:
            with self.subTest(change=change), self.assertRaises(ValueError):
                production.source_number({**copy.deepcopy(self.row), **change}, self.root)

    def test_changed_icon_rejected(self):
        self.icon.write_bytes(b"different species icon")
        with self.assertRaises(ValueError):
            production.source_number(self.row, self.root)

    def test_changed_audit_rejected(self):
        self.audit.write_text(self.audit.read_text() + "\n")
        with self.assertRaises(ValueError):
            production.source_number(self.row, self.root)

    def test_unconfirmed_gender_rejected_even_with_valid_audit_hash(self):
        audit = json.loads(self.audit.read_text())
        audit["entries"][0]["source_mapping_status"] = "gender_confirmation_pending"
        self.audit.write_text(json.dumps(audit))
        self.row["source_mapping_audit"]["sha256"] = production.sha(self.audit)
        with self.assertRaises(ValueError):
            production.source_number(self.row, self.root)


class SharedZygardeMaterialTests(unittest.TestCase):
    def setUp(self):
        self.row = {"showdown_id": "zygardemega", "source_resource_id": "pm0770_51_00"}
        self.document = {
            "materials": [{"name": "body_e", "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}}},
                          {"name": "body_e", "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}}}],
            "meshes": [{"name": "pm0770_51_00_energy_mesh_shape", "primitives": [{"material": 0}]},
                       {"name": "pm0770_51_00_head_mesh_shape", "primitives": [{"material": 1}]}],
            "textures": [{"source": 0}], "images": [{"name": "pm0770_51_00_body_e_alb.png"}]}
        self.addCleanup(patch.stopall)
        patch.object(production, "chunks", return_value=(self.document, b"")).start()
        patch.object(production, "inspect_materials", return_value=[
            {"name": "body_e", "textures": {"BaseColorMap": "pm0770_51_00_body_e_alb.bntx"}}]).start()

    def test_shared_native_head_and_energy_surface_allowed(self):
        self.assertEqual(production.material_aliases(self.row, Path("raw"), Path("table")),
                         {"body_e": "body_e"})

    def test_wrong_mesh_or_texture_still_rejected(self):
        for field in ["mesh", "image"]:
            with self.subTest(field=field):
                original = copy.deepcopy(self.document)
                if field == "mesh":
                    self.document["meshes"][0]["name"] = "unrelated_body"
                else:
                    self.document["images"][0]["name"] = "wrong_albedo"
                with self.assertRaises(ValueError):
                    production.material_aliases(self.row, Path("raw"), Path("table"))
                self.document.clear()
                self.document.update(original)

    def test_alias_does_not_apply_to_other_species(self):
        self.assertEqual(production.material_aliases({**self.row, "showdown_id": "delphoxmega"},
                                                   Path("raw"), Path("table")), {})


class SharedTextureDependencyTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.row = {"source_resource_id": "pm0882_52_00"}
        self.target = self.root / "pm0882/pm0882_52_00"
        self.target.mkdir(parents=True)
        self.origin = self.root / "pm0882/pm0882_51_00/pm0882_51_00_body_a_alb.png"
        self.origin.parent.mkdir(parents=True)
        self.origin.write_bytes(b"native shared texture")
        self.material = {"textures": {"BaseColorMap": "pm0882_51_00_body_a_alb.bntx"}}
        self.addCleanup(patch.stopall)
        patch.object(production, "inspect_materials", return_value=[self.material]).start()

    def test_shared_texture_staged_and_tampering_rejected(self):
        receipt = production.prepare_source_dependencies(self.row, self.root)
        self.assertEqual(receipt["count"], 1)
        target = self.target / self.origin.name
        self.assertEqual(target.read_bytes(), self.origin.read_bytes())
        target.write_bytes(b"incorrect colour texture")
        with self.assertRaises(ValueError):
            production.prepare_source_dependencies(self.row, self.root)

    def test_cross_species_dependency_rejected(self):
        self.material["textures"]["BaseColorMap"] = "pm0003_51_00_body_alb.bntx"
        with self.assertRaises(ValueError):
            production.prepare_source_dependencies(self.row, self.root)
        self.assertEqual(list(self.target.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
