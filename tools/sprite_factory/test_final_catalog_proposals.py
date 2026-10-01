"""Focused invariants for proposal colour/eye data, not visual approval."""
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from PIL import Image, ImageDraw
from catalog_explicit_hsv_shiny import transfer
from catalog_reference_shiny_proposals import palette
from catalog_sleep_atlas_proposals import closed_cell
from catalog_remaining_final_batch import owned_action_names


class ProposalSafetyTests(unittest.TestCase):
    def test_hue_change_preserves_alpha_and_unmatched_colours(self):
        source=Image.new('RGBA',(3,1))
        source.putdata([(180,60,200,255),(30,210,40,127),(180,60,200,0)])
        changed=transfer(source,[(.7,.9,.3,.5)])
        self.assertEqual(source.getchannel('A').tobytes(),changed.getchannel('A').tobytes())
        self.assertNotEqual(source.getpixel((0,0)),changed.getpixel((0,0)))
        self.assertEqual(source.getpixel((1,0)),changed.getpixel((1,0)))
        self.assertEqual(source.getpixel((2,0)),changed.getpixel((2,0)))

    def test_rig_action_selection_excludes_material_and_other_form_actions(self):
        names=['CusAnimMat_Eye|pm0165_00_00_ba10_waitA01|Base Layer',
               'pm0165_00_00|pm0165_00_00_ba10_waitA01|Base Layer',
               'pm0165_01_00|pm0165_00_00_ba10_waitA01|Base Layer']
        self.assertEqual(owned_action_names({'rig_name':'pm0165_00_00','action_names':names}),[names[1]])

    def test_dark_palette_handles_chromatic_black_without_changing_alpha(self):
        source=Image.new('RGBA',(1,1),(15,9,9,127))
        output=transfer(source,[('dark-to-white',0,0,0)])
        self.assertEqual(output.getpixel((0,0))[3],127)
        self.assertGreater(output.getpixel((0,0))[0],240)

    def test_value_interval_preserves_bright_leg_colour(self):
        source=Image.new('RGBA',(2,1));source.putdata([(165,115,77,255),(233,174,95,255)])
        output=transfer(source,[(.02,.18,.34,.75,0,.78)])
        self.assertNotEqual(output.getpixel((0,0)),source.getpixel((0,0)))
        self.assertEqual(output.getpixel((1,0)),source.getpixel((1,0)))

    def test_invalid_hue_rule_cannot_generate_pixels(self):
        for rule in [(1,.4,.3,.5),(.7,.9,float('nan'),.5),(.7,.9,.3,2)]:
            with self.assertRaises(ValueError):transfer(Image.new('RGBA',(2,2),'purple'),[rule])

    def test_different_reference_poses_are_held(self):
        with tempfile.TemporaryDirectory() as temp:
            a,b=[Path(temp)/name for name in ['normal.png','shiny.png']]
            Image.new('RGBA',(64,64),'purple').save(a)
            triangle=Image.new('RGBA',(64,64))
            ImageDraw.Draw(triangle).polygon([(0,63),(32,0),(63,63)],fill='green')
            triangle.save(b)
            with patch('catalog_reference_shiny_proposals.references',return_value=[a,b]):
                with self.assertRaisesRegex(ValueError,'registration is ambiguous'):palette('fixture')

    def test_transparent_cell_is_not_a_closed_eye(self):
        self.assertIsNone(closed_cell(Image.new('RGBA',(32,32),(0,0,0,0))))

    def test_round_pupil_is_not_a_closed_eyelid(self):
        eye=Image.new('RGBA',(32,32),'white')
        ImageDraw.Draw(eye).ellipse((10,9,21,22),fill='black')
        self.assertIsNone(closed_cell(eye))


if __name__=='__main__':unittest.main()
