import unittest


class Fail(unittest.TestCase):
    def test_fails(self):
        self.assertEqual(1 + 1, 3)
