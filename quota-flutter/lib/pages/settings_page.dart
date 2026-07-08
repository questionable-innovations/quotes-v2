import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import 'package:quota/api/models.dart';
import 'package:quota/contants.dart';
import 'package:quota/state/books_model.dart';

class SettingsPage extends StatefulWidget {
  final String bookId;

  const SettingsPage({super.key, required this.bookId});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<Member> _members = [];
  List<Invite> _invites = [];
  late TextEditingController _memberEmailController;
  late TextEditingController _bookNameController;
  late Book book;

  Future<void> _getMembers() async {
    try {
      final members = await api.listMembers(book.id);
      final invites = await api.listInvites(book.id);

      if (mounted) {
        setState(() {
          _members = members;
          _invites = invites;
        });
      }
    } catch (ex) {
      log("Could not fetch users", error: ex);
      if (mounted) {
        context.showErrorSnackBar(
            message: errorMessage(ex, "Could not fetch users"));
      }
    }
  }

  @override
  void initState() {
    _memberEmailController = TextEditingController();
    _bookNameController = TextEditingController();
    book = provider.Provider.of<BooksModel>(context, listen: false)
        .bookById(widget.bookId)!;
    _bookNameController.text = book.name;
    _getMembers();
    super.initState();
  }

  @override
  void dispose() {
    _memberEmailController.dispose();
    _bookNameController.dispose();
    super.dispose();
  }

  Future<void> _addMember(String email) async {
    try {
      final result = await api.addMember(book.id, email);
      if (mounted) {
        context.showSnackBar(
            message: result.invited
                ? "No account for $email yet — invite email sent!"
                : "Added $email");
      }
      await _getMembers();
    } catch (ex) {
      log("Could not add user", error: ex);
      if (mounted) {
        context.showErrorSnackBar(
            message: errorMessage(ex, "Couldn't add user"));
      }
    }
  }

  AlertDialog _addUserDialog(BuildContext context) => AlertDialog(
        content: TextField(
            controller: _memberEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(label: Text("User email"))),
        actions: [
          TextButton(
              onPressed: () {
                final email = _memberEmailController.text.trim();
                if (email == "") {
                  context.showErrorSnackBar(
                      message: "Email field should not be empty");
                  return;
                }

                Navigator.pop(context);
                _addMember(email);
                _memberEmailController.clear();
              },
              child: const Text("Ok")),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Dismiss"))
        ],
      );

  Future<void> _removeMember(Member member) async {
    try {
      await api.removeMember(book.id, member.id);
      await _getMembers();
    } catch (ex) {
      log("Could not remove user", error: ex);
      if (mounted) {
        context.showErrorSnackBar(
            message: errorMessage(ex, "Could not remove user"));
      }
    }
  }

  AlertDialog _removeUserDialog(Member member, BuildContext context) =>
      AlertDialog(
        content: Text("Are you sure you want to remove ${member.email}"),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel")),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                _removeMember(member);
              },
              child: const Text("Confirm"))
        ],
      );

  Future<void> _deleteBook() async {
    try {
      await api.deleteBook(book.id);
      if (!mounted) return;
      await provider.Provider.of<BooksModel>(context, listen: false)
          .refresh(context);
      if (!mounted) return;
      // Leave settings and the (now deleted) book page.
      Navigator.pop(context);
      Navigator.pop(context);
    } catch (ex) {
      log("Could not delete book", error: ex);
      if (mounted) {
        context.showErrorSnackBar(
            message: errorMessage(ex, "Could not delete book"));
      }
    }
  }

  AlertDialog _deleteBookDialog(BuildContext context) => AlertDialog(
        content: Text("Are you sure you want to delete ${book.name}"),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteBook();
              },
              child: const Text("Yes")),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("No")),
        ],
      );

  Future<void> _renameBook() async {
    try {
      final newBook =
          await api.renameBook(book.id, _bookNameController.text.trim());
      if (!mounted) return;
      await provider.Provider.of<BooksModel>(context, listen: false)
          .refresh(context);
      if (mounted) {
        setState(() {
          book = newBook;
        });
        context.showSnackBar(message: "Book renamed");
      }
    } catch (ex) {
      log("Could not update book name", error: ex);
      if (mounted) {
        context.showErrorSnackBar(
            message: errorMessage(ex, "Could not set book name"));
      }
    }
  }

  Future<void> _revokeInvite(Invite invite) async {
    try {
      await api.deleteInvite(book.id, invite.id);
      await _getMembers();
    } catch (ex) {
      log("Could not revoke invite", error: ex);
      if (mounted) {
        context.showErrorSnackBar(message: "Could not revoke invite");
      }
    }
  }

  Widget _buildBookSettings() {
    return Column(
      children: [
        const Text(
          "Book settings",
          style: TextStyle(fontSize: 25.0, fontWeight: FontWeight.bold),
        ),
        Padding(
            padding: const EdgeInsetsDirectional.all(10),
            child: TextField(
              controller: _bookNameController,
              decoration: const InputDecoration(label: Text("Book name")),
            )),
        ElevatedButton(
          onPressed: _renameBook,
          child: const Text("Apply"),
        )
      ],
    );
  }

  Widget _buildMembersList() {
    final List<Widget> children = [
      const Text(
        "Users",
        style: TextStyle(fontSize: 25.0, fontWeight: FontWeight.bold),
      ),
      const SizedBox(
        height: 20,
      ),
    ];

    children.addAll(_members
        .map((member) => [
              Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(member.email),
                      TextButton.icon(
                        onPressed: () {
                          showDialog(
                              context: context,
                              builder: (context) =>
                                  _removeUserDialog(member, context));
                        },
                        label: const Text(
                          "Remove",
                        ),
                        icon: const Icon(Icons.block),
                      )
                    ],
                  )),
              const SizedBox(
                height: 10,
              )
            ])
        .expand((element) => element));

    // Pending email invites (people without an account yet).
    children.addAll(_invites
        .map((invite) => [
              Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: Text("${invite.email} (invite pending)",
                              overflow: TextOverflow.ellipsis)),
                      TextButton.icon(
                        onPressed: () => _revokeInvite(invite),
                        label: const Text("Revoke"),
                        icon: const Icon(Icons.cancel_schedule_send),
                      )
                    ],
                  )),
              const SizedBox(
                height: 10,
              )
            ])
        .expand((element) => element));

    children.add(ElevatedButton(
        onPressed: () {
          showDialog(context: context, builder: _addUserDialog);
        },
        child: const Text("Add user")));

    return Column(children: children);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("${book.name} Settings")),
        body: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Card(
              margin: const EdgeInsets.fromLTRB(15, 0, 15, 15),
              child: _buildBookSettings(),
            ),
            Card(
              margin: const EdgeInsets.fromLTRB(15, 0, 15, 15),
              child: _buildMembersList(),
            ),
            FilledButton.tonal(
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) => _deleteBookDialog(context));
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.red[900]),
                ),
                child: const Text("Delete Book"))
          ]),
        ));
  }
}
