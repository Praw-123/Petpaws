#!/usr/bin/env python3
"""Ansible dynamic inventory built from `terraform output -json`."""
import json
import os
import subprocess
import sys

TF_DIR = os.environ.get("TF_DIR", os.path.join(os.path.dirname(__file__), "..", "terraform"))
KEY_FILE = os.environ.get("ANSIBLE_KEY_FILE", "ansible_key")


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--host":
        print("{}")
        return

    out = json.loads(subprocess.check_output(["terraform", f"-chdir={TF_DIR}", "output", "-json"]))
    host = out["ansible_host"]["value"]

    inventory = {
        "app": {"hosts": [host]},
        "_meta": {
            "hostvars": {
                host: {
                    "ansible_user": "root",
                    "ansible_ssh_private_key_file": KEY_FILE,
                    "instance_id": out["instance_id"]["value"],
                    "instance_private_ip": out["instance_private_ip"]["value"],
                }
            }
        },
    }
    print(json.dumps(inventory, indent=2))


if __name__ == "__main__":
    main()
