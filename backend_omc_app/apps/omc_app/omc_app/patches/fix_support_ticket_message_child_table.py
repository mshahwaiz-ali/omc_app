import frappe


CHAT_TABLE = "tabOMC Support Ticket Message"
TICKET_TABLE = "tabOMC Support Ticket"


def _table_exists(table_name):
    return bool(frappe.db.sql("show tables like %s", table_name))


def _column_exists(table_name, column_name):
    return frappe.db.has_column(table_name, column_name)


def _add_column_if_missing(table_name, column_name, definition):
    if not _column_exists(table_name, column_name):
        frappe.db.sql(f"alter table `{table_name}` add column `{column_name}` {definition}")


def execute():
    if not _table_exists(CHAT_TABLE):
        return

    _add_column_if_missing(CHAT_TABLE, "parent", "varchar(140)")
    _add_column_if_missing(CHAT_TABLE, "parentfield", "varchar(140)")
    _add_column_if_missing(CHAT_TABLE, "parenttype", "varchar(140)")
    _add_column_if_missing(CHAT_TABLE, "idx", "int(8) not null default 0")

    if not _column_exists(CHAT_TABLE, "support_ticket"):
        return

    frappe.db.sql(
        f"""
        update `{CHAT_TABLE}`
        set parent = support_ticket,
            parenttype = 'OMC Support Ticket',
            parentfield = 'conversation'
        where coalesce(parent, '') = ''
          and coalesce(support_ticket, '') != ''
        """
    )

    rows = frappe.db.sql(
        f"""
        select name, parent
        from `{CHAT_TABLE}`
        where parenttype = 'OMC Support Ticket'
          and parentfield = 'conversation'
          and coalesce(parent, '') != ''
        order by parent asc, creation asc, name asc
        """,
        as_dict=True,
    )

    counters = {}
    for row in rows:
        parent = row.parent
        counters[parent] = counters.get(parent, 0) + 1
        frappe.db.sql(
            f"update `{CHAT_TABLE}` set idx = %s where name = %s",
            (counters[parent], row.name),
        )

    if _table_exists(TICKET_TABLE):
        frappe.db.sql(
            f"""
            update `{TICKET_TABLE}` ticket
            set modified = now()
            where exists (
                select 1
                from `{CHAT_TABLE}` msg
                where msg.parent = ticket.name
                  and msg.parenttype = 'OMC Support Ticket'
                  and msg.parentfield = 'conversation'
            )
            """
        )

    frappe.db.commit()
