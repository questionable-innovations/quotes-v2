import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart' as provider;

import 'package:quota/api/models.dart';
import 'package:quota/contants.dart';
import 'package:quota/state/books_model.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

// I did not create this regex my self, thanks https://www.abstractapi.com/tools/email-regex-guide
final emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$');

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  bool _redirecting = false;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final StreamSubscription<User?> _authStateSubscription;
  bool _validEmail = false;
  bool _validPassword = false;

  Future<void> _run(Future<void> Function() action, String fallback) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        context.showErrorSnackBar(message: errorMessage(error, fallback));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signIn() => _run(() async {
        await api.signIn(
            _emailController.text.trim(), _passwordController.text);
        // Tell the platform the credentials worked so password managers
        // offer to save/update them.
        TextInput.finishAutofillContext();
      }, "Could not sign in");

  Future<void> _signUp() => _run(() async {
        await api.signUp(
            _emailController.text.trim(), _passwordController.text);
        TextInput.finishAutofillContext();
        if (mounted) {
          context.showSnackBar(
              message: "Account created! Check your email to verify it.");
        }
      }, "Could not sign up");

  Future<void> _forgotPassword() => _run(() async {
        await api.requestPasswordReset(_emailController.text.trim());
        if (mounted) {
          context.showSnackBar(
              message: "Check your email for a password reset link!");
        }
      }, "Could not request password reset");

  @override
  void initState() {
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _authStateSubscription = api.onAuthStateChange.listen((user) {
      if (_redirecting || !mounted) return;
      if (user != null) {
        _redirecting = true;
        provider.Provider.of<BooksModel>(context, listen: false)
            .refresh(context);
        Navigator.of(context).pushReplacementNamed('/books');
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _authStateSubscription.cancel();
    super.dispose();
  }

  bool get _canSubmit => _validEmail && _validPassword && !_isLoading;

  List<Widget> _emailPasswordFields({required bool signUp}) => [
        TextFormField(
          controller: _emailController,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          decoration: const InputDecoration(label: Text("Email")),
          validator: (value) => value != null && emailRegex.hasMatch(value)
              ? null
              : "Please enter a valid email",
          onChanged: (value) => setState(() {
            _validEmail = emailRegex.hasMatch(value.trim());
          }),
        ),
        TextFormField(
            controller: _passwordController,
            autofillHints: [
              signUp ? AutofillHints.newPassword : AutofillHints.password
            ],
            obscureText: true,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_canSubmit) return;
              signUp ? _signUp() : _signIn();
            },
            onChanged: (value) {
              setState(() {
                _validPassword = value.trim() != "";
              });
            },
            decoration: const InputDecoration(label: Text("Password"))),
      ];

  @override
  Widget build(BuildContext context) => DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
            title: const Text("Login"),
            bottom: const TabBar(tabs: [
              Tab(
                text: "Sign In",
              ),
              Tab(text: "Sign up")
            ])),
        body: TabBarView(children: [
          Padding(
              padding: const EdgeInsets.all(15),
              child: Form(
                  child: AutofillGroup(
                      child: Column(
                children: [
                  ..._emailPasswordFields(signUp: false),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _canSubmit ? _signIn : null,
                    child: const Text("Sign in"),
                  ),
                  TextButton(
                    onPressed:
                        (_validEmail && !_isLoading) ? _forgotPassword : null,
                    child: const Text("Forgot password?"),
                  ),
                ],
              )))),
          Padding(
              padding: const EdgeInsets.all(15),
              child: Form(
                  child: AutofillGroup(
                      child: Column(
                children: [
                  ..._emailPasswordFields(signUp: true),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _canSubmit ? _signUp : null,
                    child: const Text("Sign up"),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text("Passwords must be at least 8 characters."),
                  ),
                ],
              )))),
        ]),
      ));
}
