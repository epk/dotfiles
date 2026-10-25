"""Apply the declared tunnel settings before the service starts."""

import os
import sqlite3

with sqlite3.connect(os.environ["DB_PATH"]) as database:
    database.execute("PRAGMA foreign_keys = ON")
    interface = os.environ["WG_INTERFACE"]
    if not database.execute(
        "SELECT 1 FROM interfaces WHERE name = ?", (interface,)
    ).fetchone():
        database.execute(
            "UPDATE interfaces SET name = ? WHERE name = 'wg0'", (interface,)
        )
    database.execute(
        "UPDATE interfaces SET device = 'eth0', port = ?, ipv4Cidr = ?, "
        "mtu = 1420, firewallEnabled = 0 WHERE name = ?",
        (int(os.environ["INIT_PORT"]), os.environ["INIT_IPV4_CIDR"], interface),
    )
    database.execute(
        "UPDATE hooks SET preUp = '', postUp = '', preDown = '', postDown = ''"
    )
