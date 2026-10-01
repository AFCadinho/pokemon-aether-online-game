import unittest
from PIL import Image
from catalog_eye_detail_proposals import hue_transfer,nincada_glints,keldeo_iris
class EyeDetailTests(unittest.TestCase):
 def test_skin_hue_retains_pupil_white_and_alpha(self):
  im=Image.new('RGBA',(3,1));im.putdata([(48,112,160,127),(10,10,10,255),(250,250,250,255)])
  out=hue_transfer(im,.57,.79,-.3,1.2)
  self.assertNotEqual(out.getpixel((0,0)),im.getpixel((0,0)))
  self.assertEqual(out.getpixel((1,0)),im.getpixel((1,0)))
  self.assertEqual(out.getpixel((2,0)),im.getpixel((2,0)))
  self.assertEqual(out.getchannel('A').tobytes(),im.getchannel('A').tobytes())
 def test_missing_iris_mask_is_held(self):
  with self.assertRaisesRegex(ValueError,'No source iris'):keldeo_iris(Image.new('RGBA',(32,32),'white'),Image.new('RGBA',(32,32),'red'))
 def test_missing_open_eye_is_held(self):
  with self.assertRaisesRegex(ValueError,'no pupil'):nincada_glints(Image.new('RGBA',(64,64),'white'))
if __name__=='__main__':unittest.main()
