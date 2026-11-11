import unittest


class Ok(unittest.TestCase):
    def test_passes(self):
        self.assertEqual(1 + 1, 2)
