import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quota/contants.dart';
import 'package:quota/state/books_model.dart';
import 'package:quota/state/quotes_model.dart';

class AddQuotePage extends StatefulWidget {
  final String bookId;
  const AddQuotePage({super.key, required this.bookId});

  @override
  State<AddQuotePage> createState() => _AddQuotePageState();
}

class _AddQuotePageState extends State<AddQuotePage> {
  final GlobalKey<FormState> _formKey = GlobalKey();
  DateTime date = DateTime.now();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quoteController = TextEditingController();

  bool formValid = false;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _quoteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
    });
    try {
      await Provider.of<QuotesModel>(context, listen: false).addQuote(
          widget.bookId,
          _nameController.text.trim(),
          _quoteController.text.trim(),
          date);
      if (mounted) {
        // Keep the books page quote count in sync.
        Provider.of<BooksModel>(context, listen: false).refresh(context);
        Navigator.of(context).pop(true);
      }
    } catch (ex) {
      if (mounted) {
        context.showErrorSnackBar(
            message: errorMessage(ex, "Could not add quote"));
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text("Add Quote")),
        body: Padding(
          padding: const EdgeInsets.all(15),
          child: Form(
              key: _formKey,
              onChanged: () {
                setState(() {
                  formValid = _formKey.currentState!.validate();
                });
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _quoteController,
                    decoration: const InputDecoration(labelText: "Quote"),
                    validator: (value) => (value == null || value.trim() == "")
                        ? "Quote must not be an empty string"
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: "Person"),
                    validator: (value) => (value == null || value.trim() == "")
                        ? "Name must not be an empty string"
                        : null,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final picked = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime(2010),
                              lastDate: DateTime.now());
                          if (picked != null) {
                            setState(() {
                              date = picked;
                            });
                          }
                        },
                        label: Text("${date.day}/${date.month}/${date.year}"),
                      ),
                      FilledButton.icon(
                        label: const Text("Submit"),
                        onPressed: (!formValid || _submitting) ? null : _submit,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              )),
        ));
  }
}
