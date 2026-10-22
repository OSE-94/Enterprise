import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/employee_account.dart';
import '../models/employee_operations_models.dart';
import '../services/employee_operations_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _service = EmployeeOperationsService();
  bool _isLoading = true;
  String? _error;
  List<EmployeeMessage> _messages = [];
  List<EmployeeDirectoryEntry> _employees = [];
  StreamSubscription<List<EmployeeMessage>>? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _messagesSubscription = _service.watchMessages().listen(
      (messages) {
        if (!mounted) return;
        setState(() {
          _messages = messages;
          _isLoading = false;
          _error = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _error = 'Could not load messages: $error';
          _isLoading = false;
        });
      },
    );
    _load();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = _messages.isEmpty;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.fetchMessages(),
        _service.fetchEmployees(),
      ]);
      if (!mounted) return;
      setState(() {
        _messages = results[0] as List<EmployeeMessage>;
        _employees = results[1] as List<EmployeeDirectoryEntry>;
        _isLoading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load messages: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<EmployeeAccount>();
    final employees =
        _employees.where((employee) => employee.uid != account.uid).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Messages',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Refresh messages',
              onPressed: _isLoading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          account.isAdmin
              ? 'Send private messages or announcements to the team.'
              : 'Messages from your team and your private conversation with an admin.',
          style: const TextStyle(color: Color(0xFF64716B)),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _compose(account, employees),
          icon: const Icon(Icons.edit_outlined),
          label: Text(account.isAdmin ? 'Compose message' : 'Message admin'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(_error!),
            ),
          ),
        ],
        const SizedBox(height: 18),
        if (_isLoading && _messages.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_messages.isEmpty && _error == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('No messages yet.'),
            ),
          )
        else
          ..._messages.map(
            (message) => _MessageCard(
              message: message,
              currentUser: account,
              onReply: () => _compose(
                account,
                employees,
                initialRecipientUid: account.isAdmin
                    ? (message.senderUid == account.uid
                        ? message.recipientUid
                        : message.senderUid)
                    : (message.senderUid == account.uid
                        ? message.recipientUid
                        : message.senderUid),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _compose(
    EmployeeAccount account,
    List<EmployeeDirectoryEntry> employees, {
    String? initialRecipientUid,
  }) async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => _ComposeMessageDialog(
        account: account,
        employees: employees,
        initialRecipientUid: initialRecipientUid,
        onSend: _service.sendMessage,
      ),
    );
    if (sent == true) await _load();
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    required this.currentUser,
    required this.onReply,
  });

  final EmployeeMessage message;
  final EmployeeAccount currentUser;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final sentByMe = message.senderUid == currentUser.uid;
    final label = message.isBroadcast
        ? 'Team announcement'
        : sentByMe
            ? (message.recipientName == null
                ? 'To admin inbox'
                : 'To ${message.recipientName}')
            : 'From ${message.senderName}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    message.subject.isEmpty ? label : message.subject,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  DateFormat('d MMM, HH:mm')
                      .format(message.createdAt.toLocal()),
                  style: const TextStyle(
                    color: Color(0xFF64716B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '$label · ${message.senderName}',
              style: const TextStyle(
                color: Color(0xFF64716B),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            Text(message.body),
            if (!message.isBroadcast &&
                (currentUser.isAdmin ||
                    !sentByMe ||
                    message.recipientUid != null))
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onReply,
                  icon: const Icon(Icons.reply_rounded, size: 18),
                  label: const Text('Reply'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ComposeMessageDialog extends StatefulWidget {
  const _ComposeMessageDialog({
    required this.account,
    required this.employees,
    required this.onSend,
    this.initialRecipientUid,
  });

  final EmployeeAccount account;
  final List<EmployeeDirectoryEntry> employees;
  final String? initialRecipientUid;
  final Future<void> Function({
    required String body,
    String subject,
    String? recipientUid,
    bool broadcast,
  }) onSend;

  @override
  State<_ComposeMessageDialog> createState() => _ComposeMessageDialogState();
}

class _ComposeMessageDialogState extends State<_ComposeMessageDialog> {
  final _subject = TextEditingController();
  final _body = TextEditingController();
  late String? _recipientUid = widget.initialRecipientUid ??
      (widget.employees.isEmpty ? null : widget.employees.first.uid);
  bool _broadcast = false;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.account.isAdmin ? 'Compose message' : 'Message admin'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.account.isAdmin) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Send to everyone'),
                  value: _broadcast,
                  onChanged: _sending
                      ? null
                      : (value) => setState(() => _broadcast = value),
                ),
                if (!_broadcast)
                  DropdownButtonFormField<String>(
                    initialValue: _recipientUid,
                    decoration: const InputDecoration(
                      labelText: 'Employee',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.employees
                        .map(
                          (employee) => DropdownMenuItem(
                            value: employee.uid,
                            child: Text(employee.name),
                          ),
                        )
                        .toList(),
                    onChanged: _sending
                        ? null
                        : (value) => setState(() => _recipientUid = value),
                  ),
                const SizedBox(height: 12),
              ] else
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Your message will be sent privately to the admin team.',
                  ),
                ),
              TextField(
                controller: _subject,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Subject (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _body,
                minLines: 4,
                maxLines: 8,
                maxLength: 5000,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _sending ? null : _submit,
          child: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final body = _body.text.trim();
    if (body.isEmpty) {
      setState(() => _error = 'Write a message before sending.');
      return;
    }
    if (widget.account.isAdmin && !_broadcast && _recipientUid == null) {
      setState(() => _error = 'Choose an employee to message.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSend(
        body: body,
        subject: _subject.text.trim(),
        recipientUid: _broadcast ? null : _recipientUid,
        broadcast: _broadcast,
      );
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = 'Could not send message: $error';
        });
      }
    }
  }
}
