import frappe


CHAT_DOCTYPE = "OMC Support Ticket Message"
CHAT_TABLE = "tabOMC Support Ticket Message"
TICKET_TABLE = "tabOMC Support Ticket"


def _table_exists(table_name):
    return bool(frappe.db.sql("show tables like %s", table_name))


def _column_exists(table_name, column_name):
    if not _table_exists(table_name):
        return False
    return column_name in [row[0] for row in frappe.db.sql(f"desc `{table_name}`")]


def _add_column_if_missing(table_name, column_name, definition):
    if not _column_exists(table_name, column_name):
        frappe.db.sql(f"alter table `{table_name}` add column `{column_name}` {definition}")


def _ensure_message_columns():
    _add_column_if_missing(CHAT_TABLE, "support_ticket", "varchar(140)")
    _add_column_if_missing(CHAT_TABLE, "sender_user", "varchar(140)")
    _add_column_if_missing(CHAT_TABLE, "sender_type", "varchar(140) default 'Customer'")
    _add_column_if_missing(CHAT_TABLE, "message", "longtext")
    _add_column_if_missing(CHAT_TABLE, "attachment", "text")
    _add_column_if_missing(CHAT_TABLE, "attachment_name", "varchar(140)")
    _add_column_if_missing(CHAT_TABLE, "attachment_type", "varchar(140)")
    _add_column_if_missing(CHAT_TABLE, "attachment_size", "int(11) not null default 0")
    _add_column_if_missing(CHAT_TABLE, "is_internal", "int(1) not null default 0")
    _add_column_if_missing(CHAT_TABLE, "read_by_customer", "int(1) not null default 0")
    _add_column_if_missing(CHAT_TABLE, "read_by_staff", "int(1) not null default 0")


def _backfill_support_ticket_from_parent():
    if not _column_exists(CHAT_TABLE, "support_ticket"):
        return
    if not _column_exists(CHAT_TABLE, "parent"):
        return

    frappe.db.sql(
        f"""
        update `{CHAT_TABLE}`
        set support_ticket = parent
        where coalesce(support_ticket, '') = ''
          and coalesce(parent, '') != ''
          and coalesce(parenttype, '') = 'OMC Support Ticket'
        """
    )


def _migrate_legacy_ticket_message_rows():
    if not _table_exists(TICKET_TABLE):
        return

    tickets = frappe.db.sql(
        f"""
        select name, raised_by, message, creation
        from `{TICKET_TABLE}`
        where coalesce(message, '') != ''
        """,
        as_dict=True,
    )

    for ticket in tickets:
        existing = frappe.db.sql(
            f"select name from `{CHAT_TABLE}` where support_ticket = %s limit 1",
            ticket.name,
        )
        if existing:
            continue

        raw_message = ticket.message or ""
        parts = raw_message.split("\n\n--- Reply from ")
        initial_message = parts[0].strip()
        if initial_message:
            frappe.db.sql(
                f"""
                insert into `{CHAT_TABLE}`
                (name, creation, modified, owner, modified_by, docstatus, idx,
                 support_ticket, sender_user, sender_type, message, is_internal, read_by_customer, read_by_staff)
                values (%s, %s, now(), %s, %s, 0, 1, %s, %s, 'Customer', %s, 0, 1, 0)
                """,
                (
                    frappe.generate_hash(length=10),
                    ticket.creation,
                    ticket.raised_by or "Administrator",
                    ticket.raised_by or "Administrator",
                    ticket.name,
                    ticket.raised_by,
                    initial_message,
                ),
            )

        index = 2
        for raw_reply in parts[1:]:
            header, separator, body = raw_reply.partition(" ---\n")
            if not separator or not body.strip():
                continue
            author = header
            created_at = frappe.utils.now_datetime()
            if " at " in header:
                author, created_text = header.rsplit(" at ", 1)
                parsed = frappe.utils.get_datetime(created_text.strip())
                if parsed:
                    created_at = parsed
            author = author.strip() or "Administrator"
            sender_type = "Support" if "admin" in author.lower() or "support" in author.lower() or "omc" in author.lower() else "Customer"
            frappe.db.sql(
                f"""
                insert into `{CHAT_TABLE}`
                (name, creation, modified, owner, modified_by, docstatus, idx,
                 support_ticket, sender_user, sender_type, message, is_internal, read_by_customer, read_by_staff)
                values (%s, %s, now(), %s, %s, 0, %s, %s, %s, %s, %s, 0, 0, 0)
                """,
                (
                    frappe.generate_hash(length=10),
                    created_at,
                    author,
                    author,
                    index,
                    ticket.name,
                    author,
                    sender_type,
                    body.strip(),
                ),
            )
            index += 1


def execute():
    if not _table_exists(CHAT_TABLE):
        return

    _ensure_message_columns()
    _backfill_support_ticket_from_parent()
    _migrate_legacy_ticket_message_rows()

    if _table_exists(TICKET_TABLE):
        frappe.db.sql(
            f"""
            update `{TICKET_TABLE}` ticket
            set modified = now()
            where exists (
                select 1 from `{CHAT_TABLE}` msg
                where msg.support_ticket = ticket.name
            )
            """
        )

    frappe.db.commit()
