import 'package:flutter/material.dart';

class EndTripDialog extends StatefulWidget {
  const EndTripDialog({super.key, this.title = 'End Trip'});

  final String title;

  @override
  State<EndTripDialog> createState() => _EndTripDialogState();
}

class _EndTripDialogState extends State<EndTripDialog> {
  final TextEditingController _endSocController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _endSocController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _endSocController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'End SoC (0-100)'),
          validator: (String? value) {
            final int? parsed = int.tryParse(value ?? '');
            if (parsed == null || parsed < 0 || parsed > 100) {
              return 'Please enter a value between 0 and 100.';
            }
            return null;
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() == true) {
              Navigator.of(context).pop(int.parse(_endSocController.text));
            }
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
