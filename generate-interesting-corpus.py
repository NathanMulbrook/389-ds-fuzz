#!/usr/bin/env python3

"""Create focused LDAP seeds for the multipacket fuzzer."""

from pathlib import Path


BASE = "dc=example,dc=com"
PEOPLE = f"ou=people,{BASE}"
GROUPS = f"ou=groups,{BASE}"
FUZZ_USER = f"uid=fuzz-user,{PEOPLE}"
FUZZ_MANAGER = f"uid=fuzz-manager,{PEOPLE}"
TARGET = f"uid=fuzz-target-1,{PEOPLE}"


def ber_length(length):
    if length < 0x80:
        return bytes([length])
    encoded = length.to_bytes((length.bit_length() + 7) // 8, "big")
    return bytes([0x80 | len(encoded)]) + encoded


def ber(tag, value):
    return bytes([tag]) + ber_length(len(value)) + value


def integer(value, tag=0x02):
    encoded = value.to_bytes(max(1, (value.bit_length() + 7) // 8), "big")
    if encoded[0] & 0x80:
        encoded = b"\0" + encoded
    return ber(tag, encoded)


def octet(value):
    if isinstance(value, str):
        value = value.encode()
    return ber(0x04, value)


def sequence(*values):
    return ber(0x30, b"".join(values))


def boolean(value):
    return ber(0x01, b"\xff" if value else b"\0")


def ldap_message(message_id, operation, controls=()):
    body = integer(message_id) + operation
    if controls:
        body += ber(0xA0, b"".join(controls))
    return sequence(body)


def control(oid, value=None, critical=False):
    fields = [octet(oid)]
    if critical:
        fields.append(boolean(True))
    if value is not None:
        fields.append(octet(value))
    return sequence(*fields)


def bind(message_id, dn, password):
    request = integer(3) + octet(dn) + ber(0x80, password.encode())
    return ldap_message(message_id, ber(0x60, request))


def sasl_bind(message_id, mechanism, credentials=b""):
    authentication = octet(mechanism)
    if credentials is not None:
        authentication += octet(credentials)
    request = integer(3) + octet("") + ber(0xA3, authentication)
    return ldap_message(message_id, ber(0x60, request))


def filter_equal(attribute, value, tag=0xA3):
    return ber(tag, octet(attribute) + octet(value))


def filter_present(attribute):
    return ber(0x87, attribute.encode())


def filter_substrings(attribute, initial=None, any_values=(), final=None):
    parts = []
    if initial is not None:
        parts.append(ber(0x80, initial.encode()))
    parts.extend(ber(0x81, value.encode()) for value in any_values)
    if final is not None:
        parts.append(ber(0x82, final.encode()))
    return ber(0xA4, octet(attribute) + sequence(*parts))


def filter_extensible(attribute, value, matching_rule):
    fields = ber(0x81, matching_rule.encode())
    fields += ber(0x82, attribute.encode())
    fields += ber(0x83, value.encode())
    return ber(0xA9, fields)


def filter_and(*filters):
    return ber(0xA0, b"".join(filters))


def filter_or(*filters):
    return ber(0xA1, b"".join(filters))


def filter_not(filter_value):
    return ber(0xA2, filter_value)


def search(message_id, base, filter_value, attributes=(), controls=(), scope=2):
    request = octet(base)
    request += integer(scope, 0x0A) + integer(0, 0x0A)
    request += integer(0) + integer(0) + boolean(False)
    request += filter_value
    request += sequence(*(octet(attribute) for attribute in attributes))
    return ldap_message(message_id, ber(0x63, request), controls)


def attribute(name, *values):
    return sequence(octet(name), ber(0x31, b"".join(octet(value) for value in values)))


def add(message_id, dn, attributes, controls=()):
    request = octet(dn) + sequence(*(attribute(name, *values) for name, values in attributes))
    return ldap_message(message_id, ber(0x68, request), controls)


def modify(message_id, dn, changes, controls=()):
    encoded_changes = []
    for operation, name, values in changes:
        encoded_changes.append(sequence(integer(operation, 0x0A), attribute(name, *values)))
    request = octet(dn) + sequence(*encoded_changes)
    return ldap_message(message_id, ber(0x66, request), controls)


def delete(message_id, dn, controls=()):
    return ldap_message(message_id, ber(0x4A, dn.encode()), controls)


def modrdn(message_id, dn, new_rdn, new_superior=None):
    request = octet(dn) + octet(new_rdn) + boolean(True)
    if new_superior is not None:
        request += ber(0x80, new_superior.encode())
    return ldap_message(message_id, ber(0x6C, request))


def compare(message_id, dn, name, value, controls=()):
    request = octet(dn) + sequence(octet(name), octet(value))
    return ldap_message(message_id, ber(0x6E, request), controls)


def extended(message_id, oid, value=None, controls=()):
    request = ber(0x80, oid.encode())
    if value is not None:
        request += ber(0x81, value)
    return ldap_message(message_id, ber(0x77, request), controls)


def multipacket(*packets, flags=0x07):
    result = bytearray([flags])
    for packet in packets:
        result.extend(len(packet).to_bytes(2, "big"))
        result.extend(packet)
    return bytes(result)


def person_attributes(uid, common_name):
    return (
        ("objectClass", ("top", "person", "organizationalPerson", "inetOrgPerson")),
        ("uid", (uid,)),
        ("cn", (common_name,)),
        ("sn", (common_name.rsplit(" ", 1)[-1],)),
        ("mail", (f"{uid}@example.test",)),
    )


def membership_cycle_seed():
    user = f"uid=fuzz-cycle-user,{PEOPLE}"
    moved_user = f"uid=fuzz-cycle-user,{GROUPS}"
    group_a = f"cn=fuzz-cycle-a,{GROUPS}"
    group_b = f"cn=fuzz-cycle-b,{GROUPS}"
    group = lambda name, member: (
        ("objectClass", ("top", "groupOfNames")),
        ("cn", (name,)),
        ("member", (member,)),
    )
    packets = [
        delete(10, moved_user), delete(11, user),
        delete(12, group_a), delete(13, group_b),
        add(14, user, person_attributes("fuzz-cycle-user", "Fuzz Cycle User")),
        add(15, group_a, group("fuzz-cycle-a", user)),
        add(16, group_b, group("fuzz-cycle-b", group_a)),
        modify(17, group_a, ((0, "member", (group_b,)),)),
        search(18, user, filter_present("objectClass"), ("memberOf",), scope=0),
        modrdn(19, user, "uid=fuzz-cycle-user", GROUPS),
        search(20, group_a, filter_equal("member", moved_user), ("member",), scope=0),
        delete(21, moved_user),
        search(22, group_a, filter_present("member"), ("member",), scope=0),
        delete(23, group_b), delete(24, group_a),
    ]
    return multipacket(*packets)


def uniqueness_and_read_controls_seed():
    dn = f"uid=fuzz-unique-seed,{PEOPLE}"
    common_attributes = (
        ("objectClass", ("top", "person", "organizationalPerson", "inetOrgPerson", "posixAccount")),
        ("cn", ("Fuzz Unique Seed",)),
        ("sn", ("Seed",)),
        ("mail", ("fuzz-unique-seed@example.test",)),
        ("gidNumber", ("20000",)),
        ("homeDirectory", ("/var/empty/fuzz-unique-seed",)),
        ("description", ("before-controls",)),
        ("uidNumber", ("20990",)),
    )
    duplicate_attributes = (("uid", ("fuzz-unique-seed", "fuzz-target-1")),) + common_attributes
    unique_attributes = (("uid", ("fuzz-unique-seed",)),) + common_attributes
    requested = sequence(octet("uidNumber"), octet("description"))
    pre_read = control("1.3.6.1.1.13.1", requested)
    post_read = control("1.3.6.1.1.13.2", requested)
    packets = (
        delete(30, dn),
        add(31, dn, duplicate_attributes),
        add(32, dn, unique_attributes, (post_read,)),
        modify(33, dn, ((2, "uidNumber", ("20991",)), (2, "description", ("after-controls",))),
               (pre_read, post_read)),
        # LDAP_MOD_INCREMENT is not supported; retain its clean rejection path.
        modify(34, dn, ((3, "uidNumber", ("1",)),)),
        compare(35, dn, "description", "after-controls"),
        delete(36, dn, (pre_read,)),
    )
    return multipacket(*packets)


def search_controls_seed():
    sort_value = sequence(sequence(octet("cn")))
    vlv_value = sequence(integer(1), integer(1), ber(0xA0, integer(2) + integer(4)))
    complex_filter = filter_and(
        filter_equal("objectClass", "nsPerson"),
        filter_or(
            filter_equal("cn", "Fuzz Trget", 0xA8),
            filter_substrings("mail", "fuzz", ("target",), "example.test"),
        ),
        filter_equal("uidNumber", "20011", 0xA5),
        filter_equal("uidNumber", "20014", 0xA6),
        filter_not(filter_present("nsAccountLock")),
        filter_extensible("cn", "FUZZ TARGET ONE", "2.5.13.2"),
    )
    vlv_controls = (
        control("1.2.840.113556.1.4.473", sort_value),
        control("2.16.840.1.113730.3.4.9", vlv_value),
    )
    paged_cancel = control("1.2.840.113556.1.4.319", sequence(integer(0), octet(b"")))
    usability = control("1.3.6.1.4.1.42.2.27.9.5.8")
    packets = (
        search(40, PEOPLE, complex_filter, ("uid", "cn", "mail"), vlv_controls),
        search(41, PEOPLE, filter_present("objectClass"), ("uid",), (paged_cancel,)),
        search(42, TARGET, filter_present("objectClass"), ("uid",), (usability,), scope=0),
    )
    return multipacket(*packets)


def effective_rights_seed():
    oid = "1.3.6.1.4.1.42.2.27.9.5.2"
    manager_control = control(oid, f"dn:{FUZZ_MANAGER}".encode())
    user_control = control(oid, f"dn:{FUZZ_USER}".encode())
    attributes = ("*", "aclRights", "entryLevelRights")
    packets = (
        bind(50, FUZZ_MANAGER, "FuzzManager-pass-02"),
        search(51, TARGET, filter_present("objectClass"), attributes,
               (manager_control,), scope=0),
        compare(52, TARGET, "mail", "fuzz-target-1@example.test"),
        bind(53, FUZZ_USER, "FuzzUser-pass-01"),
        search(54, TARGET, filter_present("objectClass"), attributes,
               (user_control,), scope=0),
        modify(55, TARGET, ((2, "description", ("ordinary-user-must-not-write",)),)),
    )
    return multipacket(*packets)


def bind_and_extended_seed():
    plain = b"\0fuzz-user\0FuzzUser-pass-01"
    packets = (
        extended(60, "1.3.6.1.4.1.4203.1.11.3"),
        bind(61, FUZZ_USER, "FuzzUser-pass-01"),
        extended(62, "1.3.6.1.4.1.4203.1.11.3"),
        bind(63, FUZZ_USER, "wrong-password"),
        extended(64, "1.3.6.1.4.1.4203.1.11.3"),
        sasl_bind(65, "PLAIN", plain),
        sasl_bind(66, "FUZZ-MECHANISM", b"\0\xff\x80credentials"),
        search(67, "", filter_present("objectClass"),
               ("supportedSASLMechanisms", "supportedExtension"), scope=0),
    )
    return multipacket(*packets, flags=0x06)


def password_change_seed():
    dn = f"uid=fuzz-password-seed,{PEOPLE}"
    initial_password = "FuzzPassword-start-31"
    modified_password = "FuzzPassword-modify-32"
    final_password = "FuzzPassword-extop-33"
    pwpolicy = control("1.3.6.1.4.1.42.2.27.8.5.1")
    passmod_value = sequence(
        ber(0x80, dn.encode()),
        ber(0x81, modified_password.encode()),
        ber(0x82, final_password.encode()),
    )
    attributes = person_attributes("fuzz-password-seed", "Fuzz Password Seed") + (
        ("userPassword", (initial_password,)),
    )
    packets = (
        delete(80, dn),
        add(81, dn, attributes),
        bind(82, dn, initial_password),
        modify(83, dn, ((2, "userPassword", (modified_password,)),), (pwpolicy,)),
        bind(84, dn, modified_password),
        extended(85, "1.3.6.1.4.1.4203.1.11.1", passmod_value, (pwpolicy,)),
        bind(86, dn, final_password),
        bind(87, "cn=directory manager", "secRet_passWord"),
        delete(88, dn),
    )
    return multipacket(*packets)


def identity_controls_seed():
    session_value = sequence(
        octet("127.0.0.1"),
        octet("fuzzer.example.test"),
        octet("1.3.6.1.4.1.21008.108.63.1.1234"),
        octet(b"coverage-\"\\-session-identifier"),
    )
    session = control("1.3.6.1.4.1.21008.108.63.1", session_value)
    proxy_v2 = control("2.16.840.1.113730.3.4.18", f"dn:{FUZZ_USER}".encode(), True)
    proxy_v1 = control("2.16.840.1.113730.3.4.12", sequence(octet(FUZZ_MANAGER)), True)
    uncritical_proxy = control("2.16.840.1.113730.3.4.18", f"dn:{FUZZ_USER}".encode())
    malformed_proxy = control("2.16.840.1.113730.3.4.18", b"u:fuzz-user", True)
    packets = (
        search(90, TARGET, filter_present("objectClass"), ("uid", "mail"),
               (session, proxy_v2), scope=0),
        compare(91, TARGET, "uid", "fuzz-target-1", (proxy_v1,)),
        search(92, TARGET, filter_present("objectClass"), ("uid",),
               (uncritical_proxy,), scope=0),
        search(93, TARGET, filter_present("objectClass"), ("uid",),
               (malformed_proxy,), scope=0),
    )
    return multipacket(*packets)


def matching_and_deref_seed():
    deref_value = sequence(
        sequence(octet("member"), sequence(octet("uid"), octet("mail"), octet("entryUUID")))
    )
    deref = control("1.3.6.1.4.1.4203.666.5.16", deref_value)
    group = f"cn=fuzz-inner,{GROUPS}"
    packets = (
        search(100, PEOPLE,
               filter_extensible("uidNumber", "3", "1.2.840.113556.1.4.803"),
               ("uid", "uidNumber")),
        search(101, PEOPLE,
               filter_extensible("uidNumber", "8", "1.2.840.113556.1.4.804"),
               ("uid", "uidNumber")),
        search(102, group, filter_present("objectClass"), ("cn", "member"),
               (deref,), scope=0),
        search(103, PEOPLE,
               filter_equal("entryUUID", "00000000-0000-0000-0000-000000000000"),
               ("uid", "entryUUID")),
        search(104, PEOPLE,
               filter_equal("entryUUID", "80000000-0000-0000-0000-000000000000", 0xA5),
               ("uid", "entryUUID")),
        search(105, PEOPLE,
               filter_equal("entryUUID", "7fffffff-ffff-ffff-ffff-ffffffffffff", 0xA6),
               ("uid", "entryUUID")),
    )
    return multipacket(*packets)


def roles_seed():
    role = f"cn=fuzz-managed-role,{BASE}"
    role_attributes = (
        ("objectClass", (
            "top", "LDAPsubentry", "nsRoleDefinition",
            "nsSimpleRoleDefinition", "nsManagedRoleDefinition",
        )),
        ("cn", ("fuzz-managed-role",)),
    )
    packets = (
        modify(110, TARGET, ((1, "nsRoleDN", (role,)),)),
        delete(111, role),
        add(112, role, role_attributes),
        modify(113, TARGET, ((0, "nsRoleDN", (role,)),)),
        search(114, TARGET, filter_present("objectClass"), ("uid", "nsRole"), scope=0),
        search(115, PEOPLE, filter_equal("nsRole", role), ("uid", "nsRole")),
        modify(116, TARGET, ((1, "nsRoleDN", (role,)),)),
        delete(117, role),
    )
    return multipacket(*packets)


def complex_roles_seed():
    managed = f"cn=fuzz-managed-role-2,{BASE}"
    filtered = f"cn=fuzz-filtered-role,{BASE}"
    nested = f"cn=fuzz-nested-role,{BASE}"
    managed_attributes = (
        ("objectClass", (
            "top", "LDAPsubentry", "nsRoleDefinition",
            "nsSimpleRoleDefinition", "nsManagedRoleDefinition",
        )),
        ("cn", ("fuzz-managed-role-2",)),
    )
    filtered_attributes = (
        ("objectClass", (
            "top", "LDAPsubentry", "nsRoleDefinition",
            "nsComplexRoleDefinition", "nsFilteredRoleDefinition",
        )),
        ("cn", ("fuzz-filtered-role",)),
        ("nsRoleFilter", ("(uid=fuzz-target-2)",)),
    )
    nested_attributes = (
        ("objectClass", (
            "top", "LDAPsubentry", "nsRoleDefinition",
            "nsComplexRoleDefinition", "nsNestedRoleDefinition",
        )),
        ("cn", ("fuzz-nested-role",)),
        ("nsRoleDN", (managed, filtered)),
    )
    packets = (
        modify(130, TARGET, ((1, "nsRoleDN", (managed,)),)),
        delete(131, nested), delete(132, filtered), delete(133, managed),
        add(134, managed, managed_attributes),
        add(135, filtered, filtered_attributes),
        add(136, nested, nested_attributes),
        modify(137, TARGET, ((0, "nsRoleDN", (managed,)),)),
        search(138, PEOPLE, filter_equal("nsRole", filtered), ("uid", "nsRole")),
        search(139, PEOPLE, filter_equal("nsRole", nested), ("uid", "nsRole")),
        search(140, TARGET, filter_present("objectClass"), ("uid", "nsRole"), scope=0),
        modify(141, TARGET, ((1, "nsRoleDN", (managed,)),)),
        delete(142, nested), delete(143, filtered), delete(144, managed),
    )
    return multipacket(*packets)


def referral_seed():
    dn = f"cn=fuzz-referral,{BASE}"
    managedsait = control("2.16.840.1.113730.3.4.2")
    attributes = (
        ("objectClass", ("top", "referral", "extensibleObject")),
        ("cn", ("fuzz-referral",)),
        ("ref", (f"ldap://invalid.example/{dn}",)),
    )
    packets = (
        delete(120, dn, (managedsait,)),
        add(121, dn, attributes, (managedsait,)),
        search(122, dn, filter_present("objectClass"), ("cn", "ref"), scope=0),
        search(123, dn, filter_present("objectClass"), ("cn", "ref"),
               (managedsait,), scope=0),
        delete(124, dn, (managedsait,)),
    )
    return multipacket(*packets)


def main():
    corpus = Path(__file__).resolve().parent / "corpus"
    corpus.mkdir(exist_ok=True)
    seeds = {
        "seed-plugin-membership-cycle": membership_cycle_seed(),
        "seed-unique-read-controls": uniqueness_and_read_controls_seed(),
        "seed-search-vlv-filters": search_controls_seed(),
        "seed-acl-effective-rights": effective_rights_seed(),
        "seed-bind-sasl-extended": bind_and_extended_seed(),
        "seed-starttls": bytes([0]) + extended(70, "1.3.6.1.4.1.1466.20037"),
        "seed-password-change-paths": password_change_seed(),
        "seed-session-proxy-controls": identity_controls_seed(),
        "seed-bitwise-deref-entryuuid": matching_and_deref_seed(),
        "seed-managed-role": roles_seed(),
        "seed-filtered-nested-roles": complex_roles_seed(),
        "seed-referral-managedsait": referral_seed(),
    }
    for name, data in seeds.items():
        (corpus / name).write_bytes(data)
        print(f"{name}: {len(data)} bytes")


if __name__ == "__main__":
    main()
