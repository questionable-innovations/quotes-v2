import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:quota/contants.dart';
import 'package:quota/state/books_model.dart';
import 'package:quota/state/quotes_model.dart';
import 'package:quota/utils/pick_images.dart';

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
  final List<XFile> _images = [];

  @override
  void dispose() {
    _nameController.dispose();
    _quoteController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await pickCompressedImages(context);
    if (picked.isNotEmpty && mounted) {
      setState(() => _images.addAll(picked));
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
    });
    try {
      final model = Provider.of<QuotesModel>(context, listen: false);
      final quote = await model.addQuote(widget.bookId,
          _nameController.text.trim(), _quoteController.text.trim(), date);
      for (final image in _images) {
        try {
          final bytes = await image.readAsBytes();
          await model.uploadAttachment(quote, image.name, bytes);
        } catch (ex) {
          if (mounted) {
            context.showErrorSnackBar(
                message: errorMessage(
                    ex, "Quote saved, but ${image.name} failed to upload"));
          }
        }
      }
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
                  if (_images.isNotEmpty) ...[
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _images.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 80,
                                height: 80,
                                child: FutureBuilder(
                                  future: _images[i].readAsBytes(),
                                  builder: (context, snapshot) =>
                                      snapshot.hasData
                                          ? Image.memory(snapshot.data!,
                                              fit: BoxFit.cover)
                                          : const SizedBox.shrink(),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: InkWell(
                                onTap: () =>
                                    setState(() => _images.removeAt(i)),
                                child: Container(
                                  color: Colors.black45,
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(Icons.close,
                                      size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _submitting ? null : _pickImages,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text("Attach images"),
                    ),
                  ),
                  const SizedBox(height: 10),
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
