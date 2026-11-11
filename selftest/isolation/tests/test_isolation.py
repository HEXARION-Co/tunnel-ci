"""The harness must hold: these tests pass only inside the hardened container."""
import os
import socket
import unittest


class Isolation(unittest.TestCase):
    def test_runs_as_the_unprivileged_user(self):
        self.assertEqual((os.getuid(), os.getgid()), (10001, 10001))

    def test_no_network(self):
        with self.assertRaises(OSError):
            socket.create_connection(("1.1.1.1", 53), timeout=3)

    def test_repo_is_read_only(self):
        with self.assertRaises(OSError):
            open("/src/should_not_exist", "w").close()

    def test_root_filesystem_is_read_only(self):
        with self.assertRaises(OSError):
            open("/etc/should_not_exist", "w").close()

    def test_tmp_is_writable_but_not_executable(self):
        path = "/tmp/probe"
        with open(path, "w") as handle:
            handle.write("#!/bin/sh\n")
        os.chmod(path, 0o755)
        with self.assertRaises(OSError):
            os.execv(path, [path])

    def test_no_secret_in_the_environment(self):
        leaked = [k for k in os.environ if any(w in k.upper() for w in ("TOKEN", "SECRET", "GITHUB", "PASSWORD"))]
        self.assertEqual(leaked, [])

    def test_no_docker_socket(self):
        self.assertFalse(os.path.exists("/var/run/docker.sock"))
