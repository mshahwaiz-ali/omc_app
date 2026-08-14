frappe.ui.form.on('OMC Support Ticket', {
  refresh(frm) {
    frm.trigger('render_support_chat');

    if (!frm.is_new()) {
      frm.add_custom_button(__('Refresh Chat'), () => frm.trigger('render_support_chat'));
      frm.add_custom_button(__('Assign to Me'), () => {
        frappe.call({
          method: 'omc_app.api.support_chat.assign_support_ticket',
          args: {
            ticket_id: frm.doc.name,
            assigned_to: frappe.session.user,
          },
          freeze: true,
          freeze_message: __('Assigning ticket...'),
          callback: () => frm.reload_doc(),
        });
      });
    }
  },

  render_support_chat(frm) {
    const wrapper = frm.fields_dict.support_chat_html && frm.fields_dict.support_chat_html.$wrapper;
    if (!wrapper || frm.is_new()) return;

    wrapper.html(`
      <div class="omc-support-chat">
        <div class="omc-chat-loading">Loading support chat...</div>
      </div>
    `);

    frappe.call({
      method: 'omc_app.api.support_chat.get_support_ticket',
      args: { ticket_id: frm.doc.name },
      callback: (response) => {
        const ticket = response.message && response.message.ticket ? response.message.ticket : response.ticket;
        render_chat_widget(frm, wrapper, ticket || { messages: [] });
      },
      error: () => {
        wrapper.html('<div class="omc-chat-error">Support chat could not be loaded.</div>');
      },
    });
  },
});

function render_chat_widget(frm, wrapper, ticket) {
  const messages = Array.isArray(ticket.messages) ? ticket.messages : [];
  const isClosed = ['Closed', 'Cancelled'].includes(frm.doc.status);
  const assignedTo = frm.doc.assigned_to || '';

  wrapper.html(`
    <style>
      .omc-support-chat-wrap {
        border: 1px solid var(--border-color);
        border-radius: 14px;
        background: var(--bg-color);
        overflow: hidden;
        margin-top: 8px;
      }
      .omc-support-chat-head {
        padding: 14px 16px;
        border-bottom: 1px solid var(--border-color);
        display: flex;
        justify-content: space-between;
        gap: 12px;
        align-items: center;
        background: var(--fg-color);
      }
      .omc-support-chat-title {
        font-size: 15px;
        font-weight: 700;
        color: var(--text-color);
      }
      .omc-support-chat-subtitle {
        font-size: 12px;
        color: var(--text-muted);
        margin-top: 3px;
      }
      .omc-support-chat-body {
        padding: 16px;
        min-height: 260px;
        max-height: 520px;
        overflow-y: auto;
        background: linear-gradient(180deg, rgba(248, 249, 250, 0.9), rgba(255, 255, 255, 0.9));
      }
      .omc-chat-empty {
        color: var(--text-muted);
        padding: 18px;
        text-align: center;
        border: 1px dashed var(--border-color);
        border-radius: 12px;
      }
      .omc-chat-row {
        display: flex;
        margin-bottom: 12px;
      }
      .omc-chat-row.customer {
        justify-content: flex-start;
      }
      .omc-chat-row.staff,
      .omc-chat-row.admin,
      .omc-chat-row.support,
      .omc-chat-row.system {
        justify-content: flex-end;
      }
      .omc-chat-bubble {
        max-width: 74%;
        border: 1px solid var(--border-color);
        border-radius: 16px;
        padding: 11px 12px;
        background: #ffffff;
        box-shadow: 0 8px 24px rgba(15, 23, 42, 0.06);
      }
      .omc-chat-row.staff .omc-chat-bubble,
      .omc-chat-row.admin .omc-chat-bubble,
      .omc-chat-row.support .omc-chat-bubble {
        background: #fff3f3;
        border-color: #ffd7d7;
      }
      .omc-chat-row.system .omc-chat-bubble {
        background: #f5f7fa;
        border-color: #e5e7eb;
      }
      .omc-chat-meta {
        display: flex;
        gap: 8px;
        align-items: center;
        justify-content: space-between;
        margin-bottom: 7px;
      }
      .omc-chat-author {
        font-size: 12px;
        font-weight: 700;
        color: var(--text-color);
      }
      .omc-chat-time {
        font-size: 11px;
        color: var(--text-muted);
        white-space: nowrap;
      }
      .omc-chat-message {
        font-size: 13px;
        line-height: 1.45;
        white-space: pre-wrap;
        color: var(--text-color);
      }
      .omc-chat-attachment {
        display: inline-flex;
        align-items: center;
        gap: 7px;
        margin-top: 9px;
        padding: 8px 10px;
        border-radius: 10px;
        background: rgba(0, 0, 0, 0.04);
        color: var(--text-color);
        text-decoration: none;
        font-size: 12px;
        font-weight: 600;
      }
      .omc-chat-compose {
        border-top: 1px solid var(--border-color);
        padding: 14px;
        background: var(--fg-color);
      }
      .omc-chat-compose textarea {
        resize: vertical;
        min-height: 74px;
      }
      .omc-chat-actions {
        display: flex;
        justify-content: flex-end;
        gap: 8px;
        margin-top: 10px;
      }
      .omc-chat-closed {
        padding: 12px;
        border-radius: 10px;
        background: #f8f9fa;
        color: var(--text-muted);
        text-align: center;
        font-weight: 600;
      }
    </style>
    <div class="omc-support-chat-wrap">
      <div class="omc-support-chat-head">
        <div>
          <div class="omc-support-chat-title">Support Chat</div>
          <div class="omc-support-chat-subtitle">${frappe.utils.escape_html(messages.length)} messages${assignedTo ? ` • Assigned to ${frappe.utils.escape_html(assignedTo)}` : ''}</div>
        </div>
        <button class="btn btn-xs btn-default omc-chat-refresh">Refresh</button>
      </div>
      <div class="omc-support-chat-body">
        ${messages.length ? messages.map(render_message).join('') : '<div class="omc-chat-empty">No chat messages yet.</div>'}
      </div>
      <div class="omc-chat-compose">
        ${isClosed ? '<div class="omc-chat-closed">This ticket is closed. Reopen it before replying.</div>' : `
          <textarea class="form-control omc-chat-input" placeholder="Write a reply to the customer..."></textarea>
          <div class="omc-chat-actions">
            <button class="btn btn-default btn-sm omc-chat-attach">Attach File</button>
            <button class="btn btn-primary btn-sm omc-chat-send">Send Reply</button>
          </div>
        `}
      </div>
    </div>
  `);

  const body = wrapper.find('.omc-support-chat-body')[0];
  if (body) body.scrollTop = body.scrollHeight;

  wrapper.find('.omc-chat-refresh').on('click', () => frm.trigger('render_support_chat'));
  wrapper.find('.omc-chat-send').on('click', () => send_reply(frm, wrapper));
  wrapper.find('.omc-chat-attach').on('click', () => attach_and_send(frm, wrapper));
}

function render_message(message) {
  const senderType = String(message.sender_type || message.type || 'Customer').toLowerCase();
  const rowClass = senderType.includes('support') || senderType.includes('admin') ? 'support' : senderType.includes('system') ? 'system' : 'customer';
  const author = message.sender_user || message.author || (rowClass === 'customer' ? 'Customer' : 'OMC Team');
  const text = message.message || '';
  const time = message.created_at || '';
  const attachmentUrl = message.attachment_url || message.attachment || '';
  const attachmentName = message.attachment_name || 'Attachment';

  return `
    <div class="omc-chat-row ${rowClass}">
      <div class="omc-chat-bubble">
        <div class="omc-chat-meta">
          <span class="omc-chat-author">${frappe.utils.escape_html(author)}</span>
          <span class="omc-chat-time">${frappe.utils.escape_html(time)}</span>
        </div>
        ${text ? `<div class="omc-chat-message">${frappe.utils.escape_html(text)}</div>` : ''}
        ${attachmentUrl ? `<a class="omc-chat-attachment" href="${frappe.utils.escape_html(attachmentUrl)}" target="_blank">📎 ${frappe.utils.escape_html(attachmentName)}</a>` : ''}
      </div>
    </div>
  `;
}

function send_reply(frm, wrapper, attachmentUrl) {
  const input = wrapper.find('.omc-chat-input');
  const message = (input.val() || '').trim();

  if (!message && !attachmentUrl) {
    frappe.msgprint(__('Write a reply or attach a file first.'));
    return;
  }

  frappe.call({
    method: 'omc_app.api.support_chat.add_support_ticket_reply',
    args: {
      ticket_id: frm.doc.name,
      message,
      attachment: attachmentUrl || '',
    },
    freeze: true,
    freeze_message: __('Sending reply...'),
    callback: () => {
      input.val('');
      frm.reload_doc();
    },
  });
}

function attach_and_send(frm, wrapper) {
  new frappe.ui.FileUploader({
    doctype: frm.doctype,
    docname: frm.doc.name,
    folder: 'Home/Attachments',
    as_private: 1,
    on_success(file_doc) {
      const fileUrl = file_doc.file_url || file_doc.file_name || '';
      send_reply(frm, wrapper, fileUrl);
    },
  });
}
